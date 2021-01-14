# https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/cloudfunctions_function
# https://qiita.com/nii_yan/items/c03871ec252b12fb238d

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
  location      = "us-east1"
  storage_class = "REGIONAL"
}

data "archive_file" "py_function_archive" {
  type        = "zip"
  source_dir  = "src/python/pq-converter"
  output_path = "zip/python/pq-converter.zip"
}

resource "google_storage_bucket" "zip_bucket" {
  name          = "${var.project}-zip-bucket"
  location      = "us-east1"
  storage_class = "REGIONAL"
}

resource "google_storage_bucket_object" "py_packages" {
  name   = "packages/python/pq-converter.${data.archive_file.py_function_archive.output_md5}.zip"
  bucket = google_storage_bucket.zip_bucket.name
  source = data.archive_file.py_function_archive.output_path
}

resource "google_cloudfunctions_function" "pq-converter" {
  name                  = "pq-converter"
  description           = "convert from csv to parquet"
  runtime               = "python37"
  source_archive_bucket = google_storage_bucket.zip_bucket.name
  source_archive_object = google_storage_bucket_object.py_packages.name
  available_memory_mb   = 128
  timeout               = 30
  entry_point           = "handler"
  # https://cloud.google.com/functions/docs/calling/
  event_trigger {
    event_type = "google.storage.object.finalize"
    resource   = google_storage_bucket.csv_bucket.name
    failure_policy {
      retry = false
    }
  }
}
