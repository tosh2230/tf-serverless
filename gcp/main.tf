provider "google" {
  version = "3.60.0"
  project = var.project
  region  = var.region
  zone    = var.zone
}

terraform {
  backend "gcs" {
  }
}

##############################################
# Service Account
##############################################
resource "google_service_account" "sa_functions_pq_converter" {
  account_id   = "sa-functions-pq-converter"
  display_name = "sa-functions-pq-converter"
}

resource "google_service_account" "sa_functions_got" {
  account_id   = "sa-functions-got"
  display_name = "sa-functions-got"
}

##############################################
# Cloud Storage
##############################################
resource "google_storage_bucket" "csv_bucket" {
  name          = "${var.project}-csv-bucket"
  location      = var.region
  storage_class = "REGIONAL"
}

resource "google_storage_bucket" "zip_bucket" {
  name          = "${var.project}-zip-bucket"
  location      = var.region
  storage_class = "REGIONAL"
}

##############################################
# Cloud Functions
# https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/cloudfunctions_function
##############################################

# pq_converter
resource "google_cloudfunctions_function" "pq_converter" {
  name                  = "pq_converter"
  description           = "convert from csv to parquet"
  runtime               = "python37"
  source_archive_bucket = google_storage_bucket.zip_bucket.name
  source_archive_object = google_storage_bucket_object.packages_pq_converter.name
  available_memory_mb   = 128
  timeout               = 30
  entry_point           = "handler"
  service_account_email = google_service_account.sa_functions_pq_converter.email
  event_trigger {
    # https://cloud.google.com/functions/docs/calling/
    event_type = "google.storage.object.finalize"
    resource   = google_storage_bucket.csv_bucket.name
    failure_policy {
      retry = false
    }
  }
}

data "archive_file" "pq_converter" {
  type        = "zip"
  source_dir  = "src/python/pq_converter"
  output_path = "zip/python/pq_converter.zip"
}

resource "google_storage_bucket_object" "packages_pq_converter" {
  name   = "packages/python/pq_converter.${data.archive_file.pq_converter.output_md5}.zip"
  bucket = google_storage_bucket.zip_bucket.name
  source = data.archive_file.pq_converter.output_path
}

resource "google_cloudfunctions_function_iam_member" "pq_converter_member" {
  project        = google_cloudfunctions_function.pq_converter.project
  region         = google_cloudfunctions_function.pq_converter.region
  cloud_function = google_cloudfunctions_function.pq_converter.name
  role           = "roles/cloudfunctions.invoker"
  member         = "serviceAccount:${google_service_account.sa_functions_pq_converter.email}"
}

# got
resource "google_cloudfunctions_function" "got" {
  name                  = "got"
  description           = "Game of Thrones"
  runtime               = "go113"
  source_archive_bucket = google_storage_bucket.zip_bucket.name
  source_archive_object = google_storage_bucket_object.function_got_packages.name
  available_memory_mb   = 128
  timeout               = 30
  entry_point           = "HelloHTTP"
  trigger_http          = true
  service_account_email = google_service_account.sa_functions_got.email
}

data "archive_file" "function_got_archive" {
  type        = "zip"
  source_dir  = "src/go/got"
  output_path = "zip/go/got.zip"
}

resource "google_storage_bucket_object" "function_got_packages" {
  name   = "packages/go/function_got.${data.archive_file.function_got_archive.output_md5}.zip"
  bucket = google_storage_bucket.zip_bucket.name
  source = data.archive_file.function_got_archive.output_path
}

resource "google_cloudfunctions_function_iam_member" "got_member" {
  project        = google_cloudfunctions_function.got.project
  region         = google_cloudfunctions_function.got.region
  cloud_function = google_cloudfunctions_function.got.name
  role           = "roles/cloudfunctions.invoker"
  member         = "serviceAccount:${google_service_account.sa_functions_got.email}"
}

##############################################
# Cloud Run
##############################################
resource "google_cloud_run_service" "helloworld" {
  name     = "helloworld"
  location = var.region
  template {
    spec {
      containers {
        image = "gcr.io/${var.project}/helloworld"
      }
    }
  }
  traffic {
    percent         = 100
    latest_revision = true
  }
}

# Enable public access on Cloud Run service
resource "google_cloud_run_service_iam_policy" "noauth" {
  location    = google_cloud_run_service.helloworld.location
  project     = google_cloud_run_service.helloworld.project
  service     = google_cloud_run_service.helloworld.name
  policy_data = data.google_iam_policy.noauth.policy_data
}

##############################################
# Cloud IAM
##############################################
data "google_iam_policy" "noauth" {
  binding {
    role = "roles/run.invoker"
    members = [
      "allUsers",
    ]
  }
}

resource "google_project_iam_member" "cloud_storage_admin" {
  role   = "roles/storage.objectAdmin"
  member = "serviceAccount:${google_service_account.sa_functions_pq_converter.email}"
}

resource "google_project_iam_member" "cloud_storage_admin_got" {
  role   = "roles/storage.objectAdmin"
  member = "serviceAccount:${google_service_account.sa_functions_got.email}"
}

##############################################
# Output
##############################################
output "cloud_run_url" {
  value = google_cloud_run_service.helloworld.status[0].url
}

output "function_got_url" {
  value = google_cloudfunctions_function.got.https_trigger_url
}
