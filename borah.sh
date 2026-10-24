# Shared settings, sourced by the scripts here.
# Borah's compute nodes run an older glibc than the login node. conda checks the glibc of the machine it
# solves on, so an env made on the login node could pick builds that fail on compute nodes. Telling conda
# the compute-node glibc keeps every package runnable everywhere.
export CONDA_OVERRIDE_GLIBC=${CONDA_OVERRIDE_GLIBC:-2.17}
