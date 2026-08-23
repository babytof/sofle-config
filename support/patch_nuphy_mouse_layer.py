#!/usr/bin/env python3
# SPDX-License-Identifier: MIT
"""
Draw uniquement : couche 4 Mouse (Nuphy Corne) + toggle K56 sur Base.

Le firmware Sofle (corne_vial_layout.dtsi) garde Spare ; les images Corne 42
montrent la couche Mouse du Nuphy. Ordre = indices ZMK 0–59 (SOFLE60).

Légendes déjà résolues (dicts) : keymap-drawer n’applique pas raw_binding_map
aux chaînes injectées après le parse.
"""

from __future__ import annotations

import argparse
import sys
from pathlib import Path
from typing import Any, Dict, List, Union

import yaml

Cell = Union[str, Dict[str, Any]]

BASE_K56 = 52
N: Cell = {"type": "noswitch"}

LOCK = {"t": "$$mdi:lock-outline$$", "type": "ghost"}
ALT_MOU = {
    "t": "$$mdi:lock-outline$$",
    "h": "$$mdi:apple-keyboard-option$$",
    "type": "held",
}
SPD = lambda label: {"t": label, "type": "held"}
MMV = lambda arrow: {"t": "$$mdi:mouse$$", "h": arrow}
STEP = lambda arrow: {"t": "$$mdi:mouse$$", "h": f"1{arrow}"}
SCRL = lambda kind, label: {"t": f"$$mdi:unfold-more-{kind}$$", "h": label}
LCLK = {"t": "$$mdi:mouse-left-click-outline$$", "h": "primary"}
RCLK = {"t": "$$mdi:mouse-right-click-outline$$", "h": "right"}
MCLK = {"t": "$$mdi:mouse-right-click-outline$$", "h": "middle"}
MB4 = {"t": "$$mdi:chevron-left$$", "h": "MB4"}
MB5 = {"t": "$$mdi:chevron-right$$", "h": "MB5"}
ADJ = {"t": "$$mdi:numeric-5-box-multiple-outline$$"}
UNDO = {"t": "$$mdi:undo$$"}
REDO = {"t": "$$mdi:redo$$"}
CUT = {"t": "$$mdi:content-cut$$"}
COPY = {"t": "$$mdi:content-copy$$"}
PASTE = {"t": "$$mdi:content-paste$$"}
# Touche présente, inactive (firmware &none) : couleur normale, vide.
NONE_KEY: Cell = {"t": ""}

MOUSE_BINDINGS: List[Cell] = [
    *([N] * 12),
    LOCK,
    SPD("×½"),
    SPD("×2"),
    SPD("×4"),
    SPD("×6"),
    MB4,
    STEP("←"),
    STEP("↓"),
    STEP("↑"),
    STEP("→"),
    REDO,
    NONE_KEY,
    NONE_KEY,
    NONE_KEY,
    RCLK,
    MCLK,
    LCLK,
    MB5,
    MMV("←"),
    MMV("↓"),
    MMV("↑"),
    MMV("→"),
    LOCK,
    ADJ,
    NONE_KEY,
    UNDO,
    CUT,
    COPY,
    MCLK,
    PASTE,
    N,
    N,
    SCRL("vertical", "left"),
    SCRL("horizontal", "down"),
    SCRL("horizontal", "up"),
    SCRL("vertical", "right"),
    NONE_KEY,
    NONE_KEY,
    N,
    N,
    ALT_MOU,
    NONE_KEY,
    NONE_KEY,
    LCLK,
    RCLK,
    NONE_KEY,
    N,
    N,
]


def patch(data: Dict[str, Any]) -> None:
    layers = data.get("layers")
    if not isinstance(layers, dict):
        print("YAML invalide : clé « layers » attendue", file=sys.stderr)
        raise SystemExit(1)
    if "Base" not in layers and "Nav" not in layers:
        return

    base = layers.get("Base")
    if isinstance(base, list) and BASE_K56 < len(base):
        base[BASE_K56] = dict(ALT_MOU)

    if len(MOUSE_BINDINGS) != 60:
        print(
            f"MOUSE_BINDINGS doit faire 60 cellules (got {len(MOUSE_BINDINGS)})",
            file=sys.stderr,
        )
        raise SystemExit(1)

    if "Spare" in layers:
        del layers["Spare"]
    layers["Mouse"] = [dict(c) if isinstance(c, dict) else c for c in MOUSE_BINDINGS]


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("input", nargs="?", type=Path)
    parser.add_argument("-o", "--output", type=Path)
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
