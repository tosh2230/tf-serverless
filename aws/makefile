#!/bin/bash

docker-compose up -d
aws s3 --endpoint-url=http://localhost:4566 mb s3://tf-serverless-tosh2230 --profile=localstack --cli-connect-timeout 6000
aws s3 --endpoint-url=http://localhost:4566 cp ./tests/data/c01.csv s3://tf-serverless-tosh2230 --profile=localstack --cli-connect-timeout 6000

sam build --use-container
sam local invoke FunctionPqConverter --event ./tests/data/s3_event.json  --profile=localstack  --docker-network 36189632d3e9
docker-compose stop