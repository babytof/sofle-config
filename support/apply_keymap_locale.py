#!/usr/bin/env python3
# SPDX-License-Identifier: MIT
"""Fusionne un CSV locale dans parse_config (zmk_keycode_map + raw_binding_map)."""

from __future__ import annotations

import argparse
import csv
import sys
from pathlib import Path
from typing import Any

import yaml


def value_uses_mdi(val: Any) -> bool:
    """True si la config d’origine affiche un pictogramme Material (à ne pas écraser avec du texte CSV)."""
    if isinstance(val, str):
        return "$$mdi" in val
    if isinstance(val, dict):
        return any(isinstance(v, str) and "$$mdi" in v for v in val.values())
    return False


def raw_binding_tap_uses_mdi(val: Any) -> bool:
    if isinstance(val, dict):
        t = val.get("t")
        return isinstance(t, str) and "$$mdi" in t
    return False


def row_to_map_value(tap: str, shift: str) -> Any:
    shift = shift.strip() if shift else ""
    if not shift:
        return tap
    if shift == tap:
        return tap
    return {"t": tap, "s": shift}


def morph_num_reverse_legend(tap: str, shift: str) -> Any:
    """Légende kp_rNx : chiffre au centre, symbole en haut si le CSV est type AZERTY (shift = chiffre)."""
    st = shift.strip() if shift else ""
    if len(st) == 1 and st.isdecimal():
        return row_to_map_value(shift, tap)
    return row_to_map_value(tap, shift)


def use_shift_only_legend(tap: str, shift: str) -> bool:
    """Lettres tap/shift (ex. e,E) → une seule légende majuscule, comme Keymap Drawer d’origine."""
    if not tap or not shift:
        return False
    if len(tap) != 1 or len(shift) != 1:
        return False
    return tap.isalpha() and shift.isalpha()


def zmk_entry_for_locale(tap: str, shift: str) -> Any:
    if use_shift_only_legend(tap, shift):
        return shift
    return row_to_map_value(tap, shift)


def patch_raw_binding_value(val: Any, tap: str, shift: str) -> None:
    """Met à jour t (et s) sans retirer h, type, etc."""
    if not isinstance(val, dict):
        return
    if use_shift_only_legend(tap, shift):
        val["t"] = shift
        val.pop("s", None)
        return
    new_v = row_to_map_value(tap, shift)
    if isinstance(new_v, dict):
        val["t"] = new_v["t"]
        if "s" in new_v:
            val["s"] = new_v["s"]
        else:
            val.pop("s", None)
    else:
        val["t"] = new_v
        val.pop("s", None)


def binding_tail_token(binding: str) -> str | None:
    """Dernier mot du libellé de binding (ex. '&hml LHRM4 A' → 'A')."""
    parts = binding.strip().split()
    if not parts:
        return None
    return parts[-1]


# __NUM_REVERSE (specialkeys.dtsi) : mod-morph tap = symbole HID, shift = Nx.
# Keymap Drawer ne prend pour la branche shift que shifted_key.tap (zmk.py), pas s ;
# sans entrée raw, l’affichage est faux. Le raw fixe t (centre) / s (haut) : chiffre au centre,
# symbole en haut — on passe row_to_map_value(shift_csv, tap_csv).
_R_MORPH_BEHAVIORS: tuple[tuple[str, str], ...] = (
    ("N1", "kp_rN1"),
    ("N2", "kp_rN2"),
    ("N3", "kp_rN3"),
    ("N4", "kp_rN4"),
    ("N5", "kp_rN5"),
    ("N6", "kp_rN6"),
    ("N7", "kp_rN7"),
    ("N8", "kp_rN8"),
    ("N9", "kp_rN9"),
    ("N0", "kp_rN0"),
)


def main() -> None:
    p = argparse.ArgumentParser(description=__doc__)
    p.add_argument("base_yaml", type=Path, help="keymap-config.yaml (ou dérivé)")
    p.add_argument("locale_csv", type=Path, help="CSV UTF-8 avec en-tête zmk_key,tap,shift")
    p.add_argument("-o", "--output", type=Path, required=True)
    args = p.parse_args()

    if not args.base_yaml.is_file():
        print(f"Fichier introuvable : {args.base_yaml}", file=sys.stderr)
        sys.exit(1)
    if not args.locale_csv.is_file():
        print(f"Fichier introuvable : {args.locale_csv}", file=sys.stderr)
        sys.exit(1)

    with args.base_yaml.open(encoding="utf-8") as f:
        data = yaml.load(f, Loader=yaml.FullLoader)
    if not isinstance(data, dict):
        print(f"YAML invalide (racine attendue : mapping) : {args.base_yaml}", file=sys.stderr)
        sys.exit(1)

    parse_cfg = data.setdefault("parse_config", {})
    zmk_map = parse_cfg.setdefault("zmk_keycode_map", {})
    if not isinstance(zmk_map, dict):
        print("parse_config.zmk_keycode_map doit être un mapping YAML", file=sys.stderr)
        sys.exit(1)

    locale_rows: dict[str, tuple[str, str]] = {}
    with args.locale_csv.open(newline="", encoding="utf-8") as f:
        reader = csv.reader(f)
        header = next(reader, None)
        if not header or [c.strip() for c in header[:3]] != ["zmk_key", "tap", "shift"]:
            print(
                "En-tête CSV attendu : zmk_key,tap,shift",
                file=sys.stderr,
            )
            sys.exit(1)
        for row in reader:
            if len(row) < 2:
                continue
            key = row[0].strip()
            if not key:
                continue
            tap = row[1]
            shift = row[2] if len(row) > 2 else ""
            locale_rows[key] = (tap, shift)

    for key, (tap, shift) in locale_rows.items():
        previous = zmk_map.get(key)
        if value_uses_mdi(previous):
            continue
        zmk_map[key] = zmk_entry_for_locale(tap, shift)

    raw_map = parse_cfg.get("raw_binding_map")
    if not isinstance(raw_map, dict):
        raw_map = {}
        parse_cfg["raw_binding_map"] = raw_map
    for binding, val in raw_map.items():
        token = binding_tail_token(binding)
        if not token or token not in locale_rows:
            continue
        if raw_binding_tap_uses_mdi(val):
            continue
        tap, shift = locale_rows[token]
        patch_raw_binding_value(val, tap, shift)

    for zmk_key, behavior in _R_MORPH_BEHAVIORS:
        if zmk_key not in locale_rows:
            continue
        tap, shift = locale_rows[zmk_key]
        raw_map[f"&{behavior}"] = morph_num_reverse_legend(tap, shift)

    args.output.parent.mkdir(parents=True, exist_ok=True)
    with args.output.open("w", encoding="utf-8") as f:
        yaml.dump(
            data,
            f,
            allow_unicode=True,
            default_flow_style=False,
            sort_keys=False,
            width=120,
        )


if __name__ == "__main__":
    main()
