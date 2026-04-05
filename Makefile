# ZMK — Sofle Choc Pro BT (board sofle_choc_pro_left / _right + shield nice_view_disp).
# Matrice identique au shield Sofle classique (SOFLE60 / Townk) : même keymap que sofle.keymap.
#
# Ancienne cible nice!nano + sofle_* : remplacée — les UF2 pour Choc Pro BT exigent ce board.
#
# Prérequis : west dans le PATH (ex. source ~/.virtualenvs/zmk/bin/activate)
#
# Keymap Drawer : dans le même venv que ZMK (pas d’install globale).
#   make install-keymap-drawer   # une fois : pip install -r config/requirements-drawer.txt
#   make keymap-drawer           # SVG rapide (toutes les couches dans un fichier)
#   make keymap-images           # une SVG par couche + locale (défaut : osx/fr_azerty_iso.csv)
#
# Keymap Drawer : configs dans support/ (d’origine Townk zmk-config, MIT).
KEYMAP_DRAWER_CFG ?= $(CURDIR)/support/keymap-config.yaml
# Légendes « sortie OS » pour keymap-images (CSV). Vide = désactiver (QWERTY US du YAML).
KEYMAP_LOCALE_MAP ?= $(CURDIR)/support/locale-maps/osx/fr_azerty_iso.csv
#
# Défaut : build incrémental (sans -p). Rebuild complet : make left PRISTINE=1
# UF2 : build/.../zmk.uf2 copiés dans firmware/ (fichiers réels — glisser-déposer vers UF2)

BOARD_LEFT   ?= sofle_choc_pro_left
BOARD_RIGHT  ?= sofle_choc_pro_right
SHIELD_VIEW  ?= nice_view_disp
ZMK_APP      ?= zmk/app
KEYMAP_FILE  ?= $(CURDIR)/config/sofle.keymap
# PRISTINE non vide → west build -p (ex. PRISTINE=1)
PRISTINE ?=

WEST = west build$(if $(strip $(PRISTINE)), -p,) -s $(ZMK_APP)

# Kconfig / keymap utilisateur (reset : pas de KEYMAP_FILE → keymap du shield settings_reset)
CHOC_FLAGS_COMMON = -DZMK_CONFIG="$(CURDIR)/config" -DDTS_EXTRA_CPPFLAGS="-DUSE_MOLOCK=1"
CHOC_FLAGS_KEYMAP = $(CHOC_FLAGS_COMMON) -DKEYMAP_FILE="$(KEYMAP_FILE)"

# Fork Townk (mousemove-molock) : pas de snippet ZMK Studio — voir archive/sofle-choc-pro-bt/build.yaml pour ZMK officiel.
CHOC_FLAGS_LEFT  = $(CHOC_FLAGS_KEYMAP) -DSHIELD="$(SHIELD_VIEW)"
CHOC_FLAGS_RIGHT = $(CHOC_FLAGS_KEYMAP) -DSHIELD="$(SHIELD_VIEW)"

# Environnement Python / Keymap Drawer (même venv que west)
ZMK_VENV         ?= $(HOME)/.virtualenvs/zmk
PIP_ZMK          := $(ZMK_VENV)/bin/pip
KEYMAP           := $(ZMK_VENV)/bin/keymap
KEYMAP_LAYOUT    := $(CURDIR)/config/sofle.json
KEYMAP_PARSED    := $(CURDIR)/build/keymap_drawer.yaml
KEYMAP_SVG       := $(CURDIR)/build/keymap.svg

.DEFAULT_GOAL := all

.PHONY: all left right reset-left reset-right reset clean firmware help \
	install-keymap-drawer keymap-drawer keymap-images

all:
	@echo "=== Build Sofle Choc Pro BT (left, right, reset-left, reset-right) ==="
	$(WEST) -d build/left -b $(BOARD_LEFT) -- $(CHOC_FLAGS_LEFT)
	$(WEST) -d build/right -b $(BOARD_RIGHT) -- $(CHOC_FLAGS_RIGHT)
	$(WEST) -d build/reset-left -b $(BOARD_LEFT) -- $(CHOC_FLAGS_COMMON) -DSHIELD=settings_reset
	$(WEST) -d build/reset-right -b $(BOARD_RIGHT) -- $(CHOC_FLAGS_COMMON) -DSHIELD=settings_reset
	@$(MAKE) --no-print-directory firmware
	@echo "UF2 copiés : $(CURDIR)/firmware/"
	@echo "=== Terminé ==="

left:
	@echo "=== Build LEFT ($(BOARD_LEFT) + $(SHIELD_VIEW)) ==="
	$(WEST) -d build/left -b $(BOARD_LEFT) -- $(CHOC_FLAGS_LEFT)
	@$(MAKE) --no-print-directory firmware
	@echo "UF2 : $(CURDIR)/firmware/zmk-left.uf2  (copie de build/left/zephyr/zmk.uf2)"

right:
	@echo "=== Build RIGHT ($(BOARD_RIGHT) + $(SHIELD_VIEW)) ==="
	$(WEST) -d build/right -b $(BOARD_RIGHT) -- $(CHOC_FLAGS_RIGHT)
	@$(MAKE) --no-print-directory firmware
	@echo "UF2 : $(CURDIR)/firmware/zmk-right.uf2  (copie de build/right/zephyr/zmk.uf2)"

