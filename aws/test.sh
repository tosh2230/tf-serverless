#!/bin/bash

# ENDPOINT_IP=Please set your private ip-address('localhost' doesn't work)
ENDPOINT_PORT=4566
BUCKET_NAME=tf-serverless-tosh2230
TEST_DATA_PATH=./tests/data/c01.csv
TEST_EVENT_PATH=./tests/data/s3_event.json

# Setup Localstack
TMPDIR=/private$TMPDIR \
DATA_DIR=/tmp/localstack/data \
docker-compose up -d

NETWORK_ID=$(docker network ls | awk '/.+aws_default.+/' | awk '{print substr($0, 0, 13)}')
echo NETWORK_ID=${NETWORK_ID}

# Wait docker-compose up
sleep 15

# Make a S3 bucket and put test data
aws s3 --endpoint-url=http://${ENDPOINT_IP}:${ENDPOINT_PORT} mb s3://${BUCKET_NAME} --profile=localstack --cli-connect-timeout 6000
aws s3 --endpoint-url=http://${ENDPOINT_IP}:${ENDPOINT_PORT} cp ${TEST_DATA_PATH} s3://${BUCKET_NAME} --profile=localstack --cli-connect-timeout 6000

# Unit Testing
pytest -v

# Create env-file
printf '{
    "Parameters": {
        "ENDPOINT": "localstack",
        "ENDPOINT_URL": "http://%s:%s"
    }
}' ${ENDPOINT_IP} ${ENDPOINT_PORT} | jq > ./vars.json

# Interface Testing
sam build --use-container
sam local invoke FunctionPqConverter --event ${TEST_EVENT_PATH} --profile=localstack  --docker-network ${NETWORK_ID} --env-vars vars.json --log-file test.log

# Remove Localstack
rm -f ./vars.json
TMPDIR=/private$TMPDIR \
DATA_DIR=/tmp/localstack/data \
docker-compose down -v
