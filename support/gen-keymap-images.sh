#!/usr/bin/env bash
# Génère les SVG par couche (équivalent Townk update-layout-maps.sh, Sofle uniquement).
# Configs Keymap Drawer : ce répertoire (support/keymap-config*.yaml).
#
# Prérequis : venv ZMK avec keymap-drawer + PyYAML (merge_yaml).

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SOFLE_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
# Surcharge possible : export KEYMAP_DRAWER_SUPPORT=/chemin/vers/yamls
KEYMAP_DRAWER_SUPPORT="${KEYMAP_DRAWER_SUPPORT:-$SCRIPT_DIR}"

ZMK_VENV="${ZMK_VENV:-$HOME/.virtualenvs/zmk}"
KEYMAP="${KEYMAP:-$ZMK_VENV/bin/keymap}"
PYTHON="${PYTHON:-$ZMK_VENV/bin/python}"

KEYMAP_JSON="${KEYMAP_JSON:-$SOFLE_ROOT/config/sofle.json}"
KEYMAP_FILE="${KEYMAP_FILE:-$SOFLE_ROOT/config/sofle.keymap}"
OUT_DIR="${OUT_DIR:-$SOFLE_ROOT/docs/images}"

KD_CONFIG_MAIN="$KEYMAP_DRAWER_SUPPORT/keymap-config.yaml"
KD_NO_SYM="$KEYMAP_DRAWER_SUPPORT/keymap-config-no-shift-symbols.yaml"
KD_BG="$KEYMAP_DRAWER_SUPPORT/keymap-config-background-color.yaml"
MERGE_PY="$SCRIPT_DIR/merge_yaml.py"
APPLY_LOCALE_PY="$SCRIPT_DIR/apply_keymap_locale.py"
APPEND_RC_PY="$SCRIPT_DIR/append_rc_reference_layer.py"
ANNOTATE_SVG_PY="$SCRIPT_DIR/annotate_layer_numbers_in_svg.py"

if [[ ! -f "$KD_CONFIG_MAIN" ]]; then
  echo "Fichier introuvable : $KD_CONFIG_MAIN" >&2
  echo "Attendu : keymap-config.yaml dans support/ (ou KEYMAP_DRAWER_SUPPORT)." >&2
  exit 1
fi
if [[ ! -f "$APPLY_LOCALE_PY" ]]; then
  echo "Fichier introuvable : $APPLY_LOCALE_PY" >&2
  exit 1
fi
if [[ ! -x "$KEYMAP" ]] && ! command -v keymap &>/dev/null; then
  echo "keymap introuvable : installe keymap-drawer dans le venv (make install-keymap-drawer)." >&2
  exit 1
fi
command -v "$KEYMAP" &>/dev/null || KEYMAP="keymap"

export_layer() {
  local KD_KEYMAP=$1
  local LAYER_NAME=$2
  local OUT_FILE=$3
  local -a EXTRA_FLAG=()
  [[ -n "${KEYMAP_JSON:-}" && -f "$KEYMAP_JSON" ]] && EXTRA_FLAG+=("-j" "$KEYMAP_JSON")

  echo "- Couche « $LAYER_NAME » → $OUT_FILE"
  "$KEYMAP" --config "$KD_EFFECTIVE_MAIN" draw \
    "${EXTRA_FLAG[@]}" \
    -s "$LAYER_NAME" \
    -o "$OUT_DIR/$OUT_FILE" \
    "$KD_KEYMAP"
}

echo "Keymap Drawer (style Townk) — Sofle"
echo "- Parse + fusion YAML (couches base avec légendes Shift, puis le reste sans)"
mkdir -p "$OUT_DIR"

KEYMAP_LOCALE_MAP="${KEYMAP_LOCALE_MAP:-$SOFLE_ROOT/support/locale-maps/osx/fr_azerty_iso.csv}"
KD_EFFECTIVE_MAIN="$KD_CONFIG_MAIN"
KD_LOCALE_TMP=""
if [[ -n "${KEYMAP_LOCALE_MAP:-}" && -f "$KEYMAP_LOCALE_MAP" ]]; then
  echo "- Carte locale (légendes) : $KEYMAP_LOCALE_MAP"
  KD_LOCALE_TMP="$(mktemp)"
  "$PYTHON" "$APPLY_LOCALE_PY" "$KD_CONFIG_MAIN" "$KEYMAP_LOCALE_MAP" -o "$KD_LOCALE_TMP"
  KD_EFFECTIVE_MAIN="$KD_LOCALE_TMP"
