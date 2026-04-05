#!/usr/bin/env python3
# SPDX-License-Identifier: MIT
"""
Ajoute le numéro de couche à côté du nom dans les en-têtes Keymap Drawer
(<text class="label" …>NOM:</text> → NOM (i):).
"""

from __future__ import annotations

import argparse
import re
import sys
from pathlib import Path

# Ordre logique des couches (aligné sur gen-keymap-images.sh / LAYOUT_LAYERS)
LAYER_NUM: dict[str, int] = {
    name: i
    for i, name in enumerate(
        (
            "QWERTY",
            "Navigation",
            "Numbers",
            "Symbols",
            "Media",
            "Mouse",
            "Functions",
            "Buttons",
            "System",
            "COLEMAK",
            "RC_REFERENCE",
        )
    )
}

# En-têtes hors keymap (laissés tels quels si d’autres apparaissent)
_SKIP = frozenset({"Combos"})


def annotate(svg: str) -> str:
    pat = re.compile(r'<text([^>]*\bclass="label"[^>]*)>([^<]+)</text>')

    def repl(m: re.Match[str]) -> str:
        attrs, body = m.group(1), m.group(2).strip()
        id_m = re.search(r'\bid="([^"]+)"', attrs)
        if not id_m:
            return m.group(0)
        name = id_m.group(1)
        if name in _SKIP or name not in LAYER_NUM:
            return m.group(0)
        if body != f"{name}:":
            return m.group(0)
        i = LAYER_NUM[name]
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
