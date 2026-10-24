#!/bin/bash
# Create or update a conda env from envs/<name>.yml. Run on the Borah LOGIN node (downloads, no compiling).
#   bash make_env.sh geo             # build exactly what envs/geo-linux-64.lock lists (reproducible)
#   bash make_env.sh geo --resolve   # re-solve envs/geo.yml for current versions, test, then swap in
# --resolve builds "geo-new" first and runs check_env.py in it; only if that passes does it replace "geo"
# (the previous env is kept as "geo-old" until the next update). It rewrites the lockfiles: commit them.
set -eo pipefail   # no -u: conda activate scripts use unset variables
HERE=$(cd "$(dirname "$0")" && pwd)
source "$HERE/borah.sh"
NAME=${1:?usage: make_env.sh NAME [--resolve]}
MODE=${2:-lock}
YML=$HERE/envs/$NAME.yml
LOCK=$HERE/envs/$NAME-linux-64.lock      # conda packages, exact builds
PIPLOCK=$HERE/envs/$NAME-pip.txt         # pip-only packages, exact versions
command -v conda >/dev/null || { echo "conda not found: run install_miniforge.sh, then log out and in"; exit 1; }
[ -f "$YML" ] || { echo "no $YML"; exit 1; }
eval "$(conda shell.bash hook)"
conda deactivate 2>/dev/null || true
env_exists() { conda env list | awk '{print $1}' | grep -qx "$1"; }

if [ "$MODE" = --resolve ]; then
  env_exists $NAME-new && conda env remove -y -n $NAME-new
  mamba env create -y -n $NAME-new -f "$YML"
  conda activate $NAME-new
  python "$HERE/check_env.py" "$YML"
  { echo "# $NAME for Borah, solved $(date +%F) with CONDA_OVERRIDE_GLIBC=$CONDA_OVERRIDE_GLIBC"
    conda list --explicit --md5 | grep -v '^#'; } > "$LOCK"
  conda list | awk '$4 == "pypi" {print $1 "==" $2}' > "$PIPLOCK"
  conda deactivate
  if env_exists $NAME; then
    env_exists $NAME-old && conda env remove -y -n $NAME-old
    conda rename -n $NAME $NAME-old
    echo "The previous $NAME is kept as $NAME-old."
  fi
  conda rename -n $NAME-new $NAME
  echo "New $NAME is live."
  echo "Commit the new lockfiles: git add envs/$NAME-linux-64.lock envs/$NAME-pip.txt && git commit"
else
  [ -f "$LOCK" ] || { echo "no $LOCK yet: use --resolve"; exit 1; }
  env_exists $NAME && { echo "$NAME already exists. To rebuild it: conda env remove -n $NAME, then rerun"; exit 1; }
  mamba create -y -n $NAME --file "$LOCK"
  conda activate $NAME
  [ -s "$PIPLOCK" ] && pip install -q --no-deps -r "$PIPLOCK"
  python "$HERE/check_env.py" "$YML"
fi
conda activate $NAME
python -m ipykernel install --user --name $NAME --display-name "Python ($NAME)" >/dev/null 2>&1 || true
echo "Use it with: conda activate $NAME"
