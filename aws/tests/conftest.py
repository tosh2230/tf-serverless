import pytest
import os
import json
import src.pq_converter as pq_converter


@pytest.fixture
def read_event():
    with open("./tests/data/s3_event.json", "r") as f:
        test_event = json.load(f)

    yield pq_converter.read_s3_event(event=test_event)


@pytest.fixture
def read_csv():
    with open("./tests/data/c01.csv", "r", encoding="utf-8") as f:
        yield pq_converter.make_df(f.read())


@pytest.fixture
def create_pq(read_csv):
    file_path = "./tests/data/c01.parquet"
    if os.path.exists(file_path):
        os.remove(file_path)
    pq_converter.create_pq(read_csv, file_path)
    yield file_path