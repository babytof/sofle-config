#!/usr/bin/env bash
# Régénère docs/images/*.svg, build/out/zmk-sofle-layout-map.svg et docs/glyphs/
# (équivalent adapté de reference/zmk-config/support/update-layout-maps.sh — Sofle uniquement).
#
# Les glyphes sont copiés depuis le cache Keymap Drawer puis retouchés (width/height/fill)
# pour un rendu correct sur GitHub (README, etc.).
#
# Prérequis : venv ZMK avec keymap-drawer + PyYAML (merge_yaml).

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONFIG_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
KEYMAP_DRAWER_SUPPORT="${KEYMAP_DRAWER_SUPPORT:-$SCRIPT_DIR}"

ZMK_VENV="${ZMK_VENV:-$HOME/.virtualenvs/zmk}"
KEYMAP="${KEYMAP:-$ZMK_VENV/bin/keymap}"
PYTHON="${PYTHON:-$ZMK_VENV/bin/python}"

KEYMAP_JSON="${KEYMAP_JSON:-$CONFIG_ROOT/config/sofle.json}"
KEYMAP_FILE="${KEYMAP_FILE:-$CONFIG_ROOT/config/sofle.keymap}"

KD_CONFIG_MAIN="$KEYMAP_DRAWER_SUPPORT/keymap-config.yaml"
KD_NO_SYM="$KEYMAP_DRAWER_SUPPORT/keymap-config-no-shift-symbols.yaml"
KD_BG="$KEYMAP_DRAWER_SUPPORT/keymap-config-background-color.yaml"
MERGE_PY="$SCRIPT_DIR/merge_yaml.py"
APPEND_RC_PY="$SCRIPT_DIR/append_rc_reference_layer.py"
ANNOTATE_SVG_PY="$SCRIPT_DIR/annotate_layer_numbers_in_svg.py"

if [[ ! -f "$KD_CONFIG_MAIN" ]]; then
  echo "Fichier introuvable : $KD_CONFIG_MAIN" >&2
  exit 1
fi
if [[ ! -x "$KEYMAP" ]] && ! command -v keymap &>/dev/null; then
  echo "keymap introuvable : installe keymap-drawer dans le venv (make install-keymap-drawer)." >&2
  exit 1
fi
command -v "$KEYMAP" &>/dev/null || KEYMAP="keymap"

export_layer() {
  local KEYMAP_NAME=$1
  local LAYER_NAME=$2
  local LAYOUT_FILE=$3
  local EXTRA_LAYOUT="${4:-}"
  local -a EXTRA_FLAG=()

  if [[ -n "$EXTRA_LAYOUT" && -f "$EXTRA_LAYOUT" ]]; then
    EXTRA_FLAG+=("-j" "$EXTRA_LAYOUT")
  fi

  echo "- Export de la couche « $LAYER_NAME » → docs/images/$LAYOUT_FILE"
  "$KEYMAP" --config "$KD_CONFIG_MAIN" draw \
    "${EXTRA_FLAG[@]}" \
    -s "$LAYER_NAME" \
    -o "${CONFIG_ROOT}/docs/images/$LAYOUT_FILE" \
    "$KEYMAP_NAME"
}

