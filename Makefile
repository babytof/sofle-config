# ZMK — deux claviers dans ce dépôt :
#   Sofle Choc Pro BT  — board sofle_choc_pro_left / _right + shield nice_view_disp
#                        (make / make all / left / right). UF2 : firmware/zmk-*.uf2
#   Corne MX BT        — board nice_nano_v2 + shield corne_left / corne_right
#                        (make corne-left / corne-right). UF2 : firmware/zmk-corne-*.uf2
#
# Les cibles Sofle et Corne sont isolées (dossiers build/, keymap, .conf, préfixe UF2).
#
# Prérequis : west dans le PATH (ex. source ~/.virtualenvs/zmk/bin/activate)
#
# Keymap Drawer : dans le même venv que ZMK (pas d’install globale).
#   make install-keymap-drawer   # une fois : pip install -r config/requirements-drawer.txt
#   make keymap-drawer           # SVG rapide (toutes les couches dans un fichier)
#   make keymap-images           # SVG + PNG par couche (PNG : rsvg-convert ou Inkscape)
#
# Keymap Drawer : configs dans support/ (d’origine Townk zmk-config, MIT).
KEYMAP_DRAWER_CFG ?= $(CURDIR)/support/keymap-config.yaml
# Légendes « sortie OS » pour keymap-images (CSV). Vide = désactiver (QWERTY US du YAML).
KEYMAP_LOCALE_MAP ?= $(CURDIR)/support/locale-maps/osx/fr_azerty_iso.csv
# Largeur des PNG générés à côté des SVG (gen-keymap-images.sh). KEYMAP_SKIP_PNG=1 pour désactiver les PNG.
KEYMAP_IMAGE_PNG_WIDTH ?=
# inkscape | rsvg (librsvg + aplatissement MDI) | auto (Inkscape si présent, sinon rsvg)
KEYMAP_PNG_RENDERER ?=
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
CHOC_FLAGS_COMMON = -DZMK_CONFIG="$(CURDIR)/config"
CHOC_FLAGS_KEYMAP = $(CHOC_FLAGS_COMMON) -DKEYMAP_FILE="$(KEYMAP_FILE)"

# KeyPeek (moitié centrale) : RPC Studio + raw HID — voir https://github.com/srwi/keypeek
SHIELD_LEFT  = $(SHIELD_VIEW) raw_hid_adapter
CHOC_FLAGS_LEFT  = $(CHOC_FLAGS_KEYMAP) -DSHIELD="$(SHIELD_LEFT)"
CHOC_FLAGS_RIGHT = $(CHOC_FLAGS_KEYMAP) -DSHIELD="$(SHIELD_VIEW)"
WEST_SNIPPET_LEFT = -S studio-rpc-usb-uart

# Corne MX BT — shield officiel ZMK (ne pas réutiliser KEYMAP_FILE / SHIELD_VIEW Sofle)
BOARD_CORNE      ?= nice_nano_v2
CORNE_KEYMAP     ?= $(CURDIR)/config/corne.keymap
CORNE_FLAGS      = -DZMK_CONFIG="$(CURDIR)/config" -DKEYMAP_FILE="$(CORNE_KEYMAP)"
SHIELD_CORNE_LEFT = corne_left raw_hid_adapter

# Environnement Python / Keymap Drawer (même venv que west)
ZMK_VENV         ?= $(HOME)/.virtualenvs/zmk
PIP_ZMK          := $(ZMK_VENV)/bin/pip
KEYMAP           := $(ZMK_VENV)/bin/keymap
KEYMAP_LAYOUT    := $(CURDIR)/config/sofle.json
KEYMAP_PARSED    := $(CURDIR)/build/keymap_drawer.yaml
KEYMAP_SVG       := $(CURDIR)/build/keymap.svg

.DEFAULT_GOAL := all

.PHONY: all left right reset-left reset-right reset clean firmware help \
	install-keymap-drawer keymap-drawer keymap-images keymap-blank-sheet \
	corne corne-left corne-right corne-reset-left corne-reset-right corne-reset

