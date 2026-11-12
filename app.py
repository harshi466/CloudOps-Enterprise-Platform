"""Expense microservice: CRUD, summaries, receipt upload URLs, streaming events, forecast."""
import datetime
import json
import os
import urllib.request
import uuid
from collections import defaultdict
from functools import wraps

import jwt
from flask import Flask, g, jsonify, request
from sqlalchemy import Column, Date, Float, Integer, String, create_engine
from sqlalchemy.orm import declarative_base, sessionmaker

from forecast import forecast_next

Base = declarative_base()
CATEGORIES = {"food", "travel", "rent", "shopping", "bills", "health", "other"}


class Expense(Base):
    __tablename__ = "expenses"
    id = Column(Integer, primary_key=True)
    user_id = Column(Integer, index=True, nullable=False)
    title = Column(String(200), nullable=False)
    category = Column(String(40), nullable=False)
    amount = Column(Float, nullable=False)
    spent_on = Column(Date, nullable=False)
    receipt_key = Column(String(300))

    def to_dict(self):
        return dict(id=self.id, title=self.title, category=self.category, amount=self.amount,
                    spent_on=self.spent_on.isoformat(), receipt_key=self.receipt_key)


def create_app(db_url=None):
    app = Flask(__name__)
    secret = os.environ.get("JWT_SECRET", "dev-secret-change-me")
    engine = create_engine(db_url or os.environ.get("DATABASE_URL", "sqlite:///expenses.db"), pool_pre_ping=True)
    Base.metadata.create_all(engine)
    Session = sessionmaker(bind=engine)

    def auth(fn):
        @wraps(fn)
        def wrapper(*a, **kw):
            try:
                claims = jwt.decode(request.headers.get("Authorization", "").removeprefix("Bearer "),
                                    secret, algorithms=["HS256"])
                g.user_id = int(claims["sub"])
            except (jwt.PyJWTError, KeyError, ValueError):
                return jsonify(error="unauthorized"), 401
            return fn(*a, **kw)
        return wrapper

    def publish_event(exp):
        """Send a transaction event to Kinesis (feeds the Big-Data pipeline). Best-effort."""
        stream = os.environ.get("KINESIS_STREAM")
        if not stream:
            return
        try:
            import boto3
            boto3.client("kinesis").put_record(
                StreamName=stream, PartitionKey=str(exp.user_id),
                Data=(json.dumps(dict(expense_id=exp.id, user_id=exp.user_id, category=exp.category,
                                      amount=exp.amount, event_time=datetime.datetime.utcnow().isoformat())) + "\n").encode())
        except Exception as e:  # never fail the request because of analytics
            app.logger.warning("kinesis publish failed: %s", e)

    @app.get("/health")
    def health():
        return jsonify(status="ok", service="expense-service")

    @app.get("/api/expenses")
    @auth
    def list_expenses():
        with Session() as s:
            rows = s.query(Expense).filter_by(user_id=g.user_id).order_by(Expense.spent_on.desc()).all()
            return jsonify([r.to_dict() for r in rows])

    @app.post("/api/expenses")
    @auth
    def add_expense():
        d = request.get_json(silent=True) or {}
        try:
            amount = float(d["amount"])
            spent_on = datetime.date.fromisoformat(d.get("spent_on") or datetime.date.today().isoformat())
            title, category = d["title"].strip(), d.get("category", "other").lower()
        except (KeyError, ValueError, AttributeError):
            return jsonify(error="title, amount (number) and valid spent_on (YYYY-MM-DD) required"), 400
        if amount <= 0 or category not in CATEGORIES or not title:
            return jsonify(error=f"amount must be > 0 and category one of {sorted(CATEGORIES)}"), 400
        with Session() as s:
            exp = Expense(user_id=g.user_id, title=title, category=category, amount=amount,
                          spent_on=spent_on, receipt_key=d.get("receipt_key"))
            s.add(exp)
            s.commit()
            publish_event(exp)
            return jsonify(exp.to_dict()), 201

    @app.delete("/api/expenses/<int:eid>")
    @auth
    def delete_expense(eid):
        with Session() as s:
            exp = s.query(Expense).filter_by(id=eid, user_id=g.user_id).first()
            if not exp:
                return jsonify(error="not found"), 404
            s.delete(exp)
            s.commit()
            return "", 204

    def monthly_totals(s):
        by_month = defaultdict(float)
        for e in s.query(Expense).filter_by(user_id=g.user_id).all():
            by_month[e.spent_on.strftime("%Y-%m")] += e.amount
        return dict(sorted(by_month.items()))

    @app.get("/api/expenses/summary")
    @auth
    def summary():
        with Session() as s:
            by_cat = defaultdict(float)
            for e in s.query(Expense).filter_by(user_id=g.user_id).all():
                by_cat[e.category] += e.amount
            return jsonify(by_category=dict(by_cat), by_month=monthly_totals(s))

    @app.get("/api/expenses/predict")
    @auth
    def predict():
        with Session() as s:
            totals = list(monthly_totals(s).values())
        url = os.environ.get("PREDICT_API_URL")  # serverless ML endpoint (API Gateway + Lambda)
        if url:
            try:
                req = urllib.request.Request(url, data=json.dumps({"monthly_totals": totals}).encode(),
                                             headers={"Content-Type": "application/json"}, method="POST")
                with urllib.request.urlopen(req, timeout=5) as r:
                    return jsonify(json.loads(r.read()))
            except Exception as e:
                app.logger.warning("predict API failed, using local fallback: %s", e)
        return jsonify(next_month_forecast=forecast_next(totals), source="local-fallback")

    @app.post("/api/expenses/receipt-url")
    @auth
    def receipt_url():
        bucket = os.environ.get("RECEIPT_BUCKET")
        if not bucket:
            return jsonify(error="receipt storage not configured"), 503
        import boto3
        key = f"receipts/{g.user_id}/{uuid.uuid4()}.jpg"
        url = boto3.client("s3").generate_presigned_url(
            "put_object", Params={"Bucket": bucket, "Key": key, "ContentType": "image/jpeg"}, ExpiresIn=300)
        return jsonify(upload_url=url, key=key)

    return app
