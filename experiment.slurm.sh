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
#SBATCH --qos=scavenger

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

################################################################################
echo Install dependencies
################################################################################

module purge || :
module load GCCcore/12.2.0 Python/3.10.8 || :
export VENV="${HOME}/scratch/tmp/venv-{{revision}}"
mkdir -p "${HOME}/scratch/tmp/"
echo "VENV ${VENV}"
if [[ ! -d "${VENV}" ]]; then
  echo "Creating virtual environment"
  tmpdir="$(mktemp -d)"
  python3.10 -m venv "${tmpdir}"
  export PYTHONPATH="${tmpdir}/lib/site-packages"
  source "${tmpdir}/bin/activate"
  python3.10 -m pip install -r "https://raw.githubusercontent.com/mmore500/hstrat-reconstruction-quality/{{revision}}/requirements.txt"
  mv "${tmpdir}" "${VENV}"
fi
source "${VENV}/bin/activate"
# https://docs.icer.msu.edu/Using_Python_in_HPCC_with_virtualenv/
export PYTHONPATH="${VENV}/lib/site-packages"
echo "PYTHONPATH ${PYTHONPATH}"

################################################################################
echo Set up parameters and environment
################################################################################
export annotation_size_bits="{{annotation_size_bits}}"
export differentia_width_bits="{{differentia_width_bits}}"
export downsample="{{downsample}}"
export stratum_retention_algo="{{stratum_retention_algo}}"

export population_size="{{population_size}}"
export num_generations="{{num_generations}}"

export num_islands="{{num_islands}}"
export num_niches="{{num_niches}}"
export tournament_size="{{tournament_size}}"

export replicate="{{replicate}}"

NAME="evo=island${num_islands}-niche${num_niches}-ngen${num_generations}-popsize${population_size}-tournsize${tournament_size}+instrument=${stratum_retention_algo}-bits${annotation_size_bits}-diff${differentia_width_bits}-dsamp${downsample}"
echo "NAME ${NAME}"

WORKDIR="${HOME}/scratch/hstrat-reconstruction-quality/{{runmode}}/${NAME}"
echo "WORKDIR ${WORKDIR}"
mkdir -p "${WORKDIR}"

################################################################################
echo Run experiment
################################################################################
python3 -m papermill --cwd "${WORKDIR}" "https://raw.githubusercontent.com/mmore500/hstrat-reconstruction-quality/{{revision}}/reconstruction-quality-experiment.ipynb" "${WORKDIR}/${NAME}+replicate=${replicate}+ext=.ipynb"

################################################################################
echo Finished
################################################################################
date
echo "SECONDS ${SECONDS}"