elif [[ -n "${KEYMAP_LOCALE_MAP:-}" ]]; then
  echo "Attention : KEYMAP_LOCALE_MAP ignoré (fichier introuvable) : $KEYMAP_LOCALE_MAP" >&2
fi

KD_PARSED="$(mktemp)"
KD_KEYMAP="$(mktemp)"
KD_CONFIG_NO_SYMBOLS="$(mktemp)"
KD_CONFIG_BACKGROUND="$(mktemp)"
cleanup() {
  rm -f "$KD_PARSED" "$KD_KEYMAP" "$KD_CONFIG_NO_SYMBOLS" "$KD_CONFIG_BACKGROUND"
  [[ -n "${KD_LOCALE_TMP:-}" ]] && rm -f "$KD_LOCALE_TMP"
}
trap cleanup EXIT

"$PYTHON" "$MERGE_PY" "$KD_EFFECTIVE_MAIN" "$KD_NO_SYM" >"$KD_CONFIG_NO_SYMBOLS"

# Bloc 1 : jusqu’à la ligne « Navigation: » (exclue) — mêmes noms de couches que Townk
"$KEYMAP" --config "$KD_EFFECTIVE_MAIN" parse -z "$KEYMAP_FILE" \
  | sed -n '1,/Navigation:/p' \
  | sed -e '$ d' >"$KD_PARSED"

"$KEYMAP" --config "$KD_CONFIG_NO_SYMBOLS" parse -z "$KEYMAP_FILE" \
  | sed -n '/Navigation:/,$ p' >>"$KD_PARSED"

# Couche purement graphique (absente du firmware) : RC(row,col) du transform Sofle
"$PYTHON" "$APPEND_RC_PY" "$KD_PARSED" -o "$KD_KEYMAP"

LAYOUT_LAYERS=(
  QWERTY Navigation Numbers Symbols Media Mouse Functions Buttons System COLEMAK
)
LAYOUT_MAP_NAMES=(
  layer0-main layer1-navigation layer2-numbers layer3-symbols layer4-media
  layer5-mouse layer6-functions layer7-buttons layer8-system layer9-colemak
)

for i in "${!LAYOUT_LAYERS[@]}"; do
  export_layer "$KD_KEYMAP" "${LAYOUT_LAYERS[$i]}" "sofle-${LAYOUT_MAP_NAMES[$i]}.svg"
done

export_layer "$KD_KEYMAP" RC_REFERENCE sofle-layer-rc-reference.svg

"$PYTHON" "$MERGE_PY" "$KD_EFFECTIVE_MAIN" "$KD_BG" >"$KD_CONFIG_BACKGROUND"
mkdir -p "$SOFLE_ROOT/build/out"
echo "- Vue complète (fond noir) → build/out/zmk-sofle-layout-map.svg"
KEYMAP_JSON_ARG=()
[[ -f "$KEYMAP_JSON" ]] && KEYMAP_JSON_ARG=(-j "$KEYMAP_JSON")
"$KEYMAP" --config "$KD_CONFIG_BACKGROUND" draw \
  "${KEYMAP_JSON_ARG[@]}" \
  -s "${LAYOUT_LAYERS[@]}" \
  -o "$SOFLE_ROOT/build/out/zmk-sofle-layout-map.svg" \
  "$KD_KEYMAP"

shopt -s nullglob
annotate_targets=(
  "$OUT_DIR"/sofle-layer*.svg
  "$SOFLE_ROOT/build/out/zmk-sofle-layout-map.svg"
)
shopt -u nullglob
((${#annotate_targets[@]})) && "$PYTHON" "$ANNOTATE_SVG_PY" "${annotate_targets[@]}"

echo "Terminé. Images : $OUT_DIR/sofle-layer*.svg (dont sofle-layer-rc-reference.svg = couche RC seule)"
echo "Glyphes MDI (README, etc.) : $SOFLE_ROOT/docs/glyphs/"
