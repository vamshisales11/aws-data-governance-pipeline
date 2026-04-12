import json
import boto3
import os

s3 = boto3.client("s3")
stepfunctions = boto3.client("stepfunctions")

def lambda_handler(event, context):
    print("Received event:", json.dumps(event))

    # Extract bucket & key
    bucket = event["detail"]["bucket"]["name"]
    key = event["detail"]["object"]["key"]

    # Get object metadata
    response = s3.head_object(Bucket=bucket, Key=key)
    size = response["ContentLength"]

    # 🚨 CHECK: skip empty files
    if size == 0:
        print("Empty file detected. Skipping pipeline trigger.")
        return {
            "statusCode": 200,
            "body": "Empty file skipped"
        }

    # Trigger Step Function
    response = stepfunctions.start_execution(
        stateMachineArn=os.environ["STEP_FUNCTION_ARN"],
        input=json.dumps(event)
    )

    return {
        "statusCode": 200,
        "executionArn": response["executionArn"]
    }