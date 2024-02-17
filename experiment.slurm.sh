#!/bin/bash -login
########## Define Resources Needed with SBATCH Lines ##########
#SBATCH --time=4:00:00
#SBATCH --job-name hstrat-quality
#SBATCH --output="/mnt/home/%u/joblog/id=%j+ext.txt"
#SBATCH --mem=4G
#SBATCH --ntasks=1
#SBATCH --cpus-per-task=1
#SBATCH --mail-type=FAIL
# No --mail-user, the default value is the submitting user
#SBATCH --exclude=csn-002,amr-250
# Job may be requeued after node failure.
#SBATCH --requeue

set -e
set -o nounset
shopt -s globstar

# log context
echo "date $(date)"
echo "hostname $(hostname)"
echo "job ${SLURM_JOB_ID:-none}"
echo "user ${USER}"

ln -s "${HOME}/scratch" "/mnt/scratch/${USER}/" || :
mkdir -p "${HOME}/joblog" || :

if [[ -z ${SLURM_JOB_ID:-} ]]; then
  export JOBLOG_PATH="/dev/null"
else
  export JOBLOG_PATH="$(ls "${HOME}/joblog/"*"id=${SLURM_JOB_ID}+"*)"
fi
echo "JOBLOG_PATH ${JOBLOG_PATH}"

mkdir -p "${HOME}/joblatest" || :
ln -srfT "${JOBLOG_PATH}" "${HOME}/joblatest/start" || :

export JOBSCRIPT_PATH="$0"
echo "JOBSCRIPT_PATH ${JOBSCRIPT_PATH}"
readlink -f "${JOBSCRIPT_PATH}"
export JOBSCRIPT_PATH="$(readlink -f "${JOBSCRIPT_PATH}")"
echo "JOBSCRIPT_PATH ${JOBSCRIPT_PATH}"

mkdir -p "${HOME}/jobscript" || :
cp "${JOBSCRIPT_PATH}" "${HOME}/jobscript/id=${SLURM_JOB_ID:-none}+ext=.slurm.sh" || :

mkdir -p "${HOME}/jobcont" || :
export JOBCONT_PATH="${HOME}/jobcont/id=${SLURM_JOB_ID:-none}+ext=.slurm.sh"
echo "JOBCONT_PATH ${JOBCONT_PATH}"
touch "${JOBCONT_PATH}"

err() {
    echo "Error occurred:"
    awk 'NR>L-4 && NR<L+4 { printf "%-5d%3s%s\n",NR,(NR==L?">>>":""),$0 }' L="$1" "$0"
    ln -srfT "${JOBLOG_PATH}" "${HOME}/joblatest/fail" || :
}
trap 'err $LINENO' ERR

# Capture the current EXIT trap (if any).
existing_exit_trap=$(trap -p EXIT)
on_exit() {
  if [[ $? -eq 0 ]]; then
    ln -srfT "${JOBLOG_PATH}" "${HOME}/joblatest/succeed" || :
  fi
  ln -srfT "${JOBLOG_PATH}" "${HOME}/joblatest/finish" || :

  # Execute the existing EXIT trap commands (if any).
  eval "${existing_exit_trap#trap -- }"

}
trap on_exit EXIT

module purge || :
module load GCCcore/12.2.0 Python/3.10.8 || :
export VENV="$(mktemp -d)"
python3 -m venv "${VENV}"
source "${VENV}/bin/activate"

################################################################################
# Install dependencies
################################################################################
python3 -m pip install "papermill==2.5.0" "ipykernel==6.23.3" "jupyter==1.0.0" "notebook==6.4.10" "ipywidgets==7.8.1"

export annotation_size_bits="{{annotation_size_bits}}"
export differentia_width_bits="{{differentia_width_bits}}"
export stratum_retention_algo="{{stratum_retention_algo}}"

export population_size="{{population_size}}"
export num_generations="{{num_generations}}"

export num_islands="{{num_islands}}"
export num_niches="{{num_niches}}"
export tournament_size="{{tournament_size}}"

export replicate="{{replicate}}"

NAME="evo=island${num_islands}-niche${num_niches}-ngen${num_generations}-popsize${population_size}-tournsize${tournament_size}+instrument=${stratum_retention_algo}-new-bits${annotation_size_bits}-diff${differentia_width_bits}"
echo "NAME ${NAME}"

mkdir -p "${HOME}/scratch/hstrat-reconstruction-quality/{{runmode}}/${NAME}/"

python3 -m papermill "https://raw.githubusercontent.com/mmore500/hstrat-reconstruction-quality/fb4405c0ee829c547579d72a41cfeefe43fa1d0a/reconstruction-quality-experiment.ipynb" "${HOME}/scratch/hstrat-reconstruction-quality/{{runmode}}/${NAME}/${NAME}-${replicate}.ipynb"
