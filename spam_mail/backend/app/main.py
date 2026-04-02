import os

from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware

from .db import Base, ensure_database_exists, engine
from .routers import dataset, predict, train

os.makedirs("data/uploads", exist_ok=True)
os.makedirs("data/models", exist_ok=True)

ensure_database_exists()
Base.metadata.create_all(bind=engine)

app = FastAPI(
    title="基于集成学习的垃圾邮件分类系统",
    version="1.0.0",
    description="Vue + FastAPI + MySQL  |  Random Forest vs Decision Tree",
)

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

app.include_router(dataset.router, prefix="/api/dataset", tags=["数据集"])
app.include_router(train.router, prefix="/api/train", tags=["模型训练"])
app.include_router(predict.router, prefix="/api/predict", tags=["预测部署"])


@app.get("/api/health", tags=["系统"])
def health_check():
    return {"status": "ok", "message": "Service is running"}
