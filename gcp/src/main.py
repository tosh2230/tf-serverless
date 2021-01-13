from google.cloud import storage
import pandas as pd
import pyarrow as pa
import pyarrow.parquet as pq

def handler(event, context):
    # print('Event ID: {}'.format(context.event_id))
    # print('Event type: {}'.format(context.event_type))
    # print('Bucket: {}'.format(event['bucket']))
    # print('File: {}'.format(event['bucket']))
    # print('Metageneration: {}'.format(event['metageneration']))
    # print('Created: {}'.format(event['timeCreated']))
    # print('Updated: {}'.format(event['updated']))

    if event['name'].split('.')[-1] != 'csv':
        return

    storage_client = storage.Client()
    bucket_name = event['bucket']
    bucket = storage_client.bucket(bucket_name)

    # download
    csv_file_name: str = event['name']
    csv_file_path: str = f'/tmp/{csv_file_name}'
    blob_csv = bucket.blob(event['name'])
    blob_csv.download_to_filename(csv_file_path)

    pq_file_name: str = event['name'].replace("csv", "parquet")
    pq_file_path: str = f'/tmp/{pq_file_name}'
    df: pd.DataFrame = pd.read_csv(csv_file_path, encoding="utf-8", header=0)
    pq.write_table(pa.Table.from_pandas(df), pq_file_path, compression="snappy")

    # upload
    blob_pq = bucket.blob(pq_file_name)
    blob_pq.upload_from_filename(pq_file_path)

    print(
        "File {} uploaded to {}.".format(
            pq_file_name, bucket_name
        )
    )
