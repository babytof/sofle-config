#!/usr/bin/env bash
# Génère les SVG par couche (équivalent Townk update-layout-maps.sh, Sofle uniquement).
# Puis un PNG pour chaque SVG (largeur KEYMAP_IMAGE_PNG_WIDTH, défaut 2400 px).
# Configs Keymap Drawer : ce répertoire (support/keymap-config*.yaml).
#
# Prérequis : venv ZMK avec keymap-drawer + PyYAML (merge_yaml).
# PNG : Inkscape (prioritaire) ou rsvg-convert + aplatissement MDI (svg_flatten_mdi_uses.py).
# Désactiver : KEYMAP_SKIP_PNG=1. Forcer moteur : KEYMAP_PNG_RENDERER=inkscape|rsvg|auto

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SOFLE_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
# Surcharge possible : export KEYMAP_DRAWER_SUPPORT=/chemin/vers/yamls
KEYMAP_DRAWER_SUPPORT="${KEYMAP_DRAWER_SUPPORT:-$SCRIPT_DIR}"
KD_SYM_DRAW_OVERLAY="${KD_SYM_DRAW_OVERLAY:-$KEYMAP_DRAWER_SUPPORT/keymap-config-symbol-layer-draw.yaml}"

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
FLATTEN_SVG_PY="$SCRIPT_DIR/svg_flatten_mdi_uses.py"

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
  local KD_DRAW_CFG="$KD_EFFECTIVE_MAIN"
  [[ -n "${KEYMAP_JSON:-}" && -f "$KEYMAP_JSON" ]] && EXTRA_FLAG+=("-j" "$KEYMAP_JSON")

  # Symbols : locale + no-shift (+ overlay caractères une ligne si présent).
  if [[ "$LAYER_NAME" == "Symbols" ]]; then
    KD_DRAW_CFG="$KD_SYMBOL_DRAW"
  fi

  echo "- Couche « $LAYER_NAME » → $OUT_FILE"
  "$KEYMAP" --config "$KD_DRAW_CFG" draw \
    "${EXTRA_FLAG[@]}" \
    -s "$LAYER_NAME" \
    -o "$OUT_DIR/$OUT_FILE" \
    "$KD_KEYMAP"
}

echo "Keymap Drawer (style Townk) — Sofle"
echo "- Parse + fusion YAML (couches base avec légendes Shift, puis le reste sans)"
echo "- Couche « Symbols » : rendu avec no-shift + ${KD_SYM_DRAW_OVERLAY##*/} (légendes tap)"
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
  [[ -n "${KD_SYM_DRAW_TMP:-}" ]] && rm -f "$KD_SYM_DRAW_TMP"
  [[ -n "${KD_MAP_ALL_TMP:-}" ]] && rm -f "$KD_MAP_ALL_TMP"
}
trap cleanup EXIT

"$PYTHON" "$MERGE_PY" "$KD_EFFECTIVE_MAIN" "$KD_NO_SYM" >"$KD_CONFIG_NO_SYMBOLS"

KD_SYM_DRAW_TMP=""
KD_SYMBOL_DRAW="$KD_CONFIG_NO_SYMBOLS"
if [[ -f "$KD_SYM_DRAW_OVERLAY" ]]; then
  KD_SYM_DRAW_TMP="$(mktemp)"
  "$PYTHON" "$MERGE_PY" "$KD_CONFIG_NO_SYMBOLS" "$KD_SYM_DRAW_OVERLAY" >"$KD_SYM_DRAW_TMP"
  KD_SYMBOL_DRAW="$KD_SYM_DRAW_TMP"
fi

# Bloc 1 : jusqu’à la ligne « Navigation: » (exclue) — mêmes noms de couches que Townk
"$KEYMAP" --config "$KD_EFFECTIVE_MAIN" parse -z "$KEYMAP_FILE" \
  | sed -n '1,/Navigation:/p' \
  | sed -e '$ d' >"$KD_PARSED"

