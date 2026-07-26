#!/usr/bin/env python3
# SPDX-License-Identifier: MIT
"""
Injecte des couches Keymap Drawer vierges (BLANK_1 …) pour gabarit imprimable.

Chaque couche comporte 60 touches vides (même ordre SOFLE60 que RC_REFERENCE).
"""

from __future__ import annotations

import argparse
import sys
from pathlib import Path
from typing import Any, Dict, List

import yaml

# Ordre SOFLE60 — aligné sur append_rc_reference_layer.py
KEY_COUNT = 60
DEFAULT_LAYER_COUNT = 3


def layer_names(count: int) -> tuple[str, ...]:
    return tuple(f"BLANK_{i}" for i in range(1, count + 1))


def blank_layer() -> List[str]:
    return [""] * KEY_COUNT


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument(
        "input",
        nargs="?",
        type=Path,
        help="YAML Keymap Drawer (stdin si omis). Sans entrée : YAML minimal.",
    )
    parser.add_argument(
        "-o",
        "--output",
        type=Path,
        help="Fichier de sortie (stdout si omis)",
    )
    parser.add_argument(
        "--standalone",
        action="store_true",
        help="Génère un YAML minimal (couches vierges seulement), sans fichier d'entrée.",
    )
    parser.add_argument(
        "--count",
        type=int,
        default=DEFAULT_LAYER_COUNT,
        metavar="N",
        help=f"Nombre de couches vierges (défaut : {DEFAULT_LAYER_COUNT}).",
    )
    args = parser.parse_args()

    if args.count < 1:
        print("« --count » doit être ≥ 1", file=sys.stderr)
        raise SystemExit(1)

    names = layer_names(args.count)

    if args.standalone or args.input is None:
        data: Dict[str, Any] = {"layers": {name: blank_layer() for name in names}}
    else:
        raw = args.input.read_text(encoding="utf-8")
        data = yaml.load(raw, Loader=yaml.FullLoader)
        if not data or "layers" not in data:
            print("YAML invalide : clé « layers » attendue", file=sys.stderr)
            raise SystemExit(1)
        layers = data["layers"]
        if not isinstance(layers, dict):
            print("« layers » doit être un mapping", file=sys.stderr)
            raise SystemExit(1)
        for name in names:
            layers[name] = blank_layer()

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
