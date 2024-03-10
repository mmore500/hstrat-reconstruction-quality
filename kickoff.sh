#!/bin/bash

set -e
set -u

runmode="${1}"
echo "runmode ${runmode}"

shift

QSPOOL="$(tmpfile="$(mktemp)"; curl -s https://raw.githubusercontent.com/mmore500/qspool/v0.5.0/qspool.py > "${tmpfile}"; echo "${tmpfile}")"
echo "QSPOOL ${QSPOOL}"

SBATCH_DIR="$(mktemp -d)"
echo "SBATCH_DIR ${SBATCH_DIR}"

for num_generations in 10000 100000; do
for scope in "export population_size=4096 downsample=500" "export population_size=65536 downsample=500" "export population_size=65536 downsample=8000"; do
for instrumentation in "export annotation_size_bits=32 differentia_width_bits=1" "export annotation_size_bits=64 differentia_width_bits=1" "export annotation_size_bits=256 differentia_width_bits=1" "export annotation_size_bits=256 differentia_width_bits=8"; do
for stratum_retention_algo in "new-steady" "new-tilted" "new-hybrid" "old-steady" "old-tilted"; do

for condition in "export num_islands=1 num_niches=1 tournament_size=2" "export num_islands=1 num_niches=1 tournament_size=1" "export num_islands=4 num_niches=2 tournament_size=2" "export num_islands=64 num_niches=8 tournament_size=2"; do

for replicate in {0..19}; do

eval $condition
eval $instrumentation
eval $scope

SBATCH_FILE="$(mktemp --tmpdir="${SBATCH_DIR}")"
echo "SBATCH_FILE ${SBATCH_FILE}"

cat experiment.slurm.sh | sed -e "s/{{annotation_size_bits}}/${annotation_size_bits}/g" | sed -e "s/{{differentia_width_bits}}/${differentia_width_bits}/g" | sed -e "s/{{downsample}}/${downsample}/g" | sed -e "s/{{stratum_retention_algo}}/${stratum_retention_algo}/g" | sed -e "s/{{replicate}}/${replicate}/g" | sed -e "s/{{num_islands}}/${num_islands}/g" | sed -e "s/{{num_niches}}/${num_niches}/g" | sed -e "s/{{population_size}}/${population_size}/g" | sed -e "s/{{num_generations}}/${num_generations}/g" | sed -e "s/{{runmode}}/${runmode}/g" | sed -e "s/{{tournament_size}}/${tournament_size}/g"  > "${SBATCH_FILE}"

head "${SBATCH_FILE}"

done

done
done
done
done
done

find "${SBATCH_DIR}" -maxdepth 1 -type f | python3  "${QSPOOL}"
