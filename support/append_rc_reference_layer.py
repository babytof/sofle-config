#!/usr/bin/env python3
# SPDX-License-Identifier: MIT
"""
Injecte une couche Keymap Drawer « RC_REFERENCE » (60 touches) dans le YAML parsé.

Rangée principale : coordonnées RC (row,col) comme le transform Sofle.
Rangée pouces (10 touches, indices ZMK 50–59) : uniquement RC(4,*) — pas de noms Lily.
  Ordre : (4,0)…(4,4), puis (4,7)…(4,11). Les colonnes (4,5)(4,6) sont sur la rangée alpha.
"""

from __future__ import annotations

import argparse
import sys
from pathlib import Path
from typing import Any, Dict, List

import yaml

# Ordre SOFLE60 / indices ZMK 0–59 : pouces = RC(4,0)…(4,4), (4,7)…(4,11).
RC_LABELS: List[str] = [
    "(0,0)", "(0,1)", "(0,2)", "(0,3)", "(0,4)", "(0,5)",
    "(0,6)", "(0,7)", "(0,8)", "(0,9)", "(0,10)", "(0,11)",
    "(1,0)", "(1,1)", "(1,2)", "(1,3)", "(1,4)", "(1,5)",
    "(1,6)", "(1,7)", "(1,8)", "(1,9)", "(1,10)", "(1,11)",
    "(2,0)", "(2,1)", "(2,2)", "(2,3)", "(2,4)", "(2,5)",
    "(2,6)", "(2,7)", "(2,8)", "(2,9)", "(2,10)", "(2,11)",
    "(3,0)", "(3,1)", "(3,2)", "(3,3)", "(3,4)", "(3,5)",
    "(4,5)", "(4,6)",
    "(3,6)", "(3,7)", "(3,8)", "(3,9)", "(3,10)", "(3,11)",
    "(4,0)",
    "(4,1)",
    "(4,2)",
    "(4,3)",
    "(4,4)",
    "(4,7)",
    "(4,8)",
    "(4,9)",
    "(4,10)",
    "(4,11)",
]

LAYER_NAME = "RC_REFERENCE"


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument(
        "input",
        nargs="?",
        type=Path,
        help="YAML Keymap Drawer (stdin si omis)",
    )
    parser.add_argument(
        "-o",
        "--output",
        type=Path,
        help="Fichier de sortie (stdout si omis)",
    )
    args = parser.parse_args()

    if args.input:
        raw = args.input.read_text(encoding="utf-8")
    else:
        raw = sys.stdin.read()

    data: Dict[str, Any] = yaml.load(raw, Loader=yaml.FullLoader)
    if not data or "layers" not in data:
        print("YAML invalide : clé « layers » attendue", file=sys.stderr)
        raise SystemExit(1)

    layers = data["layers"]
    if not isinstance(layers, dict):
        print("« layers » doit être un mapping", file=sys.stderr)
        raise SystemExit(1)

    n = len(RC_LABELS)
    for name, keys in layers.items():
        if name == LAYER_NAME:
            continue
        if isinstance(keys, list) and len(keys) != n:
            print(
                f"Avertissement : la couche « {name} » a {len(keys)} touches, "
                f"attendu {n} pour RC_REFERENCE — vérifie le keymap.",
                file=sys.stderr,
            )
            break

    layers[LAYER_NAME] = list(RC_LABELS)

    out = yaml.dump(
        data,
        default_flow_style=False,
        allow_unicode=True,
        sort_keys=False,
        width=120,
    )

    if args.output:
        args.output.write_text(out, encoding="utf-8")
    else:
        sys.stdout.write(out)


if __name__ == "__main__":
    main()
