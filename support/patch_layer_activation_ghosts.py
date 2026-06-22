#!/usr/bin/env python3
# SPDX-License-Identifier: MIT
"""
Draw uniquement : légendes ghost (icône couche + numéro) sur les touches d’activation.

En firmware ces positions peuvent rester &none (ou autre binding) sur la couche
overlay ; le toggle est sur une autre touche quand il existe. Indique d’où l’on
entre depuis AZERTY (hold / tap-dance).
"""

from __future__ import annotations

import argparse
import sys
from pathlib import Path
from typing import Any, Dict, List, Tuple, Union

import yaml

# (nom couche Keymap Drawer, keypos SOFLE60, numéro couche)
# keypos ↔ KEYPOS_TO_K dans append_rc_reference_layer.py
ACTIVATION_GHOSTS: List[Tuple[str, int, int]] = [
    ("Navigation", 53, 1),   # K57  hold Esc → Nav
    ("Numbers", 56, 2),      # K61  hold → Num
    ("Symbols", 54, 3),      # K58  hold Ret → Sym
    ("Media", 55, 4),        # K59  hold Space → Med
    ("Mouse", 41, 5),        # K45  hold B → Mou
    ("Functions", 49, 6),    # K51  hold = / + → Fun
    ("Buttons", 52, 7),      # K56  motg_but
    ("Buttons", 57, 7),      # K62  motg_but
    ("System", 51, 8),       # K55  mo L_SYS
    ("System", 58, 8),       # K64  mo L_SYS
]

# Couche System : pas de toggle ; masquer studio_unlock (cadenas ouvert) au draw.
SYSTEM_DRAW_BLANK_KEYPOS: Tuple[int, ...] = (50, 59)  # K54, K65


def layer_ref_legend(layer_num: int) -> Dict[str, Any]:
    return {
        "t": f"$$mdi:numeric-{layer_num}-box-multiple-outline$$",
        "h": str(layer_num),
        "type": "ghost",
    }


def _set_binding(
    bindings: List[Any], keypos: int, value: Union[Dict[str, Any], str], layer_name: str
) -> None:
    if len(bindings) <= keypos:
        print(
            f"Couche « {layer_name} » trop courte ({len(bindings)} touches, "
            f"index {keypos} attendu).",
            file=sys.stderr,
        )
        raise SystemExit(1)
    bindings[keypos] = value


def patch(data: Dict[str, Any]) -> None:
    layers = data.get("layers")
    if not isinstance(layers, dict):
        print("YAML invalide : clé « layers » attendue", file=sys.stderr)
        raise SystemExit(1)

    for layer_name, keypos, layer_num in ACTIVATION_GHOSTS:
        bindings = layers.get(layer_name)
        if not isinstance(bindings, list):
            print(f"Couche « {layer_name} » absente ou invalide", file=sys.stderr)
            raise SystemExit(1)
        _set_binding(bindings, keypos, layer_ref_legend(layer_num), layer_name)

    system = layers.get("System")
    if isinstance(system, list):
        for keypos in SYSTEM_DRAW_BLANK_KEYPOS:
            _set_binding(system, keypos, "", "System")


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
