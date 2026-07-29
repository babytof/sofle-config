#!/usr/bin/env python3
# SPDX-License-Identifier: MIT
"""
Marque les positions Sofle sans switch (Corne 42) avec type « noswitch »
pour un style CSS distinct dans les SVG Keymap Drawer.
"""

from __future__ import annotations

import argparse
import sys
from pathlib import Path
from typing import Any, Dict, List

import yaml

# Indices matrice Sofle 60 sans switch peuplé (plan Corne 42 BT)
NOSWITCH_KEYPOS: List[int] = [
    *range(0, 12),  # rangée chiffres
    42,
    43,  # HYP
    50,
    51,
    58,
    59,  # pouces externes
]

# Légendes d’affichage uniquement (firmware inchangé).
# Nav K12 = NUBS en ZMK ; sur macOS FR la touche physique / usage attendu
# est le même rendu que GRAVE en Base (@ / #), cf. Corne keymap.html L0.
DISPLAY_OVERRIDES: Dict[tuple[str, int], Dict[str, str]] = {
    ("Nav", 12): {"t": "@", "s": "#", "type": "fr"},
}


def patch(data: Dict[str, Any]) -> None:
    layers = data.get("layers")
    if not isinstance(layers, dict):
        print("YAML invalide : clé « layers » attendue", file=sys.stderr)
        raise SystemExit(1)

    for layer_name, bindings in layers.items():
        if not isinstance(bindings, list):
            continue
        for pos in NOSWITCH_KEYPOS:
            if pos >= len(bindings):
                print(
                    f"Couche « {layer_name} » trop courte "
                    f"({len(bindings)} touches, index {pos} attendu).",
                    file=sys.stderr,
                )
                raise SystemExit(1)
            cell = bindings[pos]
            if cell is None or cell == "":
                bindings[pos] = {"type": "noswitch"}
            elif isinstance(cell, dict):
                cell = dict(cell)
                cell["type"] = "noswitch"
                bindings[pos] = cell
            else:
                # Légende texte inattendue sur une case sans switch — forcer le type
                bindings[pos] = {"t": str(cell), "type": "noswitch"}

    for (layer_name, pos), legend in DISPLAY_OVERRIDES.items():
        bindings = layers.get(layer_name)
        if not isinstance(bindings, list):
            print(f"Couche « {layer_name} » absente — override ignoré", file=sys.stderr)
            continue
        if pos >= len(bindings):
            print(
                f"Couche « {layer_name} » trop courte pour override index {pos}.",
                file=sys.stderr,
            )
            raise SystemExit(1)
        bindings[pos] = dict(legend)

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

    raw = args.input.read_text(encoding="utf-8") if args.input else sys.stdin.read()
    data: Dict[str, Any] = yaml.load(raw, Loader=yaml.FullLoader)
    patch(data)
    out = yaml.dump(data, allow_unicode=True, sort_keys=False, width=120)
    if args.output:
        args.output.write_text(out, encoding="utf-8")
    else:
        sys.stdout.write(out)


if __name__ == "__main__":
    main()
