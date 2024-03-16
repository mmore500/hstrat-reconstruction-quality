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
find "${HOME}/scratch/hstrat-reconstruction-quality/${RUNMODE}" -name 'a=inner_nodes+*ext=.pqt' | wc -l

################################################################################
echo Do collation
################################################################################
singularity exec docker://ghcr.io/mmore500/hstrat-reconstruction-quality:794ab4f9376502f9c6b057d0983af6d840f437de /bin/bash << 'EOF'
set -e
set -o nounset
find "${HOME}/scratch/hstrat-reconstruction-quality/${RUNMODE}" -name 'a=inner_nodes*ext=.pqt' | python3 -m joinem --progress "${HOME}/scratch/hstrat-reconstruction-quality/${RUNMODE}/a=inner_nodes+ext=.pqt"
EOF

################################################################################
echo Finished
################################################################################
date
echo "SECONDS ${SECONDS}"
