#!/bin/bash
# Installs a fresh Miniforge (conda + mamba, conda-forge only) in ~/miniforge3 and points your shell at it.
# Run once on the Borah LOGIN node (it downloads; nothing compiles):   bash install_miniforge.sh
#
# Your old conda is NOT deleted or changed. Only the "conda initialize" block in ~/.bashrc is swapped
# (a dated backup of ~/.bashrc is kept). The old install still works by full path if you ever need it.
set -eo pipefail   # no -u: conda activate scripts use unset variables
HERE=$(cd "$(dirname "$0")" && pwd)
source "$HERE/borah.sh"
PREFIX=${MINIFORGE:-$HOME/miniforge3}
VER=${MINIFORGE_VERSION:-26.7.2-1}     # pinned; bump on purpose, not by accident

if [ -x "$PREFIX/bin/conda" ]; then
  # A Miniforge is already there (on Borah, the one made for idaho-wrf-zarr, conda 26.7.2): keep it and
  # its envs instead of reinstalling.
  echo "Reusing the existing $PREFIX ($("$PREFIX/bin/conda" --version))"
  [ -f "$PREFIX/.condarc" ] && cp "$PREFIX/.condarc" "$PREFIX/.condarc.before-borah-python"
  # Only update conda itself if it is older than the pinned Miniforge's.
  if [ "$("$PREFIX/bin/conda" --version | awk '{print $2}' | cut -d. -f1)" -lt "${VER%%.*}" ]; then
    "$PREFIX/bin/conda" install -y -n base -c conda-forge --override-channels "conda>=${VER%%.*}" mamba
  fi
elif [ -e "$PREFIX" ]; then
  echo "$PREFIX exists but has no conda in it. Move it aside, or set MINIFORGE=/other/path."; exit 1
else
  tmp=$(mktemp -d)
  curl -fsSL -o "$tmp/miniforge.sh" \
    "https://github.com/conda-forge/miniforge/releases/download/$VER/Miniforge3-$VER-Linux-x86_64.sh"
  bash "$tmp/miniforge.sh" -b -p "$PREFIX"
  rm -rf "$tmp"
fi

# Settings live inside the new install, so they cannot leak into (or be broken by) the old one.
cat > "$PREFIX/.condarc" <<RC
channels: [conda-forge]
channel_priority: strict
auto_activate_base: false     # login shells stay clean; activate an env only when you need it
changeps1: true
pkgs_dirs: [$PREFIX/pkgs]
RC

# Every conda reads ~/.condarc, so the old one's settings (channels, env folders) would leak into the new
# install. Park it; the old conda keeps working without it, or copy it into the old install's own folder.
[ -f ~/.condarc ] && mv ~/.condarc ~/.condarc.before-miniforge && echo "Moved ~/.condarc to ~/.condarc.before-miniforge"

# Swap the shell hook: drop the old conda block, add the new one.
if [ -f ~/.bashrc ]; then
  cp ~/.bashrc ~/.bashrc.before-miniforge.$(date +%Y%m%d%H%M)
  sed -i '/^# >>> conda initialize >>>/,/^# <<< conda initialize <<</d' ~/.bashrc
  sed -i '/^# >>> mamba initialize >>>/,/^# <<< mamba initialize <<</d' ~/.bashrc
fi
"$PREFIX/bin/conda" init bash >/dev/null
# Borah's compute nodes have an old glibc; every solve must stay compatible with it (see borah.sh).
grep -q CONDA_OVERRIDE_GLIBC ~/.bashrc || cat >> ~/.bashrc <<RC
export CONDA_OVERRIDE_GLIBC=$CONDA_OVERRIDE_GLIBC   # Borah compute-node glibc; see borah-python/borah.sh
RC
"$PREFIX/bin/conda" --version
echo "Done. Log out and back in (or: source ~/.bashrc), then: bash $HERE/make_env.sh geo"