all:
	@echo "=== Build Sofle Choc Pro BT (left, right, reset-left, reset-right) ==="
	$(WEST) $(WEST_SNIPPET_LEFT) -d build/left -b $(BOARD_LEFT) -- $(CHOC_FLAGS_LEFT)
	$(WEST) -d build/right -b $(BOARD_RIGHT) -- $(CHOC_FLAGS_RIGHT)
	$(WEST) -d build/reset-left -b $(BOARD_LEFT) -- $(CHOC_FLAGS_COMMON) -DSHIELD=settings_reset
	$(WEST) -d build/reset-right -b $(BOARD_RIGHT) -- $(CHOC_FLAGS_COMMON) -DSHIELD=settings_reset
	@$(MAKE) --no-print-directory firmware
	@echo "UF2 copiés : $(CURDIR)/firmware/"
	@echo "=== Terminé ==="

left:
	@echo "=== Build LEFT ($(BOARD_LEFT) + $(SHIELD_VIEW)) ==="
	$(WEST) $(WEST_SNIPPET_LEFT) -d build/left -b $(BOARD_LEFT) -- $(CHOC_FLAGS_LEFT)
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
	@test -f build/corne-left/zephyr/zmk.uf2 && cp -f build/corne-left/zephyr/zmk.uf2 firmware/zmk-corne-left.uf2 || true
	@test -f build/corne-right/zephyr/zmk.uf2 && cp -f build/corne-right/zephyr/zmk.uf2 firmware/zmk-corne-right.uf2 || true
	@test -f build/corne-reset-left/zephyr/zmk.uf2 && cp -f build/corne-reset-left/zephyr/zmk.uf2 firmware/zmk-corne-reset-left.uf2 || true
	@test -f build/corne-reset-right/zephyr/zmk.uf2 && cp -f build/corne-reset-right/zephyr/zmk.uf2 firmware/zmk-corne-reset-right.uf2 || true

corne:
	@echo "=== Build Corne MX BT (left, right) ==="
	$(WEST) $(WEST_SNIPPET_LEFT) -d build/corne-left -b $(BOARD_CORNE) -- \
		$(CORNE_FLAGS) -DSHIELD="$(SHIELD_CORNE_LEFT)"
	$(WEST) -d build/corne-right -b $(BOARD_CORNE) -- \
		$(CORNE_FLAGS) -DSHIELD=corne_right
	@$(MAKE) --no-print-directory firmware
	@echo "UF2 : firmware/zmk-corne-left.uf2  firmware/zmk-corne-right.uf2"
	@echo "=== Terminé ==="

corne-left:
	@echo "=== Build Corne LEFT ($(BOARD_CORNE) + corne_left) ==="
	$(WEST) $(WEST_SNIPPET_LEFT) -d build/corne-left -b $(BOARD_CORNE) -- \
		$(CORNE_FLAGS) -DSHIELD="$(SHIELD_CORNE_LEFT)"
	@$(MAKE) --no-print-directory firmware
	@echo "UF2 : $(CURDIR)/firmware/zmk-corne-left.uf2  (copie de build/corne-left/zephyr/zmk.uf2)"

corne-right:
	@echo "=== Build Corne RIGHT ($(BOARD_CORNE) + corne_right) ==="
	$(WEST) -d build/corne-right -b $(BOARD_CORNE) -- \
		$(CORNE_FLAGS) -DSHIELD=corne_right
	@$(MAKE) --no-print-directory firmware
	@echo "UF2 : $(CURDIR)/firmware/zmk-corne-right.uf2  (copie de build/corne-right/zephyr/zmk.uf2)"

corne-reset-left:
	@echo "=== Build Corne RESET GAUCHE ($(BOARD_CORNE) + settings_reset) ==="
	$(WEST) -d build/corne-reset-left -b $(BOARD_CORNE) -- \
		-DZMK_CONFIG="$(CURDIR)/config" -DSHIELD=settings_reset
	@$(MAKE) --no-print-directory firmware
	@echo "UF2 : $(CURDIR)/firmware/zmk-corne-reset-left.uf2"

