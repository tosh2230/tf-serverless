import pytest
import os
import json
import boto3

from src.pq_converter import LambdaProcessor

pq_path = "./tests/data/c01.parquet"


@pytest.fixture(scope="session")
def processor():
    with open("./tests/data/s3_event.json", "r") as f:
        test_event = json.load(f)

    s3 = boto3.resource("s3", endpoint_url="http://localhost:4566")
    processor = LambdaProcessor(event=test_event, context={}, s3=s3)
    return processor


@pytest.fixture
def read_event(processor):
    yield processor.read_s3_event(event=processor.event)


@pytest.fixture
def get_s3_data(processor, read_event):
    yield processor.get_s3_data(bucket=read_event[0], key=read_event[1])


@pytest.fixture
def read_csv(processor):
    with open("./tests/data/c01.csv", "r", encoding="utf-8") as f:
        csv_data = f.read()

    yield processor.make_df(csv_data)


@pytest.fixture
def create_pq(processor, read_csv):
    if os.path.exists(pq_path):
        os.remove(pq_path)
    processor.create_pq(read_csv, pq_path)
    yield pq_path


@pytest.fixture
def upload_file(processor, read_event):
    bucket = read_event[0]
    key = read_event[1].replace("csv", "parquet")
    processor.upload_file(path=pq_path, bucket=bucket, key=key)

    response = processor.s3.meta.client.get_object(Bucket=bucket, Key=key)
    return response