reset-left:
	@echo "=== Build RESET moitié GAUCHE ($(BOARD_LEFT) + settings_reset) ==="
	$(WEST) -d build/reset-left -b $(BOARD_LEFT) -- $(CHOC_FLAGS_COMMON) -DSHIELD=settings_reset
	@$(MAKE) --no-print-directory firmware
	@echo "UF2 : $(CURDIR)/firmware/zmk-reset-left.uf2  (copie de build/reset-left/zephyr/zmk.uf2)"

reset-right:
	@echo "=== Build RESET moitié DROITE ($(BOARD_RIGHT) + settings_reset) ==="
	$(WEST) -d build/reset-right -b $(BOARD_RIGHT) -- $(CHOC_FLAGS_COMMON) -DSHIELD=settings_reset
	@$(MAKE) --no-print-directory firmware
	@echo "UF2 : $(CURDIR)/firmware/zmk-reset-right.uf2  (copie de build/reset-right/zephyr/zmk.uf2)"

reset:
	@echo "=== Build RESET (gauche + droite) ==="
	$(WEST) -d build/reset-left -b $(BOARD_LEFT) -- $(CHOC_FLAGS_COMMON) -DSHIELD=settings_reset
	$(WEST) -d build/reset-right -b $(BOARD_RIGHT) -- $(CHOC_FLAGS_COMMON) -DSHIELD=settings_reset
	@$(MAKE) --no-print-directory firmware
	@echo "UF2 copiés : $(CURDIR)/firmware/"
	@echo "=== Terminé ==="

firmware:
	@mkdir -p firmware
	@test -f build/left/zephyr/zmk.uf2 && cp -f build/left/zephyr/zmk.uf2 firmware/zmk-left.uf2 || true
	@test -f build/right/zephyr/zmk.uf2 && cp -f build/right/zephyr/zmk.uf2 firmware/zmk-right.uf2 || true
	@test -f build/reset-left/zephyr/zmk.uf2 && cp -f build/reset-left/zephyr/zmk.uf2 firmware/zmk-reset-left.uf2 || true
	@test -f build/reset-right/zephyr/zmk.uf2 && cp -f build/reset-right/zephyr/zmk.uf2 firmware/zmk-reset-right.uf2 || true

clean:
	rm -rf build firmware
	@echo "Supprimé : build/ firmware/"

install-keymap-drawer:
	@test -x "$(PIP_ZMK)" || (echo "Venv introuvable : $(ZMK_VENV) (variable ZMK_VENV)" >&2; exit 1)
	"$(PIP_ZMK)" install -r "$(CURDIR)/config/requirements-drawer.txt"

keymap-drawer: $(KEYMAP_SVG)

$(KEYMAP_PARSED): config/sofle.keymap
	@test -x "$(KEYMAP)" || (echo "Installe keymap-drawer dans le venv : make install-keymap-drawer" >&2; exit 1)
	@mkdir -p "$(CURDIR)/build"
	@if [ -f "$(KEYMAP_DRAWER_CFG)" ]; then \
		"$(KEYMAP)" --config "$(KEYMAP_DRAWER_CFG)" parse -z "$(CURDIR)/$<" -o "$@"; \
	else \
		"$(KEYMAP)" parse -z "$(CURDIR)/$<" -o "$@"; \
	fi

$(KEYMAP_SVG): $(KEYMAP_PARSED) $(KEYMAP_LAYOUT)
	@test -x "$(KEYMAP)" || (echo "Installe keymap-drawer dans le venv : make install-keymap-drawer" >&2; exit 1)
	@if [ -f "$(KEYMAP_DRAWER_CFG)" ]; then \
		"$(KEYMAP)" --config "$(KEYMAP_DRAWER_CFG)" draw -j "$(KEYMAP_LAYOUT)" "$(KEYMAP_PARSED)" -o "$@"; \
	else \
		"$(KEYMAP)" draw -j "$(KEYMAP_LAYOUT)" "$(KEYMAP_PARSED)" -o "$@"; \
	fi
	@echo "SVG : $(KEYMAP_SVG)"

keymap-images:
	@export ZMK_VENV="$(ZMK_VENV)" KEYMAP_JSON="$(KEYMAP_LAYOUT)" KEYMAP_LOCALE_MAP="$(KEYMAP_LOCALE_MAP)"; \
		"$(CURDIR)/support/gen-keymap-images.sh"

help:
	@echo "Bootstrap machine neuve : README.md + ./build-setup.sh (venv activé, Zephyr SDK à part)."
	@echo "Cibles :"
	@echo "  make / make all     — les 4 builds (Choc Pro BT) + firmware/*.uf2"
	@echo "  make left | right | reset-left | reset-right"
	@echo "  make reset          — les deux firmwares reset + firmware/"
	@echo "  make firmware       — copie les .uf2 construits vers firmware/"
	@echo "  make clean          — supprime build/ et firmware/"
	@echo "  make install-keymap-drawer — pip install keymap-drawer dans ZMK_VENV"
	@echo "  make keymap-drawer  — build/keymap.svg"
	@echo "  make keymap-images  — docs/images/sofle-layer*.svg (KEYMAP_LOCALE_MAP, défaut AZERTY FR macOS ISO)"
	@echo ""
	@echo "Board : $(BOARD_LEFT) / $(BOARD_RIGHT)   Shield : $(SHIELD_VIEW)"
	@echo "Kconfig utilisateur : config/sofle_choc_pro.conf"
	@echo "Changement de cible ou de KEYMAP_FILE : make clean ou PRISTINE=1"
	@echo "Variables : ZMK_APP=$(ZMK_APP)  ZMK_VENV=$(ZMK_VENV)  KEYMAP_FILE=$(KEYMAP_FILE)"