# Navigation → System : même fusion que le rendu Symbols (no-shift + overlay caractères).
"$KEYMAP" --config "$KD_SYMBOL_DRAW" parse -z "$KEYMAP_FILE" \
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
KD_MAP_ALL_DRAW="$KD_CONFIG_BACKGROUND"
KD_MAP_ALL_TMP=""
if [[ -f "$KD_SYM_DRAW_OVERLAY" ]]; then
  KD_MAP_ALL_TMP="$(mktemp)"
  "$PYTHON" "$MERGE_PY" "$KD_CONFIG_BACKGROUND" "$KD_SYM_DRAW_OVERLAY" >"$KD_MAP_ALL_TMP"
  KD_MAP_ALL_DRAW="$KD_MAP_ALL_TMP"
fi
mkdir -p "$SOFLE_ROOT/build/out"
echo "- Vue complète (fond noir) → build/out/zmk-sofle-layout-map.svg"
KEYMAP_JSON_ARG=()
[[ -f "$KEYMAP_JSON" ]] && KEYMAP_JSON_ARG=(-j "$KEYMAP_JSON")
"$KEYMAP" --config "$KD_MAP_ALL_DRAW" draw \
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

KEYMAP_IMAGE_PNG_WIDTH="${KEYMAP_IMAGE_PNG_WIDTH:-2400}"

_png_via_inkscape() {
  inkscape --batch-process "$1" -o "$2" -w "$KEYMAP_IMAGE_PNG_WIDTH"
}

_png_via_rsvg_flat() {
  local svg=$1 png=$2 flat
  if [[ ! -f "$FLATTEN_SVG_PY" ]]; then
    echo "Fichier introuvable : $FLATTEN_SVG_PY" >&2
    return 1
  fi
  flat="$(mktemp "${TMPDIR:-/tmp}/keymapflat.XXXXXX")"
  "$PYTHON" "$FLATTEN_SVG_PY" "$svg" "$flat"
  rsvg-convert -w "$KEYMAP_IMAGE_PNG_WIDTH" -o "$png" "$flat"
  rm -f "$flat"
}

svg_to_png() {
  local svg=$1
  local png="${svg%.svg}.png"
  case "${KEYMAP_PNG_RENDERER:-auto}" in
    inkscape)
      command -v inkscape &>/dev/null || return 1
      _png_via_inkscape "$svg" "$png"
      ;;
    rsvg)
      command -v rsvg-convert &>/dev/null || return 1
      _png_via_rsvg_flat "$svg" "$png"
      ;;
    auto|*)
      if command -v inkscape &>/dev/null; then
        _png_via_inkscape "$svg" "$png"
      elif command -v rsvg-convert &>/dev/null; then
        _png_via_rsvg_flat "$svg" "$png"
      else
        return 1
      fi
      ;;
  esac
}

if [[ "${KEYMAP_SKIP_PNG:-}" == "1" ]]; then
  echo "- PNG : ignoré (KEYMAP_SKIP_PNG=1)"
else
  if ! command -v rsvg-convert &>/dev/null && ! command -v inkscape &>/dev/null; then
    echo "Erreur : installe rsvg-convert (ex. brew install librsvg) ou Inkscape pour générer les PNG." >&2
    exit 1
  fi
  if ! command -v inkscape &>/dev/null && [[ ! -f "$FLATTEN_SVG_PY" ]]; then
    echo "Erreur : $FLATTEN_SVG_PY requis pour rsvg-convert (glyphes MDI)." >&2
    exit 1
  fi
  echo "- Export PNG (${KEYMAP_IMAGE_PNG_WIDTH}px, moteur ${KEYMAP_PNG_RENDERER:-auto}) …"
  for svg in "${annotate_targets[@]}"; do
    [[ -f "$svg" ]] || continue
    svg_to_png "$svg"
    echo "  → ${svg%.svg}.png"
  done
fi

echo "Terminé. Images : $OUT_DIR/sofle-layer*.svg (+ .png) ; build/out/zmk-sofle-layout-map.svg (+ .png)"
echo "Glyphes MDI (README, etc.) : $SOFLE_ROOT/docs/glyphs/"
