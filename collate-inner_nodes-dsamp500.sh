#!/bin/bash

set -e
set -o nounset

export RUNMODE="${1}"
echo "RUNMODE ${RUNMODE}"

################################################################################
echo Log context
################################################################################
echo "date $(date)"
echo "hostname $(hostname)"
echo "job ${SLURM_JOB_ID:-none}"
echo "user ${USER}"

ln -s "${HOME}/scratch" "/mnt/scratch/${USER}/" || :

echo "num data files?"
find "${HOME}/scratch/hstrat-reconstruction-quality/${RUNMODE}" -name 'a=inner_nodes+*ext=.pqt' | grep "dsamp500" | wc -l

################################################################################
echo Do collation
################################################################################
singularity exec docker://ghcr.io/mmore500/hstrat-reconstruction-quality:4a037849287dc258e92354aa09b7b2c13441c4f5 /bin/bash << 'EOF'
set -e
set -o nounset
find "${HOME}/scratch/hstrat-reconstruction-quality/${RUNMODE}" -name 'a=inner_nodes*ext=.pqt' | grep 'dsamp500' | python3 -m joinem --progress "${HOME}/scratch/hstrat-reconstruction-quality/${RUNMODE}/a=inner_nodes+dsamp=true+ext=.pqt"
EOF

################################################################################
echo Finished
################################################################################
date
echo "SECONDS ${SECONDS}"
