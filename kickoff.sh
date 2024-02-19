#!/bin/bash

set -e
set -u

runmode="${1}"
echo "runmode ${runmode}"

shift

for annotation_size_bits in 64 256; do
for differentia_width_bits in 1; do
for stratum_retention_algo in "$@"; do

for condition in "export num_islands=1 num_niches=1 tournament_size=2" "export num_islands=1 num_niches=1 tournament_size=1" "export num_islands=4 num_niches=2 tournament_size=2" "export num_islands=64 num_niches=8 tournament_size=2"; do
for scale in "export population_size=1024 num_generations=10000" "export population_size=65536 num_generations=100000"; do


for replicate in {0..19}; do

eval $condition
eval $scale

cat experiment.slurm.sh | sed -e "s/{{annotation_size_bits}}/${annotation_size_bits}/g" | sed -e "s/{{differentia_width_bits}}/${differentia_width_bits}/g" | sed -e "s/{{stratum_retention_algo}}/${stratum_retention_algo}/g" | sed -e "s/{{replicate}}/${replicate}/g" | sed -e "s/{{num_islands}}/${num_islands}/g" | sed -e "s/{{num_niches}}/${num_niches}/g" | sed -e "s/{{population_size}}/${population_size}/g" | sed -e "s/{{num_generations}}/${num_generations}/g" | sed -e "s/{{runmode}}/${runmode}/g" | sed -e "s/{{tournament_size}}/${tournament_size}/g" > /tmp/slurm.sh
head /tmp/slurm.sh
sbatch /tmp/slurm.sh

done
done

done
done
done
done
