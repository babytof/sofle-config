#!python
# SPDX-License-Identifier: MIT
# D’après Townk zmk-config/support/merge_yaml.py (MIT)

import argparse
from copy import deepcopy
from pathlib import Path
from typing import Any, Dict

import yaml


def deep_merge(a: dict, b: dict) -> dict:
    result = deepcopy(a)
    for bk, bv in b.items():
        av = result.get(bk)
        if isinstance(av, dict) and isinstance(bv, dict):
            result[bk] = deep_merge(av, bv)
        else:
            result[bk] = deepcopy(bv)
    return result


parser = argparse.ArgumentParser()
parser.add_argument("base")
parser.add_argument("update")
args = parser.parse_args()

base_yaml = Path(args.base)
update_yaml = Path(args.update)

if not base_yaml.exists():
    print("The base YAML file doesn't exist")
    raise SystemExit(1)
if not update_yaml.exists():
    print("The update YAML file doesn't exist")
    raise SystemExit(1)

with base_yaml.open() as base_file:
    base: Dict[str, Any] = yaml.load(base_file, Loader=yaml.FullLoader)
if not base:
    print(f"Could not parse base file '{base_yaml}'")
    raise SystemExit(1)

with update_yaml.open() as update_file:
    update: Dict[str, Any] = yaml.load(update_file, Loader=yaml.FullLoader)
if not update:
    print(f"Could not parse update file '{update_yaml}'")
    raise SystemExit(1)

print(yaml.dump(deep_merge(base, update), default_flow_style=True))
