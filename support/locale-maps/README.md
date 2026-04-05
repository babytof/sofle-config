# Fichiers de locale (légendes Keymap Drawer)

Chaque fichier `*.csv` décrit **ce qui s’affiche** pour une touche ZMK donnée (proposition B : sortie avec le layout système cible).

## Colonnes

| Colonne | Description |
|--------|-------------|
| `zmk_key` | Nom de touche ZMK / Keymap Drawer (`Q`, `N1`, `SEMI`, `BSPC`, …). Pas de `&kp`. |
| `tap` | Caractère ou libellé pour **tap** (souvent minuscule pour les lettres). |
| `shift` | Caractère ou libellé pour **Shift+tap**. Peut être vide (champ vide après la dernière virgule) si non applicable. |

- Séparateur : **virgule**.
- Champs contenant une virgule ou des guillemets : entourer de `"` et doubler les `"` internes.
- Encodage : **UTF-8**.

## Arborescence

- `osx/` — correspondance mesurée ou tabulée pour **macOS** + source de saisie choisie.
- `windows/` — idem **Windows**.
- `linux/` — idem **Linux** (X11/Wayland selon ton cas).

Les trois `us_qwerty.csv` fournis sont **identiques** (QWERTY US de référence). Pour le français, copie vers `fr_azerty.csv` (ou autre nom) et adapte `tap` / `shift`.

Les lignes à **un seul glyphe** (ex. `@`, `(`) ont souvent `tap` et `shift` identiques dans ce fichier de base ; tu peux les ajuster pour ton OS.

## Prochaine étape (non branchée encore)

Un script pourra fusionner ce CSV avec `keymap-config.yaml` avant `keymap parse` / `draw`. Variable d’environnement du type `KEYMAP_LOCALE=osx/fr_azerty`.
