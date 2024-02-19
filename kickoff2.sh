#!/bin/bash

set -e
set -u

cd "$(dirname "$0")"

./kickoff.sh "$1" "new-steady" "new-tilted" "new-hybrid"
