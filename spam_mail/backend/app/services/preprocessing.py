"""Data loading, column detection, cleaning, and EDA chart generation."""
import base64
import io

import matplotlib
matplotlib.use("Agg")
import matplotlib.pyplot as plt
import pandas as pd


def load_csv(file_path: str) -> pd.DataFrame:
    """Try common encodings and separators to load a CSV/TSV file."""
    for encoding in ("utf-8", "latin-1", "cp1252"):
        for sep in (",", "\t"):
            try:
                df = pd.read_csv(file_path, encoding=encoding, sep=sep)
                if len(df.columns) >= 2 and len(df) > 0:
                    return df
            except Exception:
                continue
    raise ValueError("无法解析文件，请确保是有效的 CSV/TSV 格式")


def detect_columns(df: pd.DataFrame) -> tuple[str, str]:
    """Return (label_col, message_col) by content heuristics."""
    label_col: str | None = None
    msg_col: str | None = None

    for col in df.columns:
        if df[col].dtype == object:
            vals = set(df[col].dropna().astype(str).str.lower().unique())
            if {"ham", "spam"}.issubset(vals) or vals == {"ham", "spam"}:
                label_col = col
                break

    for col in df.columns:
        if col == label_col:
            continue
        if df[col].dtype == object:
            avg_len = df[col].dropna().astype(str).str.len().mean()
            if avg_len > 10:
                msg_col = col
                break

    if label_col is None or msg_col is None:
        label_col = df.columns[0]
        msg_col = df.columns[1]

    return label_col, msg_col


def preprocess_df(df: pd.DataFrame) -> pd.DataFrame:
    """Standardise columns to ['label', 'message'] and clean data."""
    label_col, msg_col = detect_columns(df)
    result = df[[label_col, msg_col]].copy()
    result.columns = ["label", "message"]
    result = result.dropna()
    result["label"] = result["label"].astype(str).str.lower().str.strip()
    result["message"] = result["message"].astype(str).str.strip()
    result = result[result["label"].isin(["ham", "spam"])]
    result = result.drop_duplicates(subset=["message"])
    return result.reset_index(drop=True)


def _fig_to_b64(fig) -> str:
    buf = io.BytesIO()
    fig.savefig(buf, format="png", dpi=100, bbox_inches="tight")
    plt.close(fig)
    buf.seek(0)
    return base64.b64encode(buf.read()).decode()


def get_eda(df: pd.DataFrame) -> dict:
    """Generate EDA stats and charts (base64 PNG) for the dataset."""
    df = df.copy()
    label_counts = df["label"].value_counts().to_dict()
    df["msg_len"] = df["message"].str.len()

    # --- Label distribution bar chart ---
    fig, ax = plt.subplots(figsize=(5, 3.5))
    labels = list(label_counts.keys())
    values = [label_counts[l] for l in labels]
    color_map = {"ham": "#67c23a", "spam": "#f56c6c"}
    bars = ax.bar(
        labels, values,
        color=[color_map.get(l, "#409eff") for l in labels],
        width=0.5,
    )
    for bar, v in zip(bars, values):
        ax.text(
            bar.get_x() + bar.get_width() / 2,
            bar.get_height() + max(values) * 0.02,
            str(v),
            ha="center", va="bottom", fontsize=11, fontweight="bold",
        )
    ax.set_title("Label Distribution", fontsize=13)
    ax.set_xlabel("Class")
    ax.set_ylabel("Count")
    ax.set_ylim(0, max(values) * 1.18)
    ax.spines[["top", "right"]].set_visible(False)
    plt.tight_layout()
    label_dist_chart = _fig_to_b64(fig)

    # --- Text length distribution histogram ---
    fig, ax = plt.subplots(figsize=(7, 3.8))
    for label, color in [("ham", "#67c23a"), ("spam", "#f56c6c")]:
        subset = df[df["label"] == label]["msg_len"]
        ax.hist(subset, bins=50, alpha=0.75, label=label, color=color, edgecolor="none")
    ax.set_title("Text Length Distribution", fontsize=13)
    ax.set_xlabel("Length (characters)")
    ax.set_ylabel("Frequency")
    ax.legend()
    ax.spines[["top", "right"]].set_visible(False)
    plt.tight_layout()
    len_dist_chart = _fig_to_b64(fig)

    return {
        "total": int(len(df)),
        "spam_count": int(label_counts.get("spam", 0)),
        "ham_count": int(label_counts.get("ham", 0)),
        "avg_msg_len": round(float(df["msg_len"].mean()), 1),
        "label_dist_chart": label_dist_chart,
        "len_dist_chart": len_dist_chart,
        "preview": df.head(20).to_dict(orient="records"),
    }