corne-reset-right:
	@echo "=== Build Corne RESET DROITE ($(BOARD_CORNE) + settings_reset) ==="
	$(WEST) -d build/corne-reset-right -b $(BOARD_CORNE) -- \
		-DZMK_CONFIG="$(CURDIR)/config" -DSHIELD=settings_reset
	@$(MAKE) --no-print-directory firmware
	@echo "UF2 : $(CURDIR)/firmware/zmk-corne-reset-right.uf2"

corne-reset:
	@echo "=== Build Corne RESET (gauche + droite) ==="
	$(WEST) -d build/corne-reset-left -b $(BOARD_CORNE) -- \
		-DZMK_CONFIG="$(CURDIR)/config" -DSHIELD=settings_reset
	$(WEST) -d build/corne-reset-right -b $(BOARD_CORNE) -- \
		-DZMK_CONFIG="$(CURDIR)/config" -DSHIELD=settings_reset
	@$(MAKE) --no-print-directory firmware
	@echo "UF2 copiés : $(CURDIR)/firmware/"
	@echo "=== Terminé ==="

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
	@export ZMK_VENV="$(ZMK_VENV)" KEYMAP_JSON="$(KEYMAP_LAYOUT)" KEYMAP_LOCALE_MAP="$(KEYMAP_LOCALE_MAP)" \
		KEYMAP_IMAGE_PNG_WIDTH="$(KEYMAP_IMAGE_PNG_WIDTH)" KEYMAP_SKIP_PNG="$(KEYMAP_SKIP_PNG)" \
		KEYMAP_PNG_RENDERER="$(KEYMAP_PNG_RENDERER)"; \
		"$(CURDIR)/support/gen-keymap-images.sh"

keymap-blank-sheet:
	@export ZMK_VENV="$(ZMK_VENV)" KEYMAP_JSON="$(KEYMAP_LAYOUT)"; \
		"$(CURDIR)/support/gen-blank-layer-sheet.sh"

help:
	@echo "Bootstrap machine neuve : README.md + ./build-setup.sh (venv activé, Zephyr SDK à part)."
	@echo "Cibles Sofle Choc Pro BT :"
	@echo "  make / make all     — les 4 builds Sofle + firmware/zmk-*.uf2"
	@echo "  make left | right | reset-left | reset-right"
	@echo "  make reset          — les deux firmwares reset Sofle + firmware/"
	@echo "Cibles Corne MX BT :"
	@echo "  make corne          — corne-left + corne-right"
	@echo "  make corne-left | corne-right | corne-reset-left | corne-reset-right"
	@echo "  make corne-reset    — les deux firmwares reset Corne"
	@echo "Commun :"
	@echo "  make firmware       — copie les .uf2 construits (Sofle et/ou Corne) vers firmware/"
	@echo "  make clean          — supprime build/ et firmware/ (Sofle et Corne)"
	@echo "  make install-keymap-drawer — pip install keymap-drawer dans ZMK_VENV"
	@echo "  make keymap-drawer  — build/keymap.svg (Sofle)"
	@echo "  make keymap-images  — docs/images/sofle-layer*.{svg,png} + build/out/zmk-sofle-layout-map.{svg,png}"
	@echo "  make keymap-blank-sheet — gabarit imprimable (3 couches vierges/page, docs/images/blank-layer-sheet.html)"
	@echo ""
	@echo "Sofle : $(BOARD_LEFT) / $(BOARD_RIGHT)   Shield gauche : $(SHIELD_LEFT)   droite : $(SHIELD_VIEW)"
	@echo "        Kconfig : config/sofle_choc_pro.conf   Keymap : $(KEYMAP_FILE)"
	@echo "Corne : $(BOARD_CORNE) + corne_left / corne_right"
	@echo "        Kconfig : config/corne.conf   Keymap : $(CORNE_KEYMAP)"
	@echo "Changement de cible ou de KEYMAP_FILE : make clean ou PRISTINE=1"
	@echo "Variables : ZMK_APP=$(ZMK_APP)  ZMK_VENV=$(ZMK_VENV)  KEYMAP_FILE=$(KEYMAP_FILE)"
