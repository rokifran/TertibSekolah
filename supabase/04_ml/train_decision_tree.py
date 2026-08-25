#!/usr/bin/env python3
"""Train Decision Tree untuk validasi tugas TertibSekolah.

Input CSV wajib memiliki kolom:
    nilai, kelengkapan, kesesuaian, target

target: selesai / revisi
kelengkapan & kesesuaian: 1/0, true/false, ya/tidak juga diterima.

Script menghasilkan artefak penelitian dan tree JSON yang dapat dipakai
Supabase Edge Function.
"""

from __future__ import annotations

import argparse
import json
from pathlib import Path
from typing import Any

import joblib
import matplotlib.pyplot as plt
import numpy as np
import pandas as pd
from sklearn.metrics import (
    accuracy_score,
    classification_report,
    confusion_matrix,
    f1_score,
    precision_score,
    recall_score,
)
from sklearn.model_selection import GridSearchCV, StratifiedKFold, train_test_split
from sklearn.tree import DecisionTreeClassifier, export_text, plot_tree

FEATURES = ["nilai", "kelengkapan", "kesesuaian"]
TARGET = "target"
ALLOWED_TARGETS = {"selesai", "revisi"}


def parse_bool(value: Any) -> int:
    if isinstance(value, (bool, np.bool_)):
        return int(value)
    if isinstance(value, (int, np.integer, float, np.floating)) and not pd.isna(value):
        if int(value) in (0, 1):
            return int(value)
    text = str(value).strip().lower()
    if text in {"1", "true", "ya", "yes", "lengkap", "sesuai"}:
        return 1
    if text in {"0", "false", "tidak", "no", "tidak lengkap", "tidak sesuai"}:
        return 0
    raise ValueError(f"Nilai boolean tidak valid: {value!r}")


def load_dataset(path: Path) -> pd.DataFrame:
    df = pd.read_csv(path)
    missing = [c for c in FEATURES + [TARGET] if c not in df.columns]
    if missing:
        raise ValueError(f"Kolom wajib tidak ditemukan: {missing}")

    df = df[FEATURES + [TARGET]].copy()
    df = df.dropna()
    df["nilai"] = pd.to_numeric(df["nilai"], errors="raise").astype(int)
    if ((df["nilai"] < 0) | (df["nilai"] > 100)).any():
        raise ValueError("Kolom nilai harus berada pada rentang 0-100.")

    df["kelengkapan"] = df["kelengkapan"].map(parse_bool)
    df["kesesuaian"] = df["kesesuaian"].map(parse_bool)
    df[TARGET] = df[TARGET].astype(str).str.strip().str.lower()

    invalid_targets = set(df[TARGET].unique()) - ALLOWED_TARGETS
    if invalid_targets:
        raise ValueError(f"Target tidak valid: {sorted(invalid_targets)}")

    counts = df[TARGET].value_counts()
    if len(counts) < 2:
        raise ValueError("Dataset harus memiliki dua kelas: selesai dan revisi.")
    if counts.min() < 5:
        raise ValueError(
            "Setiap kelas minimal memerlukan 5 record agar split stratified dan "
            "cross-validation dapat dijalankan. Untuk penelitian final, gunakan "
            "dataset yang lebih besar dan seimbang semampunya."
        )
    return df


