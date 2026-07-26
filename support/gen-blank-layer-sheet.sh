#!/usr/bin/env bash
# Gabarit imprimable : N couches Sofle vierges (SVG) + page HTML.
#
# Prérequis : venv ZMK avec keymap-drawer (make install-keymap-drawer).

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SOFLE_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

ZMK_VENV="${ZMK_VENV:-$HOME/.virtualenvs/zmk}"
KEYMAP="${KEYMAP:-$ZMK_VENV/bin/keymap}"
PYTHON="${PYTHON:-$ZMK_VENV/bin/python}"

KEYMAP_JSON="${KEYMAP_JSON:-$SOFLE_ROOT/config/sofle.json}"
OUT_DIR="${OUT_DIR:-$SOFLE_ROOT/docs/images}"
OUT_HTML="$OUT_DIR/blank-layer-sheet.html"
BLANK_LAYER_COUNT="${BLANK_LAYER_COUNT:-3}"

KD_CONFIG_MAIN="$SCRIPT_DIR/keymap-config.yaml"
KD_PRINT_BLANK="$SCRIPT_DIR/keymap-config-print-blank.yaml"
MERGE_PY="$SCRIPT_DIR/merge_yaml.py"
APPEND_BLANK_PY="$SCRIPT_DIR/append_blank_layers.py"

if [[ ! -x "$KEYMAP" ]] && ! command -v keymap &>/dev/null; then
  echo "keymap introuvable : installe keymap-drawer dans le venv (make install-keymap-drawer)." >&2
  exit 1
fi
command -v "$KEYMAP" &>/dev/null || KEYMAP="keymap"

mkdir -p "$OUT_DIR"

KD_KEYMAP="$(mktemp)"
KD_DRAW_CFG="$(mktemp)"
cleanup() {
  rm -f "$KD_KEYMAP" "$KD_DRAW_CFG"
}
trap cleanup EXIT

echo "Gabarit couches vierges — Sofle ($BLANK_LAYER_COUNT par page)"
echo "- YAML minimal (BLANK_1 … BLANK_${BLANK_LAYER_COUNT})"
"$PYTHON" "$APPEND_BLANK_PY" --standalone --count "$BLANK_LAYER_COUNT" -o "$KD_KEYMAP"

echo "- Config rendu impression (fond blanc)"
"$PYTHON" "$MERGE_PY" "$KD_CONFIG_MAIN" "$KD_PRINT_BLANK" >"$KD_DRAW_CFG"

KEYMAP_JSON_ARG=()
[[ -f "$KEYMAP_JSON" ]] && KEYMAP_JSON_ARG=(-j "$KEYMAP_JSON")

OUT_SVGS=()
for i in $(seq 1 "$BLANK_LAYER_COUNT"); do
  out="$OUT_DIR/sofle-layer-blank-${i}.svg"
  OUT_SVGS+=("$out")
  echo "- SVG couche $i → $out"
  "$KEYMAP" --config "$KD_DRAW_CFG" draw \
    "${KEYMAP_JSON_ARG[@]}" \
    -s "BLANK_${i}" \
    --keys-only \
    -o "$out" \
    "$KD_KEYMAP"
done