export_layout_map() {
  local SHIELD_NAME="$1"
  local KEYS_COUNT="${2:-}"
  local EXTRA_LAYOUT="${3:-}"
  local KEYMAP_NAME
  local KD_KEYMAP
  local KD_CONFIG_NO_SYMBOLS
  local KD_CONFIG_BACKGROUND
  local -a LAYOUT_LAYERS
  local -a LAYOUT_MAP_NAMES
  local -a EXTRA_FLAG=()

  KEYMAP_NAME="$(echo "${SHIELD_NAME}" | tr "[:upper:]" "[:lower:]")"
  KD_PARSED="$(mktemp)"
  KD_KEYMAP="$(mktemp)"

  if [[ -n "$EXTRA_LAYOUT" && -f "$EXTRA_LAYOUT" ]]; then
    EXTRA_FLAG+=("-j" "$EXTRA_LAYOUT")
  fi

  echo "Génération des cartes de couches pour le clavier ${SHIELD_NAME}..."
  echo "- Parse Keymap Drawer → YAML temporaire"

  "$KEYMAP" --config "$KD_CONFIG_MAIN" parse -z "${CONFIG_ROOT}/config/${KEYMAP_NAME}.keymap" \
    | sed -n '1,/Navigation:/p' \
    | sed -e '$ d' >"$KD_PARSED"

  KD_CONFIG_NO_SYMBOLS="$(mktemp).yaml"
  "$PYTHON" "$MERGE_PY" \
    "$KD_CONFIG_MAIN" \
    "$KD_NO_SYM" >"$KD_CONFIG_NO_SYMBOLS"

  "$KEYMAP" --config "$KD_CONFIG_NO_SYMBOLS" parse -z "${CONFIG_ROOT}/config/${KEYMAP_NAME}.keymap" \
    | sed -n '/Navigation:/,$ p' >>"$KD_PARSED"

  "$PYTHON" "$APPEND_RC_PY" "$KD_PARSED" -o "$KD_KEYMAP"

  LAYOUT_LAYERS=(
    QWERTY Navigation Numbers Symbols Media Mouse Functions Buttons System COLEMAK
  )
  LAYOUT_MAP_NAMES=(
    layer0-main layer1-navigation layer2-numbers layer3-symbols layer4-media
    layer5-mouse layer6-functions layer7-buttons layer8-system layer9-colemak
  )

  local suffix=""
  [[ -n "$KEYS_COUNT" ]] && suffix="${KEYS_COUNT}"

  for i in "${!LAYOUT_LAYERS[@]}"; do
    export_layer "$KD_KEYMAP" "${LAYOUT_LAYERS[$i]}" \
      "${KEYMAP_NAME}${suffix}-${LAYOUT_MAP_NAMES[$i]}.svg" "$EXTRA_LAYOUT"
  done

  export_layer "$KD_KEYMAP" RC_REFERENCE \
    "${KEYMAP_NAME}${suffix}-layer-rc-reference.svg" "$EXTRA_LAYOUT"

  KD_CONFIG_BACKGROUND="$(mktemp).yaml"
  "$PYTHON" "$MERGE_PY" "$KD_CONFIG_MAIN" "$KD_BG" >"$KD_CONFIG_BACKGROUND"

  local out_full="zmk-${KEYMAP_NAME}"
  [[ -n "$KEYS_COUNT" ]] && out_full="${out_full}-${KEYS_COUNT}"
  out_full="${out_full}-layout-map.svg"

  echo "- Export de la carte complète (toutes les couches) → build/out/$out_full"
  mkdir -p "${CONFIG_ROOT}/build/out"
  "$KEYMAP" --config "$KD_CONFIG_BACKGROUND" draw \
    "${EXTRA_FLAG[@]}" \
    -s "${LAYOUT_LAYERS[@]}" \
    -o "${CONFIG_ROOT}/build/out/$out_full" \
    "$KD_KEYMAP"

  shopt -s nullglob
  _annotate=(
    "${CONFIG_ROOT}/docs/images/${KEYMAP_NAME}${suffix}"-*.svg
    "${CONFIG_ROOT}/build/out/$out_full"
  )
  shopt -u nullglob
  ((${#_annotate[@]})) && "$PYTHON" "$ANNOTATE_SVG_PY" "${_annotate[@]}"

  rm -f "$KD_KEYMAP" "$KD_CONFIG_NO_SYMBOLS" "$KD_CONFIG_BACKGROUND" "$KD_PARSED"

  echo "Terminé pour ${SHIELD_NAME}."
  echo ""
}

mkdir -p "${CONFIG_ROOT}/docs/images"

# Sofle : layout physique optionnel (comme Rolio pour Townk)
export_layout_map Sofle "" "$KEYMAP_JSON"

echo "Export des glyphes (cache Keymap Drawer → docs/glyphs)..."
GLYPH_CACHE="${KEYMAP_DRAWER_GLYPH_CACHE:-$HOME/Library/Caches/keymap-drawer/glyphs}"
mkdir -p "${CONFIG_ROOT}/docs/glyphs"

shopt -s nullglob
glyph_files=("$GLYPH_CACHE"/*)
shopt -u nullglob

if [[ ! -d "$GLYPH_CACHE" ]] || ((${#glyph_files[@]} == 0)); then
  echo "Avertissement : pas de glyphes dans $GLYPH_CACHE (lance au moins un draw/parse keymap-drawer)." >&2
else
  for g in "${glyph_files[@]}"; do
    [[ -f "$g" ]] || continue
    # GitHub : ajouter height, width et fill (comme Townk)
    sed 's/viewBox="0 0 24 24"/viewBox="0 0 24 24" height="20px" width="20px" fill="#e8eaed"/' "$g" \
      >"${CONFIG_ROOT}/docs/glyphs/${g#*mdi:}"
  done
fi

echo "Terminé."
