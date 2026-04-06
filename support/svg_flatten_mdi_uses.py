#!/usr/bin/env python3
# SPDX-License-Identifier: MIT
"""
Aplatit les <use href="#mdi:…"> vers des <g><path/></g> avec transform,
pour que rsvg-convert (librsvg) rende les glyphes MDI (nested <svg> dans <defs>).

Usage : python3 svg_flatten_mdi_uses.py entree.svg sortie.svg
"""
from __future__ import annotations

import sys
import xml.etree.ElementTree as ET

SVG_NS = "http://www.w3.org/2000/svg"
XLINK_NS = "http://www.w3.org/1999/xlink"


def _tag(local: str) -> str:
    return f"{{{SVG_NS}}}{local}"


def _local(tag: str) -> str:
    if tag.startswith("{"):
        return tag[tag.index('}') + 1 :]
    return tag


def _href(use: ET.Element) -> str | None:
    h = use.get("href")
    if h:
        return h
    return use.get(f"{{{XLINK_NS}}}href")


def _extract_paths_from_mdi_def(def_el: ET.Element) -> list[str]:
    """Récupère les attributs d= des path sous une définition mdi (svg wrappé)."""
    ds: list[str] = []
    for el in def_el.iter():
        if _local(el.tag) == "path" and el.get("d"):
            ds.append(el.get("d", ""))
    return ds


def _use_to_transform(use: ET.Element) -> str:
    x = float(use.get("x", "0"))
    y = float(use.get("y", "0"))
    w_s = use.get("width")
    h_s = use.get("height")
    if w_s and h_s:
        w, h = float(w_s), float(h_s)
        sx, sy = w / 24.0, h / 24.0
    elif w_s:
        s = float(w_s) / 24.0
        sx = sy = s
    elif h_s:
        s = float(h_s) / 24.0
        sx = sy = s
    else:
        sx = sy = 1.0
    return f"translate({x},{y}) scale({sx},{sy})"


def flatten(svg_path: str, out_path: str) -> None:
    ET.register_namespace("", SVG_NS)
    ET.register_namespace("xlink", XLINK_NS)

    tree = ET.parse(svg_path)
    root = tree.getroot()

    defs = None
    for child in root:
        if _local(child.tag) == "defs":
            defs = child
            break
    if defs is None:
        tree.write(out_path, encoding="utf-8", xml_declaration=True)
        return

    mdi_paths: dict[str, list[str]] = {}
    to_remove: list[ET.Element] = []
    for child in list(defs):
        if _local(child.tag) != "svg":
            continue
        cid = child.get("id")
        if not cid or not cid.startswith("mdi:"):
            continue
        paths = _extract_paths_from_mdi_def(child)
        if paths:
            mdi_paths[cid] = paths
            to_remove.append(child)

    uses: list[tuple[ET.Element, ET.Element]] = []

    def walk(parent: ET.Element) -> None:
        for child in list(parent):
            if _local(child.tag) == "use":
                href = _href(child)
                if href and href.startswith("#"):
                    rid = href[1:]
                    if rid in mdi_paths:
                        uses.append((parent, child))
            walk(child)

    walk(root)

    for parent, use_el in uses:
        href = _href(use_el)
        assert href
        rid = href[1:]
        idx = list(parent).index(use_el)
        parent.remove(use_el)
        g = ET.Element(_tag("g"))
        if use_el.get("class"):
            g.set("class", use_el.get("class", ""))
        g.set("transform", _use_to_transform(use_el))
        for d in mdi_paths[rid]:
            p = ET.SubElement(g, _tag("path"))
            p.set("d", d)
            p.set("fill", "inherit")
        parent.insert(idx, g)

    for el in to_remove:
        defs.remove(el)

    tree.write(out_path, encoding="utf-8", xml_declaration=True)


def main() -> None:
    if len(sys.argv) != 3:
        print("Usage: svg_flatten_mdi_uses.py input.svg output.svg", file=sys.stderr)
        sys.exit(2)
    flatten(sys.argv[1], sys.argv[2])


if __name__ == "__main__":
    main()
