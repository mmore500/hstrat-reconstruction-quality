#!/bin/bash

set -e
set -u

cd "$(dirname "$0")"

./kickoff.sh "$1" "export population_size=65536 num_generations=100000"
