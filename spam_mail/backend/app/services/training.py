"""Train Random Forest (core) and Decision Tree (baseline) models."""
import os
import pickle
from datetime import datetime

import pandas as pd
from sklearn.ensemble import RandomForestClassifier
from sklearn.feature_extraction.text import TfidfVectorizer
from sklearn.metrics import (
    accuracy_score,
    classification_report,
    f1_score,
    precision_score,
    recall_score,
)
from sklearn.model_selection import train_test_split
from sklearn.pipeline import Pipeline
from sklearn.tree import DecisionTreeClassifier

from .preprocessing import load_csv, preprocess_df


def train_models(
    file_path: str,
    job_id: int,
    model_dir: str,
    n_estimators: int = 100,
    balance: bool = True,
) -> dict:
    """Load dataset, optionally balance, train RF + DT, return metrics dict."""
    df = preprocess_df(load_csv(file_path))

    if balance:
        ham = df[df["label"] == "ham"]
        spam = df[df["label"] == "spam"]
        min_count = min(len(ham), len(spam))
        ham = ham.sample(min_count, random_state=42)
        spam = spam.sample(min_count, random_state=42)
        df = (
            pd.concat([ham, spam])
            .sample(frac=1, random_state=42)
            .reset_index(drop=True)
        )

    X, y = df["message"], df["label"]
    X_train, X_test, y_train, y_test = train_test_split(
        X, y, test_size=0.2, random_state=42, stratify=y
    )

    # ---- Random Forest (core ensemble model) ----
    rf_pipe = Pipeline(
        [
            ("tfidf", TfidfVectorizer(max_features=10000, ngram_range=(1, 2))),
            (
                "clf",
                RandomForestClassifier(
                    n_estimators=n_estimators, n_jobs=-1, random_state=42
                ),
            ),
        ]
    )
    rf_pipe.fit(X_train, y_train)
    rf_pred = rf_pipe.predict(X_test)

    # ---- Decision Tree (single-tree baseline) ----
    dt_pipe = Pipeline(
        [
            ("tfidf", TfidfVectorizer(max_features=10000, ngram_range=(1, 2))),
            ("clf", DecisionTreeClassifier(random_state=42)),
        ]
    )
    dt_pipe.fit(X_train, y_train)
    dt_pred = dt_pipe.predict(X_test)

    # Save models
    os.makedirs(model_dir, exist_ok=True)
    rf_path = os.path.join(model_dir, f"rf_job{job_id}.pkl")
    dt_path = os.path.join(model_dir, f"dt_job{job_id}.pkl")
    with open(rf_path, "wb") as f:
        pickle.dump(rf_pipe, f)
    with open(dt_path, "wb") as f:
        pickle.dump(dt_pipe, f)

    def _metrics(y_true, y_pred, model_path: str) -> dict:
        return {
            "accuracy": round(float(accuracy_score(y_true, y_pred)), 4),
            "precision": round(
                float(precision_score(y_true, y_pred, pos_label="spam")), 4
            ),
            "recall": round(
                float(recall_score(y_true, y_pred, pos_label="spam")), 4
            ),
            "f1": round(float(f1_score(y_true, y_pred, pos_label="spam")), 4),
            "report": classification_report(y_true, y_pred),
            "model_path": model_path,
        }

    return {
        "rf": _metrics(y_test, rf_pred, rf_path),
        "dt": _metrics(y_test, dt_pred, dt_path),
    }
