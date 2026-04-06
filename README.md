# Configuration ZMK — Sofle Choc Pro BT

> **À propos de ce dépôt** — Configuration issue d’un fork de [Townk/zmk-config](https://github.com/Townk/zmk-config), avec adaptation du mapping **Lily58** vers un **Sofle Choc Pro Bluetooth**, pour une utilisation **AZERTY / ISO français** sous **macOS**.

Keymap, board et manifest **West** pour le firmware Townk (ZMK `mousemove-molock`) + module `zmk-tri-state`. Les arborescences **zephyr/**, **zmk/** et **modules/** sont ignorées par Git (`.gitignore`) : elles sont recréées par West et éventuellement modifiées par des **patches versionnés** dans `support/patches/`.

## Nouvel ordinateur (ordre recommandé)

### 1. Outils système

- **Git**
- **CMake** et **Ninja** (ex. macOS : `brew install cmake ninja`)
- **Python 3** (3.10 ou plus récent, selon ta stack Zephyr)

### 2. Zephyr SDK (hors script)

Le toolchain n’est **pas** installé par `./build-setup.sh`.

1. Télécharger une archive **Zephyr SDK 0.16.x** adaptée à ton OS depuis [sdk-ng — Releases](https://github.com/zephyrproject-rtos/sdk-ng/releases) (ex. `zephyr-sdk-0.16.5_macos-aarch64.tar.xz`).
2. Extraire l’archive (ex. sous `$HOME`).
3. Dans le répertoire extrait, exécuter **`./setup.sh`** (souvent avec **`-c`** pour enregistrer le paquet CMake, voir la doc du SDK).

Zephyr 3.5 attend un SDK **≥ 0.16** (`find_package(Zephyr-sdk 0.16)`). Après `setup.sh`, CMake retrouve en général le SDK via le profil utilisateur ; sinon définir **`ZEPHYR_SDK_INSTALL_DIR`**.

### 3. Cloner ce dépôt

```bash
git clone <url-de-ce-depot> sofle-config
cd sofle-config
```

### 4. Virtualenv Python (obligatoire pour `build-setup.sh`)

Le script exige une variable **`VIRTUAL_ENV`** non vide (venv activé).

```bash
python3 -m venv ~/.virtualenvs/zmk
source ~/.virtualenvs/zmk/bin/activate
```

(Autre chemin possible : tant que `which python` pointe dans le venv après `source …/activate`.)

### 5. Setup West + Python + patches

```bash
./build-setup.sh
```

Fait notamment : `west init -l config` si besoin, **`west update`**, application des fichiers **`support/patches/{zephyr,zmk,zmk-tri-state}/*.patch`** (s’il y en a), puis `pip install` pour Zephyr et Keymap Drawer.

### 6. Build firmware / diagrammes

```bash
make left          # ou make all, make right, …
make keymap-images # SVG dans docs/images/
```

Variable utile du **Makefile** : **`ZMK_VENV`** (défaut `$(HOME)/.virtualenvs/zmk`) pour pointer vers ton venv si différent.

## Patches sur zephyr / zmk / zmk-tri-state

Toute modification locale dans ces clones **sans** patch versionné sera perdue au prochain clone ou `west update` propre.

- Index : **`support/patches/README.txt`**
- Un **`README.txt`** par sous-dossier explique comment générer les `.patch` (`git diff`, `git format-patch`, alternative `git am`).

## Références

- Manifest West : **`config/west.yml`**
- `make help` — cibles du Makefile
