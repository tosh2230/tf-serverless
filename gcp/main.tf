# https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/cloudfunctions_function
# https://qiita.com/nii_yan/items/c03871ec252b12fb238d

data "archive_file" "function_archive" {
  type        = "zip"
  source_dir  = "src"
  output_path = "zip/functions.zip"
}

resource "google_storage_bucket" "bucket" {
  name          = "my-zip-bucket"
  location      = "US"
  storage_class = "STANDARD"
}

resource "google_storage_bucket_object" "packages" {
  name   = "packages/functions.${data.archive_file.function_archive.output_md5}.zip"
  bucket = google_storage_bucket.bucket.name
  source = data.archive_file.function_archive.output_path
}

resource "google_cloudfunctions_function" "function" {
  name                  = "pq-converter"
  description           = "convert from csv to parquet"
  runtime               = "python37"
  source_archive_bucket = google_storage_bucket.bucket.name
  source_archive_object = google_storage_bucket_object.packages.name
  available_memory_mb   = 128
  timeout               = 30
  entry_point           = "pq-converter"

  # https://cloud.google.com/functions/docs/calling/
  event_trigger {
    event_type = "google.storage.object.finalize"
    resource = "my-csv-bucket"
    failure_policy {
      retry = false
    }
  }
  service_account_email = "value"
}

# IAM entry for a single user to invoke the function
resource "google_cloudfunctions_function_iam_member" "invoker" {
  project        = google_cloudfunctions_function.function.project
  region         = google_cloudfunctions_function.function.region
  cloud_function = google_cloudfunctions_function.function.name

  role   = "roles/cloudfunctions.invoker"
  member = "user:myFunctionInvoker@example.com"
}
