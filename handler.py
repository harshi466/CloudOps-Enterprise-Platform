"""S3-triggered Lambda: runs when a receipt is uploaded and records its metadata in DynamoDB."""
import datetime
import os
import urllib.parse

import boto3

table = boto3.resource("dynamodb").Table(os.environ["RECEIPTS_TABLE"])


def handler(event, context):
    count = 0
    for rec in event.get("Records", []):
        bucket = rec["s3"]["bucket"]["name"]
        key = urllib.parse.unquote_plus(rec["s3"]["object"]["key"])
        parts = key.split("/")  # receipts/<user_id>/<uuid>.jpg
        table.put_item(Item={
            "receipt_key": key,
            "bucket": bucket,
            "user_id": parts[1] if len(parts) > 2 else "unknown",
            "size_bytes": rec["s3"]["object"].get("size", 0),
            "uploaded_at": datetime.datetime.utcnow().isoformat(),
            "status": "RECEIVED",
        })
        count += 1
        print(f"processed receipt s3://{bucket}/{key}")
    return {"processed": count}
