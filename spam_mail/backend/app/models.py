from datetime import datetime

from sqlalchemy import Column, Integer, String, Text, DateTime, Float

from .db import Base


class Dataset(Base):
    __tablename__ = "datasets"

    id = Column(Integer, primary_key=True, index=True)
    name = Column(String(255), nullable=False)
    file_path = Column(String(500), nullable=False)
    total_rows = Column(Integer, default=0)
    spam_count = Column(Integer, default=0)
    ham_count = Column(Integer, default=0)
    created_at = Column(DateTime, default=datetime.utcnow)


class TrainingJob(Base):
    __tablename__ = "training_jobs"

    id = Column(Integer, primary_key=True, index=True)
    dataset_id = Column(Integer, nullable=False)
    status = Column(String(20), default="pending")  # pending/running/done/failed

    # Random Forest metrics
    rf_accuracy = Column(Float)
    rf_precision = Column(Float)
    rf_recall = Column(Float)
    rf_f1 = Column(Float)
    rf_report = Column(Text)
    rf_model_path = Column(String(500))

    # Decision Tree metrics (baseline)
    dt_accuracy = Column(Float)
    dt_precision = Column(Float)
    dt_recall = Column(Float)
    dt_f1 = Column(Float)
    dt_report = Column(Text)
    dt_model_path = Column(String(500))

    n_estimators = Column(Integer, default=100)
    balance = Column(Integer, default=1)  # 1=True, 0=False

    created_at = Column(DateTime, default=datetime.utcnow)
    completed_at = Column(DateTime)


class PredictionRecord(Base):
    __tablename__ = "prediction_records"

    id = Column(Integer, primary_key=True, index=True)
    job_id = Column(Integer, nullable=False)
    message = Column(Text, nullable=False)
    prediction = Column(String(10), nullable=False)
    confidence = Column(Float, nullable=False)
    created_at = Column(DateTime, default=datetime.utcnow)
