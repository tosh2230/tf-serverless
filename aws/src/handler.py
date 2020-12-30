import os
import boto3
from botocore.config import Config
from pq_converter import LambdaProcessor

endpoint = os.environ["ENDPOINT"]
endpoint_url = os.environ["ENDPOINT_URL"]

# boto3 session
session = boto3.Session()

if endpoint == "localstack":
    print("Start Testing with Localstack")
    s3 = session.resource("s3", endpoint_url=endpoint_url, config=Config())
else:
    s3 = session.resource("s3")


def lambda_handler(event, context) -> dict:
    processor = LambdaProcessor(event=event, context=context, s3=s3)
    return processor.main()