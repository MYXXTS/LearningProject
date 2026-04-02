import os


class Settings:
    DB_HOST: str = os.getenv("DB_HOST", "127.0.0.1")
    DB_PORT: int = int(os.getenv("DB_PORT", "3306"))
    DB_USER: str = os.getenv("DB_USER", "root")
    DB_PASSWORD: str = os.getenv("DB_PASSWORD", "123456")
    DB_NAME: str = os.getenv("DB_NAME", "spam_detection")
    UPLOAD_DIR: str = os.getenv("UPLOAD_DIR", "data/uploads")
    MODEL_DIR: str = os.getenv("MODEL_DIR", "data/models")


settings = Settings()
