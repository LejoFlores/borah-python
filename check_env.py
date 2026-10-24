"""Smoke test for an env: import every package in envs/<name>.yml and write/read a small NetCDF file.
Run it on a compute node too, since that is where an incompatible build would fail:
    srun -p short -n1 -t 10 python check_env.py envs/geo.yml
"""
import importlib
import os
import platform
import re
import sys
import tempfile

# conda package name -> import name, where they differ; None = command-line tool, checked on PATH
IMPORT_NAME = {
    "python": None, "pip": None, "netcdf4": "netCDF4", "python-eccodes": "eccodes", "scikit-learn": "sklearn",
    "scikit-image": "skimage", "pyyaml": "yaml", "pillow": "PIL", "gdal": "osgeo.gdal", "wrf-python": "wrf",
    "pftools": "parflow", "jupyterlab": "jupyterlab", "pytables": "tables", "nco": None, "cdo": None,
    "wgrib2": None, "setuptools": None,
}
TOOLS = {"nco": "ncks", "cdo": "cdo", "wgrib2": "wgrib2"}


def packages(yml):
    names, deps = [], False
    for line in open(yml):
        deps = deps or line.startswith("dependencies:")
        if not deps:
            continue
        m = re.match(r"\s+- ([A-Za-z0-9_.-]+)", line.split("#")[0])
        if m and m.group(1) not in ("pip:", "-e"):
            names.append(m.group(1))
    return names


def main(yml):
    print(f"python {sys.version.split()[0]} on {platform.node()}, glibc {platform.libc_ver()[1]}")
    bad = []
    for pkg in packages(yml):
        name = IMPORT_NAME.get(pkg, pkg.replace("-", "_"))
        if name is None:
            tool = TOOLS.get(pkg)
            if tool and not os.access(os.path.join(sys.prefix, "bin", tool), os.X_OK):
                bad.append(f"{pkg}: {tool} missing from {sys.prefix}/bin")
            continue
        try:
            importlib.import_module(name)
        except Exception as e:  # noqa: BLE001
            bad.append(f"{pkg}: {type(e).__name__}: {e}")
    import netCDF4
    import numpy as np
    with tempfile.TemporaryDirectory() as d:
        f = os.path.join(d, "t.nc")
        with netCDF4.Dataset(f, "w") as nc:
            nc.createDimension("x", 3)
            nc.createVariable("v", "f4", ("x",), zlib=True)[:] = np.arange(3)
        with netCDF4.Dataset(f) as nc:
            assert list(nc["v"][:]) == [0, 1, 2]
    if bad:
        print("FAILED:\n  " + "\n  ".join(bad))
        sys.exit(1)
    print(f"OK: {len(packages(yml))} packages import, NetCDF write/read works")


if __name__ == "__main__":
    main(sys.argv[1] if len(sys.argv) > 1 else os.path.join(os.path.dirname(__file__), "envs", "geo.yml"))
