#!/bin/bash

set -e
set -u

cd "$(dirname "$0")"

./kickoff.sh "$1" "export population_size=1024 num_generations=10000"
