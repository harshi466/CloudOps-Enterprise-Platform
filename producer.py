"""Simulates live transactions and pushes them to Kinesis Data Streams.
Usage: python streaming/producer.py --stream cloudops-dev-expenses --count 200
"""
import argparse
import datetime
import json
import random
import time

import boto3

CATS = ["food", "travel", "rent", "shopping", "bills", "health", "other"]

ap = argparse.ArgumentParser()
ap.add_argument("--stream", required=True)
ap.add_argument("--count", type=int, default=100)
ap.add_argument("--delay", type=float, default=0.2)
a = ap.parse_args()

k = boto3.client("kinesis")
for i in range(a.count):
    evt = {"expense_id": i, "user_id": random.randint(1, 20), "category": random.choice(CATS),
           "amount": round(random.uniform(50, 5000), 2), "event_time": datetime.datetime.utcnow().isoformat()}
    k.put_record(StreamName=a.stream, PartitionKey=str(evt["user_id"]), Data=(json.dumps(evt) + "\n").encode())
    print("sent", evt)
    time.sleep(a.delay)
