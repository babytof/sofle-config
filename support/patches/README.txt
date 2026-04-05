Patches Git pour les dépôts West (zephyr/, zmk/, modules/zmk-tri-state/), versionnés dans CE dépôt.

Après chaque « west update », ./build-setup.sh réinitialise chaque module concerné
(git reset --hard, git clean -fd) puis applique les *.patch du sous-dossier correspondant,
dans l’ordre lexicographique (0001-…, 0002-…), via « git apply ».

Arborescence :
  support/patches/zephyr/*.patch      → appliqués dans zephyr/
  support/patches/zmk/*.patch         → appliqués dans zmk/
  support/patches/zmk-tri-state/*.patch → appliqués dans modules/zmk-tri-state/

Sous-dossiers : un README.txt chacun (chemins relatifs pour git diff / format-patch).

Sans aucun .patch dans un dossier, le module West n’est pas modifié par le script.

Pour une machine neuve : suivre README.md à la racine du dépôt (clone → venv → SDK → build-setup.sh).
