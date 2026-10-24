# Python on Borah

Miniforge in `~/miniforge3` plus one pinned, general-purpose analysis environment (`geo`) for pre- and
post-processing of the models in the project repos. The old `~/miniconda3` (conda 4.10, Python 3.9) is
left alone.

The rules that keep it from going brittle again:

1. **Nothing goes into `base`.** Base only runs conda itself. Everything else lives in named envs.
2. **Envs are rebuilt from files, never edited by hand.** To add a package, add it to `envs/geo.yml` and
   run `make_env.sh geo --resolve`. The lockfiles record exactly what got installed, so the same env can be
   rebuilt anywhere, any time.
3. **Every solve targets the compute nodes' old glibc** (`CONDA_OVERRIDE_GLIBC=2.17`, set in `borah.sh` and
   in `~/.bashrc`). Without it, an env made on the login node can work there and fail in Slurm jobs.
4. **No env is active when you log in** (`auto_activate_base: false`), so `module load` builds and model
   `env.sh` files see a clean shell.

## Install (once, Borah login node, about 15 minutes)

```bash
cd ~ && git clone https://github.com/LejoFlores/borah-python && cd borah-python
bash install_miniforge.sh          # reuses ~/miniforge3 (or installs it), swaps the conda block in ~/.bashrc
exit                               # log out and back in so the new conda is on PATH
cd ~/borah-python
bash make_env.sh geo               # builds the pinned env from the lockfile and tests it
srun -p short -n1 -t 10 bash -c 'eval "$(conda shell.bash hook)"; conda activate geo; python check_env.py'
```

The last line repeats the test on a compute node. Both should end with `OK: ... NetCDF write/read works`.

Then, whenever you need it: `conda activate geo`. In Jupyter, pick the "Python (geo)" kernel.

## What `geo` has

numpy, scipy, pandas, xarray, dask, netCDF4, h5netcdf, h5py, pyhdf, zarr 3, eccodes, cfgrib, wgrib2,
wrf-python, xwrf, MetPy, GDAL, rasterio, rioxarray, pyproj, geopandas, cartopy, pysheds, statsmodels,
scikit-learn, scikit-image, matplotlib, s3fs, gcsfs, cdsapi, earthaccess, pftools 1.3.15 (ParFlow 3.15),
NCO, CDO, JupyterLab. It covers the Python in schnaps-borah (`setup/`, `post/`, including the
`schnaps-forcing` uses), parflow-borah `code/`, erf-borah `setup/`, idaho-summer-precip, idaho-wrf-zarr and
wy2026-idaho-snow-drought. See `envs/geo.yml`.

## Envs that stay separate

These have their own pinned requirements; build them from their repos with the new conda:

| Env | How |
| --- | --- |
| `wolverine-oggm` | `cd ~/wolverine-oggm && mamba env create -f environment.yml` (OGGM pins Python 3.11) |
| `wrf-zarr` | `cd ~/idaho-wrf-zarr && mamba env create -f environment.yml` (its `slurm/env.sh` finds `~/miniforge3` on its own); or skip it and run with `WRF_ZARR_ENV=geo` |
| `schnaps-domains` | `bash setup/make_env.sh` in schnaps-borah, in a dev-session (it compiles HORAYZON) |
| ParFlow's venv | unchanged: `parflow-borah/borah/fetch_sources.sh` makes its own uv venv |

## In Slurm jobs

```bash
eval "$(conda shell.bash hook)"   # or: source ~/miniforge3/etc/profile.d/conda.sh
conda activate geo
python my_postprocessing.py
```

If the job also sources a model `env.sh` that runs `module purge` (WRF, ERF, SCHNAPS), source that
**first** and activate conda **after** it.

## Building models: keep conda out of the way

Compilers must see the modules, not conda's copies of netCDF, HDF5, MPI or CMake. Since nothing is active at
login, just don't activate an env in the shell you build in. If one is active: `conda deactivate` (repeat
until the prompt shows no env name), then `source build/env_gcc12.sh` or the model's `env.sh`.

## Updating (every few months, or when a package is needed)

```bash
cd ~/borah-python && git pull
# optional: add packages to envs/geo.yml
bash make_env.sh geo --resolve
```

This builds `geo-new`, tests it, and only then swaps it in as `geo`. The previous env stays as `geo-old`,
so going back is `conda env remove -n geo && conda rename -n geo-old geo`. Commit the two changed
lockfiles (`envs/geo-linux-64.lock`, `envs/geo-pip.txt`) so the repo always describes what is on Borah.

To update conda itself: `conda update -n base conda mamba` (safe: the glibc setting applies to base too).

If `~/miniforge3` already exists (on Borah it does: it holds the `wrf-zarr` env), the script keeps it and
its envs, and updates conda only if it is older than 26.

## The old install

`install_miniforge.sh` does not touch it. It removes only the `conda initialize` block from `~/.bashrc`
(a dated copy of the old `.bashrc` is kept as `~/.bashrc.before-miniforge.*`) and parks `~/.condarc` as
`~/.condarc.before-miniforge`. Old envs (`aws_s3`, `schnaps-forcing`, `wrf-drought`) still run by full path, e.g.
`~/miniconda3/envs/wrf-drought/bin/python`, or rebuild them in the new conda. Once
nothing needs them, the old folder can be deleted to free space.

## Files

| File | What it does |
| --- | --- |
| `install_miniforge.sh` | Installs Miniforge 26.7.2-1 in `~/miniforge3`, or updates the one there (conda-forge only, no base auto-activation) |
| `make_env.sh NAME [--resolve]` | Builds an env from its lockfile, or re-solves the `.yml`, tests it and swaps it in |
| `check_env.py` | Imports every package of an env and writes/reads a NetCDF file |
| `borah.sh` | Borah settings (compute-node glibc) |
| `envs/geo.yml` | What `geo` should contain (edit this) |
| `envs/geo-linux-64.lock`, `envs/geo-pip.txt` | What `geo` does contain, exact builds (generated) |
