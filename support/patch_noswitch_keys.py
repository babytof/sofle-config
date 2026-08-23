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
# macOS FR ISO : NUBS → @/# ; GRAVE → </> ; LS(GRAVE) → >
# Functions : sorties macOS FR des accords du Corne Vial (L3).
DISPLAY_OVERRIDES: Dict[tuple[str, int], Dict[str, str]] = {
    ("Nav", 48): {"t": ">", "type": "fr"},                 # K52 LS(GRAVE) = K38+Shift
    ("Symbols", 12): {"t": ">", "type": "fr"},             # K12 LS(GRAVE)
    ("Functions", 30): {"t": "-", "type": "fr"},   # K34 EQUAL
    ("Functions", 44): {"t": "_", "type": "fr"},   # K48 RS(EQUAL)
    ("Functions", 32): {"t": "}", "type": "fr"},   # K36 RA(MINUS)
    ("Functions", 33): {"t": "]", "type": "fr"},   # K37 LA(LS(MINUS))
    ("Functions", 29): {"t": "/", "type": "fr"},   # K31 LS(DOT)
    ("Symbols", 34): {"t": "`", "type": "fr"},     # K38 BSLH
    ("Symbols", 48): {"t": "£", "type": "fr"},     # K52 LS(BSLH)
    ("Symbols", 31): {"t": "-", "type": "fr"},     # K35 EQUAL
    ("Symbols", 32): {"t": "^", "type": "fr"},     # K36 LBKT
    ("Symbols", 44): {"t": "°", "type": "fr"},     # K48 LS(MINUS)
    ("Symbols", 45): {"t": "_", "type": "fr"},     # K49 LS(EQUAL)
    ("Symbols", 46): {"t": "¨", "type": "fr"},     # K50 LS(LBKT)
    ("Symbols", 47): {"t": "*", "type": "fr"},     # K51 LS(RBKT)
    ("Symbols", 13): {"t": "1", "type": "fr"},     # K13 LS(N1)
    ("Symbols", 14): {"t": "2", "type": "fr"},     # K14 LS(N2)
    ("Symbols", 15): {"t": "3", "type": "fr"},     # K15 LS(N3)
    ("Symbols", 16): {"t": "4", "type": "fr"},     # K16 LS(N4)
    ("Symbols", 17): {"t": "5", "type": "fr"},     # K17 LS(N5)
    ("Symbols", 18): {"t": "6", "type": "fr"},     # K20 LS(N6)
    ("Symbols", 19): {"t": "7", "type": "fr"},     # K21 LS(N7)
    ("Symbols", 20): {"t": "8", "type": "fr"},     # K22 LS(N8)
    ("Symbols", 21): {"t": "9", "type": "fr"},     # K23 LS(N9)
    ("Symbols", 22): {"t": "0", "type": "fr"},     # K24 LS(N0)
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
            # Réf. RC : garder les coordonnées. Ailleurs : case vide pointillée (pas de « &none »).
            if layer_name == "RC_REFERENCE":
                cell = bindings[pos]
                if isinstance(cell, dict):
                    cell = dict(cell)
                    cell["type"] = "noswitch"
                    bindings[pos] = cell
                else:
                    bindings[pos] = {"t": str(cell), "type": "noswitch"}
            else:
                bindings[pos] = {"type": "noswitch"}

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
