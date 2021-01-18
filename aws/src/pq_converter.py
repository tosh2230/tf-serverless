import os
import io
import logging
import tempfile
import urllib
from typing import Tuple

import boto3
import pandas as pd
import pyarrow as pa
import pyarrow.parquet as pq

# logger
logger = logging.getLogger(__name__)
logger.setLevel(logging.INFO)


class LambdaProcessor(object):
    def __init__(self, event, context, s3):
        self.event = event
        self.context = context
        self.s3 = s3

    def main(self) -> dict:
        try:
            bucket: str
            csv_key: str
            bucket, csv_key = self.read_s3_event(event=self.event)
            csv_body: str = self.get_s3_data(bucket=bucket, key=csv_key)
            df: pd.DataFrame = self.make_df(body=csv_body)

            pq_key: str = csv_key.replace("csv", "parquet")
            pq_name: str = pq_key.split("/")[-1]

            with tempfile.TemporaryDirectory() as tmp_dir:
                pq_tmp_path: str = f"{tmp_dir}/{pq_name}"
                self.create_pq(df=df, path=pq_tmp_path)
                self.upload_file(path=pq_tmp_path, bucket=bucket, key=pq_key)

            return {
                "StatusCode": 200,
                "Bucket": bucket,
                "Key": pq_key
            }

        except Exception as e:
            logger.exception(e)
            raise e

    def read_s3_event(self, event: dict) -> Tuple[str, str]:
        bucket = event["Records"][0]["s3"]["bucket"]["name"]
        key = urllib.parse.unquote_plus(
            event["Records"][0]["s3"]["object"]["key"], encoding="utf-8"
        )
        return bucket, key

    def get_s3_data(self, bucket: str, key: str) -> str:
        return (
            self.s3.meta.client.get_object(Bucket=bucket, Key=key)["Body"]
            .read()
            .decode("utf-8")
        )

    def make_df(self, body: str) -> pd.DataFrame:
        return pd.read_csv(io.StringIO(body), encoding="utf-8", header=0)

    def create_pq(self, df: pd.DataFrame, path: str) -> None:
        pq.write_table(pa.Table.from_pandas(df), path, compression="snappy")

    def upload_file(self, path: str, bucket: str, key: str) -> dict:
        self.s3.Bucket(bucket).upload_file(Filename=path, Key=key)
