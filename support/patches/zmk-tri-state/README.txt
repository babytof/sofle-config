Patches pour modules/zmk-tri-state (après chaque « west update », appliqués par ./build-setup.sh).

Index général des patches West : ../README.txt

Fichiers : *.patch triés par nom (ex. 0001-fix-foo.patch, 0002-…).

Générer un patch depuis un clone du module (hors commit, diff simple) :
  cd modules/zmk-tri-state
  git diff > ../../support/patches/zmk-tri-state/0001-ma-modif.patch

Ou depuis un commit déjà fait dans le module :
  cd modules/zmk-tri-state
  git format-patch -1 HEAD --stdout > ../../support/patches/zmk-tri-state/0001-ma-modif.patch

Alternative « git am » (série format-patch, un fichier par commit) :
  cd modules/zmk-tri-state
  git reset --hard HEAD && git clean -fd
  git am ../../support/patches/zmk-tri-state/*.patch

Le script build-setup.sh utilise « git apply » (pas de commit local) pour rester idempotent :
  reset --hard + clean, puis git apply pour chaque .patch dans l’ordre.

Si le dépôt amont change les mêmes lignes, le patch peut échouer : régénère-le ou fige
revision: <sha> dans config/west.yml pour zmk-tri-state.
