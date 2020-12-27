import pytest
import os


@pytest.mark.usefixtures("read_event")
class TestReadS3Event:
    def test_bucket(self, read_event):
        assert read_event[0] == "tf-serverless-tosh2230"

    def test_key(self, read_event):
        assert read_event[1] == "c01.csv"


@pytest.mark.usefixtures("get_s3_data")
class TestGetS3Data:
    def test_is_s3_data_found(self, get_s3_data):
        assert get_s3_data is not None


@pytest.mark.usefixtures("read_csv")
class TestMakeDataframe:
    def test_row_length(self, read_csv):
        assert len(read_csv) == 10000

    def test_column_length(self, read_csv):
        assert len(read_csv.columns) == 6


@pytest.mark.usefixtures("create_pq")
class TestCreateParquet:
    def test_is_exist_file(self, create_pq):
        assert os.path.exists(create_pq) == True


@pytest.mark.usefixtures("upload_file")
class TestUploadFile:
    def test_is_uploading_succeeded(self, upload_file):
        assert upload_file is not None