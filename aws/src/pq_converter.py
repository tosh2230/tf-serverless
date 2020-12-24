import os
import logging
import urllib
from typing import Tuple

import boto3
import pandas as pd
import pyarrow as pa
import pyarrow.parquet as pq

# logger
logger = logging.getLogger(__name__)
logger.setLevel(logging.INFO)

# boto3 session
session = boto3.Session()
s3 = session.client("s3")


def lambda_handler(event, context):
    """
    csvファイルをparquetファイルに変換する

    Parameters
    ----------
    event : dict
        トリガーイベント情報
    context : dict
        実行環境情報

    Returns
    ----------
    response : dict
        アップロードリクエスト結果
    """
    try:
        bucket, csv_key = read_s3_event(event=event)
        csv_body = get_s3_data(bucket=bucket, key=csv_key)
        df = make_df(body=csv_body)

        pq_key = csv_key.replace("csv", "parquet")
        pq_name = pq_key.split("/")[-1]
        pq_tmp_path = f"/tmp/{pq_name}"
        create_pq(df=df, path=pq_tmp_path)

        return upload_file(path=pq_tmp_path, bucket=bucket, key=pq_key)

    except Exception as e:
        logger.exception(e)


def read_s3_event(event: dict) -> Tuple[str, str]:
    bucket = event["Records"][0]["s3"]["bucket"]["name"]
    key = urllib.parse.unquote_plus(
        event["Records"][0]["s3"]["object"]["key"], encoding="utf-8"
    )
    return bucket, key


def get_s3_data(bucket: str, key: str) -> str:
    return s3.get_object(Bucket=bucket, Key=key)["Body"].read()


def make_df(body: str) -> pd.DataFrame:
    return pd.read_csv(body, encoding="utf-8", header=0)


def create_pq(df: pd.DataFrame, path: str) -> None:
    pq.write_table(pa.Table.from_pandas(df), path, compression="snappy")


def upload_file(path: str, bucket: str, key: str) -> dict:
    with open(path) as f:
        return s3.put_object(Body=f.read(), Bucket=bucket, Key=key)
