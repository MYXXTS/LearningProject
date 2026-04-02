import os
import shutil
import uuid

from fastapi import APIRouter, Depends, File, HTTPException, UploadFile
from sqlalchemy.orm import Session

from ..config import settings
from ..db import get_db
from ..models import Dataset
from ..schemas import DatasetOut
from ..services.preprocessing import get_eda, load_csv, preprocess_df

router = APIRouter()


@router.post("/upload", response_model=DatasetOut)
def upload_dataset(file: UploadFile = File(...), db: Session = Depends(get_db)):
    if not (file.filename or "").lower().endswith(".csv"):
        raise HTTPException(status_code=400, detail="仅支持 CSV 文件")

    os.makedirs(settings.UPLOAD_DIR, exist_ok=True)
    safe_name = f"{uuid.uuid4().hex}_{os.path.basename(file.filename)}"
    file_path = os.path.join(settings.UPLOAD_DIR, safe_name)

    with open(file_path, "wb") as fp:
        shutil.copyfileobj(file.file, fp)

    try:
        df = preprocess_df(load_csv(file_path))
    except Exception as exc:
        os.remove(file_path)
        raise HTTPException(status_code=400, detail=f"解析 CSV 失败：{exc}")

    label_counts = df["label"].value_counts().to_dict()
    dataset = Dataset(
        name=file.filename,
        file_path=file_path,
        total_rows=int(len(df)),
        spam_count=int(label_counts.get("spam", 0)),
        ham_count=int(label_counts.get("ham", 0)),
    )
    db.add(dataset)
    db.commit()
    db.refresh(dataset)
    return dataset


@router.get("/", response_model=list[DatasetOut])
def list_datasets(db: Session = Depends(get_db)):
    return db.query(Dataset).order_by(Dataset.created_at.desc()).all()


@router.get("/{dataset_id}/eda")
def get_dataset_eda(dataset_id: int, db: Session = Depends(get_db)):
    dataset = db.query(Dataset).filter(Dataset.id == dataset_id).first()
    if not dataset:
        raise HTTPException(status_code=404, detail="数据集不存在")

    try:
        df = preprocess_df(load_csv(dataset.file_path))
        return get_eda(df)
    except Exception as exc:
        raise HTTPException(status_code=500, detail=f"EDA 分析失败：{exc}")
