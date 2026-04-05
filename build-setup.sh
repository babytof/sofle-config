#!/usr/bin/env bash
# Prépare l’environnement Python (venv actif) + dépôts West pour ce Makefile ZMK.
# Usage : activer ton venv ZMK, puis depuis la racine du dépôt :
#   ./build-setup.sh
#
# Prérequis hors script : [Zephyr SDK](https://github.com/zephyrproject-rtos/sdk-ng/releases)
# (toolchain arm-zephyr-eabi, ./setup.sh -c …) — requis pour « make left » / « make all ».
#
# Patches modules West : après « west update », support/patches/{zephyr,zmk,zmk-tri-state}/\*.patch
# sont appliqués avec « git apply » (voir support/patches/README.txt).

set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$ROOT"

# Réinitialise le module puis applique les .patch dans l’ordre (idempotent si relancé).
# Sans aucun .patch : ne touche pas au module (pas de reset).
apply_patches_dir() {
	local module_path="$1"
	local patches_dir="$2"
	local -a patches

	shopt -s nullglob
	patches=( "$patches_dir"/*.patch )
	shopt -u nullglob
	if ((${#patches[@]} == 0)); then
		return 0
	fi

	if [[ ! -d "$module_path" ]]; then
		echo "Erreur : patches présents mais module introuvable : $module_path" >&2
		echo "Lance « west update » ou vérifie le manifest." >&2
		exit 1
	fi
	if ! git -C "$module_path" rev-parse --is-inside-work-tree >/dev/null 2>&1; then
		echo "Avertissement : pas de dépôt Git dans $module_path — patches ignorés." >&2
		return 0
	fi

	echo "==> Patches : $(basename "$module_path") (${#patches[@]} fichier(s) dans $(basename "$patches_dir")/)"
	git -C "$module_path" reset --hard HEAD
	git -C "$module_path" clean -fd

	local p
	while IFS= read -r p; do
		[[ -n "$p" ]] || continue
		echo "    git apply → $(basename "$p")"
		if ! git -C "$module_path" apply "$p"; then
			echo "Erreur : git apply a échoué : $p" >&2
			[[ -f "$patches_dir/README.txt" ]] && echo "Consulter : $patches_dir/README.txt" >&2
			echo "Index : $ROOT/support/patches/README.txt" >&2
			exit 1
		fi
	done < <(printf '%s\n' "${patches[@]}" | LC_ALL=C sort)
}

if [[ -z "${VIRTUAL_ENV:-}" ]]; then
	echo "Erreur : aucun virtualenv Python actif (variable VIRTUAL_ENV vide)." >&2
	echo "Active d’abord ton venv ZMK, par ex. :" >&2
	echo "  source \"\${HOME}/.virtualenvs/zmk/bin/activate\"" >&2
	exit 1
fi

echo "==> Virtualenv : $VIRTUAL_ENV"

if [[ ! -f "$ROOT/config/west.yml" ]]; then
	echo "Erreur : manifest West introuvable : $ROOT/config/west.yml" >&2
	exit 1
fi

if [[ ! -f "$ROOT/.west/config" ]]; then
	echo "==> Initialisation du workspace West (west init -l config)…"
	west init -l config
fi

echo "==> pip : west + dépendances Zephyr (build) + Keymap Drawer…"
python -m pip install --upgrade pip wheel setuptools
python -m pip install west

echo "==> west update (zephyr, zmk, modules/zmk-tri-state, …)…"
west update

# Ordre : zephyr → zmk → modules (dépendances logiques si plusieurs patches cohabitent).
apply_patches_dir "$ROOT/zephyr" "$ROOT/support/patches/zephyr"
apply_patches_dir "$ROOT/zmk" "$ROOT/support/patches/zmk"
apply_patches_dir "$ROOT/modules/zmk-tri-state" "$ROOT/support/patches/zmk-tri-state"

REQ_ZEPHYR="$ROOT/zephyr/scripts/requirements.txt"
if [[ -f "$REQ_ZEPHYR" ]]; then
	echo "==> pip install -r zephyr/scripts/requirements.txt"
	python -m pip install -r "$REQ_ZEPHYR"
else
	echo "Avertissement : $REQ_ZEPHYR absent — « west update » a peut-être échoué." >&2
fi

REQ_DRAWER="$ROOT/config/requirements-drawer.txt"
if [[ -f "$REQ_DRAWER" ]]; then
	echo "==> pip install -r config/requirements-drawer.txt"
	python -m pip install -r "$REQ_DRAWER"
fi

for cmd in cmake ninja; do
	if ! command -v "$cmd" >/dev/null 2>&1; then
		echo "Avertissement : « $cmd » introuvable dans le PATH (souvent requis pour le build)." >&2
	fi
done

cat <<'EOF'

Terminé. Prérequis build firmware : Zephyr SDK installé et visible par CMake
(ZEPHYR_SDK_INSTALL_DIR ou enregistrement via ./setup.sh -c du SDK).

Tu peux lancer par ex. :
  make keymap-images
  make left

─── Patches versionnés (zephyr, zmk, zmk-tri-state) ─────────────────────────
support/patches/{zephyr,zmk,zmk-tri-state}/*.patch : appliqués après « west update »
(reset --hard + clean dans le module, puis git apply). Index : support/patches/README.txt

─── West / .gitignore ───────────────────────────────────────────────────────
zephyr/, zmk/, modules/ ne sont pas versionnés dans ce dépôt : tout repose sur
west.yml + éventuels patches. Figer revision: <sha> dans config/west.yml stabilise
les mises à jour ; les patches se régénèrent si l’amont diverge.
EOF
