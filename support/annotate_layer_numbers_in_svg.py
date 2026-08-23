#!/usr/bin/env python3
# SPDX-License-Identifier: MIT
"""
Ajoute le numéro de couche à côté du nom dans les en-têtes Keymap Drawer
(<text class="label" …>NOM:</text> → NOM (i):).

Layout : KEYMAP_LAYOUT_KIND=corne|townk (défaut : détection via ids SVG).
"""

from __future__ import annotations

import argparse
import os
import re
import sys
from pathlib import Path

# Townk / Sofle 60 (standard_layout.dtsi)
LAYER_NUM_TOWNK: dict[str, int] = {
    name: i
    for i, name in enumerate(
        (
            "AZERTY",
            "Navigation",
            "Numbers",
            "Symbols",
            "Media",
            "Mouse",
            "Functions",
            "Buttons",
            "System",
            "RC_REFERENCE",
        )
    )
}

# Corne Vial 42 (corne_vial_layout.dtsi) — index ZMK
LAYER_NUM_CORNE: dict[str, int] = {
    "Base": 0,
    "Nav": 1,
    "Symbols": 2,
    "Functions": 3,
    "Spare": 4,
    "Mouse": 4,
    "Adjust": 5,
    "RC_REFERENCE": 6,
}

# En-têtes hors keymap (laissés tels quels si d’autres apparaissent)
_SKIP = frozenset({"Combos"})

_CORNE_HINT = re.compile(r'\bid="(Base|Nav|Adjust|Spare)"')
_TOWNK_HINT = re.compile(r'\bid="(AZERTY|Navigation|Numbers|Media|Mouse|Buttons|System)"')


def resolve_layer_num(svg: str) -> dict[str, int]:
    kind = os.environ.get("KEYMAP_LAYOUT_KIND", "").strip().lower()
    if kind == "corne":
        return LAYER_NUM_CORNE
    if kind == "townk":
        return LAYER_NUM_TOWNK
    if _CORNE_HINT.search(svg):
        return LAYER_NUM_CORNE
    if _TOWNK_HINT.search(svg):
        return LAYER_NUM_TOWNK
    # SVG mono-couche Symbols/Functions : défaut Townk (historique)
    return LAYER_NUM_TOWNK


def annotate(svg: str) -> str:
    layer_num = resolve_layer_num(svg)
    pat = re.compile(r'<text([^>]*\bclass="label"[^>]*)>([^<]+)</text>')

    def repl(m: re.Match[str]) -> str:
        attrs, body = m.group(1), m.group(2).strip()
        id_m = re.search(r'\bid="([^"]+)"', attrs)
        if not id_m:
            return m.group(0)
        name = id_m.group(1)
        if name in _SKIP or name not in layer_num:
            return m.group(0)
        if body != f"{name}:":
            return m.group(0)
        i = layer_num[name]
        return f'<text{attrs}>{name} ({i}):</text>'

    return pat.sub(repl, svg)


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("svg", type=Path, nargs="+", help="Fichiers SVG à modifier")
    args = parser.parse_args()

    for path in args.svg:
        if not path.is_file():
            print(f"Fichier introuvable : {path}", file=sys.stderr)
            raise SystemExit(1)
        text = path.read_text(encoding="utf-8")
        path.write_text(annotate(text), encoding="utf-8")


if __name__ == "__main__":
    main()
