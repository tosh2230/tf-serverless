import boto3
from pq_converter import LambdaProcessor

# boto3 session
session = boto3.Session()
s3 = session.resource("s3")


def lambda_handler(event, context):
    processor = LambdaProcessor(event, context, s3)
    processor.main()