#!/usr/bin/env python3
# SPDX-License-Identifier: MIT
"""
Injecte une couche Keymap Drawer « RC_REFERENCE » (60 touches) dans le YAML parsé.

Rangée principale : coordonnées RC row,col (sans parenthèses à l’affichage) comme le transform Sofle.
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
# Légende Keymap Drawer : « row,col » sans parenthèses (lisibilité, pas de césure sur 2 lignes).
RC_COORDS: List[str] = (
    [f"0,{c}" for c in range(12)]
    + [f"1,{c}" for c in range(12)]
    + [f"2,{c}" for c in range(12)]
    + [f"3,{c}" for c in range(6)]
    + ["4,5", "4,6"]
    + [f"3,{c}" for c in range(6, 12)]
    + [f"4,{c}" for c in range(5)]
    + [f"4,{c}" for c in range(7, 12)]
)

# Paramètres SOFLE60 (entrée macro) pour chaque keypos — aligné sur la sortie ZMK dans sofle.keymap.
KEYPOS_TO_K: List[str] = [
    "K00", "K01", "K02", "K03", "K04", "K05", "K06", "K07", "K08", "K09", "K10", "K11",
    "K12", "K13", "K14", "K15", "K16", "K17", "K20", "K21", "K22", "K23", "K24", "K25",
    "K26", "K27", "K28", "K29", "K30", "K31", "K34", "K35", "K36", "K37", "K38", "K39",
    "K40", "K41", "K42", "K43", "K44", "K45", "K18", "K19", "K48", "K49", "K50", "K51",
    "K52", "K53", "K54", "K55", "K56", "K57", "K58", "K59", "K61", "K62", "K64", "K65",
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

    n = len(RC_COORDS)
    if len(KEYPOS_TO_K) != n:
        print(
            f"Erreur interne : KEYPOS_TO_K ({len(KEYPOS_TO_K)}) ≠ RC_COORDS ({n}).",
            file=sys.stderr,
        )
        raise SystemExit(1)

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

    layers[LAYER_NAME] = [
        {"t": rc, "h": k} for rc, k in zip(RC_COORDS, KEYPOS_TO_K)
    ]

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