echo "- HTML → $OUT_HTML"
{
  cat <<'HTMLEOF'
<!DOCTYPE html>
<html lang="fr">
<head>
  <meta charset="utf-8" />
  <meta name="viewport" content="width=device-width, initial-scale=1" />
  <title>Sofle — gabarit couches vierges</title>
  <style>
    * { box-sizing: border-box; }
    :root {
      --ink: #1a1a1a;
      --muted: #666;
      --line: #ccc;
    }
    body {
      margin: 0;
      padding: 1rem 1.25rem 2rem;
      font-family: system-ui, -apple-system, sans-serif;
      color: var(--ink);
      background: #f5f5f5;
    }
    .sheet {
      max-width: 900px;
      margin: 0 auto;
      background: #fff;
      padding: 1rem 1.25rem 1.5rem;
      border: 1px solid var(--line);
      border-radius: 4px;
    }
    header {
      margin-bottom: 0.75rem;
      padding-bottom: 0.5rem;
      border-bottom: 1px solid var(--line);
    }
    h1 {
      margin: 0 0 0.25rem;
      font-size: 1.15rem;
      font-weight: 600;
    }
    .hint {
      margin: 0;
      font-size: 0.8rem;
      color: var(--muted);
      line-height: 1.4;
    }
    .hint code { font-size: 0.78rem; }
    .layer-block {
      margin: 0 0 1.25rem;
      page-break-inside: avoid;
      break-inside: avoid;
    }
    .layer-block:last-child { margin-bottom: 0; }
    .layer-title {
      display: flex;
      align-items: baseline;
      gap: 0.5rem;
      margin: 0 0 0.35rem;
      font-size: 0.9rem;
    }
    .layer-title .num {
      flex: 0 0 auto;
      font-weight: 600;
    }
    .layer-title .name {
      flex: 1 1 auto;
      border-bottom: 1px dotted var(--line);
      min-height: 1.2em;
    }
    .layer-title .name:empty::before {
      content: "nom de la couche…";
      color: #bbb;
      font-weight: 400;
      font-style: italic;
    }
    figure { margin: 0; }
    figure img {
      display: block;
      width: 100%;
      height: auto;
    }
    .toolbar {
      margin: 1rem auto 0;
      max-width: 900px;
      text-align: center;
    }
    .toolbar button {
      font: inherit;
      font-size: 0.9rem;
      padding: 0.45rem 1rem;
      cursor: pointer;
      border: 1px solid #888;
      border-radius: 4px;
      background: #fff;
    }
    .toolbar button:hover { background: #eee; }
    @media print {
      html, body {
        margin: 0;
        padding: 0;
        background: #fff;
      }
      .sheet {
        max-width: none;
        border: none;
        border-radius: 0;
        padding: 0;
        page-break-inside: avoid;
        break-inside: avoid;
      }
      .toolbar, .hint-screen { display: none !important; }
      header {
        margin: 0 0 1.5mm;
        padding: 0 0 1mm;
        border-bottom: 0.5pt solid var(--line);
      }
      h1 {
        font-size: 9pt;
        line-height: 1.15;
        margin: 0;
      }
      .layer-block {
        margin: 0 0 1.5mm;
        page-break-inside: avoid;
        break-inside: avoid;
      }
      .layer-block:last-child { margin-bottom: 0; }
      .layer-title {
        margin: 0 0 0.5mm;
        font-size: 7.5pt;
        line-height: 1.15;
        gap: 0.35rem;
      }
      figure img {
        width: 100%;
        height: auto;
        max-height: 82mm;
        object-fit: contain;
      }
      @page {
        size: A4 portrait;
        margin: 3mm 6mm;
      }
    }
  </style>
</head>
<body>
  <div class="sheet">
    <header>
      <h1>Sofle — brouillon de couches</h1>
      <p class="hint hint-screen">
        Gabarit vierge pour esquisser de nouvelles combinaisons.
        Régénération : <code>make keymap-blank-sheet</code>.
        Ouvrir ce fichier localement (<code>file://</code>) ou via un serveur statique.
      </p>
    </header>
HTMLEOF

  for i in $(seq 1 "$BLANK_LAYER_COUNT"); do
    cat <<EOF

    <section class="layer-block" aria-label="Couche $i">
      <p class="layer-title">
        <span class="num">Couche $i</span>
        <span class="name" contenteditable="true" spellcheck="false"></span>
      </p>
      <figure>
        <img src="sofle-layer-blank-${i}.svg" alt="Sofle — couche vierge $i" width="900" height="428" />
      </figure>
    </section>
EOF
  done

  cat <<'HTMLEOF'
  </div>

  <p class="toolbar hint-screen">
    <button type="button" onclick="window.print()">Imprimer…</button>
  </p>
</body>
</html>
HTMLEOF
} >"$OUT_HTML"

echo "Terminé."
for out in "${OUT_SVGS[@]}"; do
  echo "  SVG  : $out"
done
echo "  Page : $OUT_HTML"
echo "Ouvrir $OUT_HTML dans le navigateur, puis Imprimer (portrait A4, $BLANK_LAYER_COUNT couches)."
