#!/bin/bash

set -e
set -u

cd "$(dirname "$0")"

./kickoff.sh "$1" "old-steady" "old-tilted"
