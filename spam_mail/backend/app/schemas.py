from datetime import datetime
from typing import Optional

from pydantic import BaseModel


# ---------- Dataset ----------

class DatasetOut(BaseModel):
    id: int
    name: str
    total_rows: int
    spam_count: int
    ham_count: int
    created_at: datetime

    model_config = {"from_attributes": True}


# ---------- Training ----------

class TrainRequest(BaseModel):
    dataset_id: int
    n_estimators: int = 100
    balance: bool = True


class TrainingJobOut(BaseModel):
    id: int
    dataset_id: int
    status: str
    rf_accuracy: Optional[float] = None
    rf_precision: Optional[float] = None
    rf_recall: Optional[float] = None
    rf_f1: Optional[float] = None
    rf_report: Optional[str] = None
    rf_model_path: Optional[str] = None
    dt_accuracy: Optional[float] = None
    dt_precision: Optional[float] = None
    dt_recall: Optional[float] = None
    dt_f1: Optional[float] = None
    dt_report: Optional[str] = None
    dt_model_path: Optional[str] = None
    n_estimators: Optional[int] = None
    balance: Optional[int] = None
    created_at: datetime
    completed_at: Optional[datetime] = None

    model_config = {"from_attributes": True}


# ---------- Prediction ----------

class PredictSingleRequest(BaseModel):
    job_id: int
    message: str


class PredictSingleOut(BaseModel):
    prediction: str
    confidence: float
    message: str
