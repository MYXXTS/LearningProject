"""Model loading (with cache) and prediction helpers."""
import csv
import io
import pickle

_model_cache: dict = {}


def _load_model(model_path: str):
    if model_path not in _model_cache:
        with open(model_path, "rb") as f:
            _model_cache[model_path] = pickle.load(f)
    return _model_cache[model_path]


def predict_single(model_path: str, message: str) -> dict:
    model = _load_model(model_path)
    prediction: str = model.predict([message])[0]
    proba = model.predict_proba([message])[0]
    classes: list = model.named_steps["clf"].classes_.tolist()
    confidence = float(proba[classes.index(prediction)])
    return {"prediction": prediction, "confidence": round(confidence, 4)}


def predict_batch_csv(model_path: str, file_bytes: bytes) -> list[dict]:
    """Read a CSV from bytes, predict each row, return list of result dicts."""
    model = _load_model(model_path)
    content = file_bytes.decode("utf-8", errors="replace")
    reader = csv.reader(io.StringIO(content))
    rows = list(reader)
    if not rows:
        return []

    header = rows[0]
    # Detect message column by name heuristic
    msg_col_idx = 0
    for i, h in enumerate(header):
        if any(kw in h.lower() for kw in ("message", "msg", "email", "text", "content")):
            msg_col_idx = i
            break
    else:
        # If no header match, pick the column with the longest average value
        data_rows = rows[1:] if len(rows) > 1 else rows
        if data_rows:
            avg_lens = [
                sum(len(r[i]) for r in data_rows if i < len(r)) / max(len(data_rows), 1)
                for i in range(len(header))
            ]
            msg_col_idx = avg_lens.index(max(avg_lens))

    classes: list = model.named_steps["clf"].classes_.tolist()
    results = []
    for row in rows[1:]:
        if not row or len(row) <= msg_col_idx:
            continue
        msg = row[msg_col_idx].strip()
        if not msg:
            continue
        pred: str = model.predict([msg])[0]
        proba = model.predict_proba([msg])[0]
        conf = float(proba[classes.index(pred)])
        results.append(
            {"message": msg, "prediction": pred, "confidence": round(conf, 4)}
        )
    return results
