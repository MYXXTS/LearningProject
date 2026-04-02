import io

from fastapi import APIRouter, Depends, File, HTTPException, UploadFile
from fastapi.responses import StreamingResponse
from sqlalchemy.orm import Session

from ..db import get_db
from ..models import PredictionRecord, TrainingJob
from ..schemas import PredictSingleOut, PredictSingleRequest
from ..services.prediction import predict_batch_csv, predict_single

router = APIRouter()


@router.post("/single", response_model=PredictSingleOut)
def predict_single_msg(req: PredictSingleRequest, db: Session = Depends(get_db)):
    if not req.message.strip():
        raise HTTPException(status_code=400, detail="消息内容不能为空")

    job = (
        db.query(TrainingJob)
        .filter(TrainingJob.id == req.job_id, TrainingJob.status == "done")
        .first()
    )
    if not job:
        raise HTTPException(status_code=404, detail="训练任务不存在或尚未完成")

    result = predict_single(job.rf_model_path, req.message)

    record = PredictionRecord(
        job_id=req.job_id,
        message=req.message,
        prediction=result["prediction"],
        confidence=result["confidence"],
    )
    db.add(record)
    db.commit()

    return PredictSingleOut(
        prediction=result["prediction"],
        confidence=result["confidence"],
        message=req.message,
    )


@router.post("/batch")
def predict_batch(
    job_id: int, file: UploadFile = File(...), db: Session = Depends(get_db)
):
    job = (
        db.query(TrainingJob)
        .filter(TrainingJob.id == job_id, TrainingJob.status == "done")
        .first()
    )
    if not job:
        raise HTTPException(status_code=404, detail="训练任务不存在或尚未完成")

    file_bytes = file.file.read()
    try:
        results = predict_batch_csv(job.rf_model_path, file_bytes)
    except Exception as exc:
        raise HTTPException(status_code=500, detail=f"批量预测失败：{exc}")

    # Return CSV
    out = io.StringIO()
    out.write("message,prediction,confidence\n")
    for r in results:
        msg = r["message"].replace('"', '""')
        out.write(f'"{msg}",{r["prediction"]},{r["confidence"]}\n')
    out.seek(0)
    return StreamingResponse(
        io.BytesIO(out.getvalue().encode("utf-8")),
        media_type="text/csv; charset=utf-8",
        headers={"Content-Disposition": 'attachment; filename="predictions.csv"'},
    )


@router.get("/history")
def get_prediction_history(limit: int = 50, db: Session = Depends(get_db)):
    records = (
        db.query(PredictionRecord)
        .order_by(PredictionRecord.created_at.desc())
        .limit(limit)
        .all()
    )
    return [
        {
            "id": r.id,
            "job_id": r.job_id,
            "message": r.message[:120],
            "prediction": r.prediction,
            "confidence": r.confidence,
            "created_at": r.created_at,
        }
        for r in records
    ]
