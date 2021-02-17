provider "google" {
  version = "3.52.0"
  project = var.project
  region  = var.region
  zone    = var.zone
}

terraform {
  backend "gcs" {
  }
}

resource "google_storage_bucket" "csv_bucket" {
  name          = "${var.project}-csv-bucket"
  location      = var.region
  storage_class = "REGIONAL"
}

data "archive_file" "py_function_archive" {
  type        = "zip"
  source_dir  = "src/python/pq-converter"
  output_path = "zip/python/pq-converter.zip"
}

resource "google_storage_bucket" "zip_bucket" {
  name          = "${var.project}-zip-bucket"
  location      = var.region
  storage_class = "REGIONAL"
}

resource "google_storage_bucket_object" "py_packages" {
  name   = "packages/python/pq-converter.${data.archive_file.py_function_archive.output_md5}.zip"
  bucket = google_storage_bucket.zip_bucket.name
  source = data.archive_file.py_function_archive.output_path
}

# https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/cloudfunctions_function
resource "google_cloudfunctions_function" "pq-converter" {
  name                  = "pq-converter"
  description           = "convert from csv to parquet"
  runtime               = "python37"
  source_archive_bucket = google_storage_bucket.zip_bucket.name
  source_archive_object = google_storage_bucket_object.py_packages.name
  available_memory_mb   = 128
  timeout               = 30
  entry_point           = "handler"
  service_account_email = google_service_account.sa.email
  event_trigger {
    # https://cloud.google.com/functions/docs/calling/
    event_type = "google.storage.object.finalize"
    resource   = google_storage_bucket.csv_bucket.name
    failure_policy {
      retry = false
    }
  }
}

resource "google_service_account" "sa" {
  account_id   = "pq-converter"
  display_name = "pq-converter"
}

resource "google_project_iam_member" "cloud_storage_admin" {
  role   = "roles/storage.objectAdmin"
  member = "serviceAccount:${google_service_account.sa.email}"
}

resource "google_cloudfunctions_function_iam_member" "member" {
  project        = google_cloudfunctions_function.pq-converter.project
  region         = google_cloudfunctions_function.pq-converter.region
  cloud_function = google_cloudfunctions_function.pq-converter.name
  role           = "roles/cloudfunctions.invoker"
  member         = "serviceAccount:${google_service_account.sa.email}"
}

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

data "google_iam_policy" "noauth" {
  binding {
    role = "roles/run.invoker"
    members = [
      "allUsers",
    ]
  }
}
# Enable public access on Cloud Run service
resource "google_cloud_run_service_iam_policy" "noauth" {
  location    = google_cloud_run_service.helloworld.location
  project     = google_cloud_run_service.helloworld.project
  service     = google_cloud_run_service.helloworld.name
  policy_data = data.google_iam_policy.noauth.policy_data
}

output "url" {
  value = google_cloud_run_service.helloworld.status[0].url
}
