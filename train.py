"""Trains the seasonal-index model used by the serverless /predict endpoint.

Reads monthly spend history from a CSV (month,total), computes each calendar month's
seasonal index (avg of month / avg overall) and writes model.json.
Usage: python ml/train.py --input data/monthly_spend.csv --output ml/model.json [--upload-bucket BUCKET]
"""
import argparse
import csv
import json
import os
import random


def make_sample(path):
    random.seed(7)
    season = [0.95, 0.9, 0.95, 1.0, 1.0, 0.95, 1.0, 1.05, 1.0, 1.25, 1.15, 1.3]  # festive spike Oct-Dec
    os.makedirs(os.path.dirname(path), exist_ok=True)
    with open(path, "w", newline="") as f:
        w = csv.writer(f)
        w.writerow(["month", "total"])
        for i in range(36):
            y, m = 2023 + i // 12, i % 12 + 1
            w.writerow([f"{y}-{m:02d}", round((20000 + 150 * i) * season[m - 1] * random.uniform(0.95, 1.05), 2)])


def train(rows):
    overall = sum(r[1] for r in rows) / len(rows)
    buckets = {m: [] for m in range(1, 13)}
    for month, total in rows:
        buckets[int(month.split("-")[1])].append(total)
    seasonal = [round((sum(v) / len(v)) / overall, 4) if v else 1.0 for v in buckets.values()]
    return {"version": "seasonal-v1", "samples": len(rows), "seasonal": seasonal}


if __name__ == "__main__":
    ap = argparse.ArgumentParser()
    ap.add_argument("--input", default="data/monthly_spend.csv")
    ap.add_argument("--output", default="ml/model.json")
    ap.add_argument("--upload-bucket")
    a = ap.parse_args()
    if not os.path.exists(a.input):
        make_sample(a.input)
    with open(a.input) as f:
        rows = [(r["month"], float(r["total"])) for r in csv.DictReader(f)]
    model = train(rows)
    with open(a.output, "w") as f:
        json.dump(model, f, indent=2)
    print("model saved:", a.output, model)
    if a.upload_bucket:
        import boto3
        boto3.client("s3").upload_file(a.output, a.upload_bucket, "models/model.json")
        print("uploaded to s3://%s/models/model.json" % a.upload_bucket)
