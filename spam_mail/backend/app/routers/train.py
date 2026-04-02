from datetime import datetime

from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy.orm import Session

from ..config import settings
from ..db import get_db
from ..models import Dataset, TrainingJob
from ..schemas import TrainRequest, TrainingJobOut
from ..services.training import train_models

router = APIRouter()


@router.post("/", response_model=TrainingJobOut)
def start_training(req: TrainRequest, db: Session = Depends(get_db)):
    dataset = db.query(Dataset).filter(Dataset.id == req.dataset_id).first()
    if not dataset:
        raise HTTPException(status_code=404, detail="数据集不存在")

    job = TrainingJob(
        dataset_id=req.dataset_id,
        status="running",
        n_estimators=req.n_estimators,
        balance=int(req.balance),
    )
    db.add(job)
    db.commit()
    db.refresh(job)

    try:
        results = train_models(
            file_path=dataset.file_path,
            job_id=job.id,
            model_dir=settings.MODEL_DIR,
            n_estimators=req.n_estimators,
            balance=req.balance,
        )
        rf = results["rf"]
        dt = results["dt"]

        job.status = "done"
        job.rf_accuracy = rf["accuracy"]
        job.rf_precision = rf["precision"]
        job.rf_recall = rf["recall"]
        job.rf_f1 = rf["f1"]
        job.rf_report = rf["report"]
        job.rf_model_path = rf["model_path"]
        job.dt_accuracy = dt["accuracy"]
        job.dt_precision = dt["precision"]
        job.dt_recall = dt["recall"]
        job.dt_f1 = dt["f1"]
        job.dt_report = dt["report"]
        job.dt_model_path = dt["model_path"]
        job.completed_at = datetime.utcnow()
        db.commit()
        db.refresh(job)
    except Exception as exc:
        job.status = "failed"
        db.commit()
        raise HTTPException(status_code=500, detail=f"训练失败：{exc}")

    return job


@router.get("/jobs", response_model=list[TrainingJobOut])
def list_jobs(db: Session = Depends(get_db)):
    return db.query(TrainingJob).order_by(TrainingJob.created_at.desc()).all()


@router.get("/jobs/{job_id}", response_model=TrainingJobOut)
def get_job(job_id: int, db: Session = Depends(get_db)):
    job = db.query(TrainingJob).filter(TrainingJob.id == job_id).first()
    if not job:
        raise HTTPException(status_code=404, detail="训练任务不存在")
    return job