def node_to_json(model: DecisionTreeClassifier, node_id: int = 0) -> dict[str, Any]:
    tree = model.tree_
    classes = [str(c) for c in model.classes_]

    if tree.children_left[node_id] == tree.children_right[node_id]:
        counts = tree.value[node_id][0].astype(float)
        total = float(counts.sum())
        class_idx = int(np.argmax(counts))
        confidence = float(counts[class_idx] / total) if total else 0.0
        return {
            "type": "leaf",
            "class": classes[class_idx],
            "confidence": round(confidence, 6),
            "samples": int(tree.n_node_samples[node_id]),
            "distribution": {
                classes[i]: int(round(counts[i])) for i in range(len(classes))
            },
        }

    feature_index = int(tree.feature[node_id])
    return {
        "type": "node",
        "feature": FEATURES[feature_index],
        "threshold": float(tree.threshold[node_id]),
        "samples": int(tree.n_node_samples[node_id]),
        "left": node_to_json(model, int(tree.children_left[node_id])),
        "right": node_to_json(model, int(tree.children_right[node_id])),
    }


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--input", required=True, type=Path, help="CSV dataset")
    parser.add_argument("--out", required=True, type=Path, help="Folder output")
    parser.add_argument("--version", default="dt-v1", help="Versi model")
    parser.add_argument("--random-state", type=int, default=42)
    parser.add_argument("--test-size", type=float, default=0.20)
    args = parser.parse_args()

    args.out.mkdir(parents=True, exist_ok=True)
    df = load_dataset(args.input)

    X = df[FEATURES]
    y = df[TARGET]

    X_train, X_test, y_train, y_test = train_test_split(
        X,
        y,
        test_size=args.test_size,
        random_state=args.random_state,
        stratify=y,
    )

    min_train_class = int(y_train.value_counts().min())
    cv_splits = max(2, min(5, min_train_class))
    cv = StratifiedKFold(
        n_splits=cv_splits,
        shuffle=True,
        random_state=args.random_state,
    )

    estimator = DecisionTreeClassifier(random_state=args.random_state)
    param_grid = {
        "criterion": ["gini", "entropy"],
        "max_depth": [2, 3, 4, 5, None],
        "min_samples_leaf": [1, 2, 5],
        "class_weight": [None, "balanced"],
    }

    search = GridSearchCV(
        estimator=estimator,
        param_grid=param_grid,
        scoring="f1_macro",
        cv=cv,
        n_jobs=-1,
        refit=True,
    )
    search.fit(X_train, y_train)
    model: DecisionTreeClassifier = search.best_estimator_

    y_pred = model.predict(X_test)
    labels = ["revisi", "selesai"]
    cm = confusion_matrix(y_test, y_pred, labels=labels)

    metrics = {
        "model_version": args.version,
        "features": FEATURES,
        "target": TARGET,
        "rows_total": int(len(df)),
        "rows_train": int(len(X_train)),
        "rows_test": int(len(X_test)),
        "class_distribution": {k: int(v) for k, v in y.value_counts().to_dict().items()},
        "test_size": args.test_size,
        "random_state": args.random_state,
        "cv_splits": cv_splits,
        "best_params": search.best_params_,
        "best_cv_f1_macro": float(search.best_score_),
        "holdout": {
            "accuracy": float(accuracy_score(y_test, y_pred)),
            "precision_macro": float(precision_score(y_test, y_pred, average="macro", zero_division=0)),
            "recall_macro": float(recall_score(y_test, y_pred, average="macro", zero_division=0)),
            "f1_macro": float(f1_score(y_test, y_pred, average="macro", zero_division=0)),
        },
        "confusion_matrix": {
            "labels": labels,
            "matrix": cm.tolist(),
        },
        "feature_importance": {
            FEATURES[i]: float(model.feature_importances_[i]) for i in range(len(FEATURES))
        },
    }

    # Artefak model untuk reproducibility.
    joblib.dump(model, args.out / "model.joblib")
    (args.out / "model_metrics.json").write_text(
        json.dumps(metrics, indent=2, ensure_ascii=False), encoding="utf-8"
    )

    model_json = {
        "version": args.version,
        "features": FEATURES,
        "classes": [str(c) for c in model.classes_],
        "criterion": model.criterion,
        "max_depth": int(model.get_depth()),
        "random_state": args.random_state,
        "root": node_to_json(model),
    }
    (args.out / "tree.json").write_text(
        json.dumps(model_json, indent=2, ensure_ascii=False), encoding="utf-8"
    )

    rules = export_text(model, feature_names=FEATURES)
    (args.out / "tree_rules.txt").write_text(rules, encoding="utf-8")

    report = classification_report(
        y_test,
        y_pred,
        labels=labels,
        output_dict=True,
        zero_division=0,
    )
    pd.DataFrame(report).transpose().to_csv(args.out / "classification_report.csv")
    pd.DataFrame(cm, index=[f"actual_{x}" for x in labels], columns=[f"pred_{x}" for x in labels]).to_csv(
        args.out / "confusion_matrix.csv"
    )
    pd.DataFrame(
        {"feature": FEATURES, "importance": model.feature_importances_}
    ).sort_values("importance", ascending=False).to_csv(args.out / "feature_importance.csv", index=False)

    test_out = X_test.copy()
    test_out["actual"] = y_test.values
    test_out["prediction"] = y_pred
    probs = model.predict_proba(X_test)
    test_out["prediction_confidence"] = probs.max(axis=1)
    test_out.to_csv(args.out / "test_predictions.csv", index=False)

    plt.figure(figsize=(14, 8))
    plot_tree(
        model,
        feature_names=FEATURES,
        class_names=[str(c) for c in model.classes_],
        filled=False,
        rounded=True,
        proportion=False,
        impurity=True,
    )
    plt.tight_layout()
    plt.savefig(args.out / "decision_tree.png", dpi=180, bbox_inches="tight")
    plt.close()

    print(json.dumps(metrics, indent=2, ensure_ascii=False))
    print(f"\nArtefak tersimpan di: {args.out}")


if __name__ == "__main__":
    main()
