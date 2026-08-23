# Corne MX Bluetooth — instructions (même dépôt)

Ne pas créer un second dépôt. Ajouter une **cible hardware Corne** ici, à côté du Sofle Choc Pro BT.

Le keymap 42 touches vit déjà dans [`config/layout/corne_vial_layout.dtsi`](config/layout/corne_vial_layout.dtsi) (port de `vial-qmk/keyboards/crkbd/keymaps/vial/keymap.c`). Les UF2 Sofle ne se flashent **pas** sur le SuperMini.

## Matériel

| | |
|---|---|
| Kit | PandaKB Corne V3 MX, Kit3 wireless |
| MCU | SuperMini nRF52840 (= `nice_nano_v2` dans ZMK) |
| PCB | Corne V3 / crkbd, pinout Pro Micro |
| Écran | OLED 0,91″ SSD1306 128×32 (I2C `0x3c`) — **pas** Nice!View |
| Split | BLE uniquement (ne pas souder le jack TRRS) |

Cible West :

```text
board  : nice_nano_v2
shield : corne_left   /   corne_right
```

Le shield officiel est déjà dans `zmk/app/boards/shields/corne/` (ZMK v0.3). OLED et matrice y sont définis.

## Ne pas toucher

- `config/boards/arm/sofle_choc_pro/`
- `config/boards/shields/nice_view_disp/`
- les cibles Makefile `left` / `right` / `all` (Sofle)
- `config/sofle.keymap` et la macro `SOFLE60`
- `config/west.yml` (sauf besoin nouveau module)

`make all` reste le build Sofle.

## Fichiers à créer

| Fichier | Rôle |
|---|---|
| `config/corne.keymap` | 42 bindings, layout officiel 3×6+3 |
| `config/corne.conf` | OLED, RGB underglow, Studio (gauche) |
| `config/layout/corne_42_layout.dtsi` | extrait de `corne_vial_layout.dtsi` **sans** `SOFLE60` |

Optionnel plus tard : `config/corne.json` + schéma keymap-drawer, docs dédiées.

## Keymap 42 touches

Le shield `corne` attend **42** cellules, dans cet ordre (indices combo entre parenthèses) :

```text
 0  1  2  3  4  5        6  7  8  9 10 11     rangée Q
12 13 14 15 16 17       18 19 20 21 22 23     homerow  (J=19 K=20 L=21)
24 25 26 27 28 29       30 31 32 33 34 35     rangée Z
         36 37 38       39 40 41              pouces
```

Modèle : `zmk/app/boards/shields/corne/corne.keymap` (pas de macro, 4 lignes de bindings).

Reprends les bindings **non-`&none`** de `corne_vial_layout.dtsi` :

| Sofle (`SOFLE60`) | Corne 42 |
|---|---|
| rangée chiffres + HYP + pouces externes (`&none`) | supprimer |
| rangées lettres / home / bas | garder, même ordre |
| pouces `LAlt LGui Sym/Enter \| Nav/Space RGui RAlt` | positions 36–41 |

Comportements à **copier** (pas réinventer) :

- `&cmt` / `&clt` — hold-tap 180 ms
- couches `L_BASE` … `L_ADJ` (0–5)
- Adjust : RGB, média, `&bootloader`, profils BT, `&out OUT_TOG`

### Combo J+K+L → Enter

Aujourd’hui : `key-positions = <31 32 33>` (indices **Sofle**).

Sur Corne : **`key-positions = <19 20 21>`**.

## `config/corne.conf`

Le shield commente déjà l’OLED et l’underglow (`zmk/app/boards/shields/corne/corne.conf`). Les activer **ici** :

```kconfig
CONFIG_ZMK_BLE=y
CONFIG_ZMK_SPLIT=y

CONFIG_ZMK_DISPLAY=y
CONFIG_SSD1306=y

CONFIG_ZMK_RGB_UNDERGLOW=y
CONFIG_WS2812_STRIP=y

CONFIG_ZMK_STUDIO=y
```

Notes :

- `Kconfig.defconfig` du shield active I2C + SSD1306 dès que `CONFIG_ZMK_DISPLAY=y`.
- RGB **per-key** : pas dans le shield officiel (`TODO` dans `corne.dtsi`). Premier objectif = underglow (27 LED / moitié, broche D3). Vérifier le compte / l’ordre une fois flashé.
- Ne pas inclure `nice_view_disp` ni `CONFIG_ZMK_MOUSE=y` (sauf si on réactive la souris plus tard).

## Makefile

Ajouter des cibles **séparées**, dossiers `build/` distincts, UF2 préfixés `corne-` :

```make
BOARD_CORNE      ?= nice_nano_v2
CORNE_KEYMAP     ?= $(CURDIR)/config/corne.keymap
CORNE_FLAGS      = -DZMK_CONFIG="$(CURDIR)/config" -DKEYMAP_FILE="$(CORNE_KEYMAP)"

corne-left:
	$(WEST) -S studio-rpc-usb-uart -d build/corne-left -b $(BOARD_CORNE) -- \
		$(CORNE_FLAGS) -DSHIELD="corne_left raw_hid_adapter"

corne-right:
	$(WEST) -d build/corne-right -b $(BOARD_CORNE) -- \
		$(CORNE_FLAGS) -DSHIELD=corne_right

corne-reset-left:
	$(WEST) -d build/corne-reset-left -b $(BOARD_CORNE) -- \
		-DZMK_CONFIG="$(CURDIR)/config" -DSHIELD=settings_reset

corne-reset-right:
	$(WEST) -d build/corne-reset-right -b $(BOARD_CORNE) -- \
		-DZMK_CONFIG="$(CURDIR)/config" -DSHIELD=settings_reset
```

Copier les UF2 vers `firmware/` :

- `firmware/zmk-corne-left.uf2`
- `firmware/zmk-corne-right.uf2`
- `firmware/zmk-corne-reset-left.uf2`
- `firmware/zmk-corne-reset-right.uf2`

`make firmware` Sofle ne doit pas écraser ces fichiers. `make help` : documenter les 4 cibles Corne.

KeyPeek / Studio : snippet + `raw_hid_adapter` **uniquement à gauche** (central BLE), comme le Sofle.

## Build / flash

Prérequis identiques au Sofle : venv `~/.virtualenvs/zmk`, Zephyr SDK, `./build-setup.sh` déjà faits.

```bash
source ~/.virtualenvs/zmk/bin/activate
make corne-left corne-right
# en cas de settings BLE corrompus :
make corne-reset-left corne-reset-right
```

Flash (double-tap reset → volume UF2, souvent `NICENANO`) :

1. Reset des deux moitiés si besoin, puis firmware left / right.
2. Batteries ON, un reset simultané pour l’appairage inter-moitiés.
3. Appairer l’hôte au nom **Corne** (`ZMK_KEYBOARD_NAME` du shield gauche).

Changement de board / shield : `PRISTINE=1` ou `make clean` (attention : `clean` efface aussi les builds Sofle).

## Contrôles

- [ ] `make left` Sofle inchangé
- [ ] 42 touches, même ordre que le Vial filaire / le Sofle 42
- [ ] combo J+K+L → Enter
- [ ] hold-tap 180 ms (homerow + pouces layer-tap)
- [ ] OLED des deux côtés
- [ ] split BLE sans TRRS
- [ ] profils BT + bootloader sur Adjust
- [ ] underglow (si LED soudées)

## Hors scope (v1)

- nouveau dépôt `corne-config`
- firmware dans `/Users/tof/dev/keyboard/corne` (hardware crkbd + QMK)
- RGB per-key, couche souris, Nice!View
- QMK/Vial sur nRF52840
