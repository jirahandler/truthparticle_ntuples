#!/usr/bin/env bash

# This script should not be sourced, we don't need anything in here to
# propigate to the surrounding environment.
if [[ $- == *i* ]] ; then
    echo "Don't source me!" >&2
    return 1
else
  # set the shell to exit if there's an error (-e), and to error if
  # there's an unset variable (-u)
    set -eu
fi

BREAK="----------------------------------------------"
###################################################
# Add some mode switches
###################################################
declare -A SCRIPTS_BY_MODE=(
    [main]=extractinfo
)
declare -A INPUTS_BY_MODE=(
    [main]=samples.txt
)
###################################################
# CLI
###################################################
_usage() {
    echo "usage: ${0##*/} [-h] [options] MODE"
}
_help() {
    _usage
    cat <<EOF

    Submit dumper jobs to the grid! This script will ask you to commit your changes.
    Specify a running MODE (below) and then optionally overwrite the mode's defaults
    using the optional flags. You are encoraged to use the -t argument to tag your
    submission.

Options:
 -s script : Executable to be run (e.g. dump-single-btag)
 -i file   : File listing input samples, will override the default list
 -d        : Dry run, don't submit anything or make a tarball, but build the
             submit directory
 -e        : external files to be added to grid job

Modes:
$(for key in "${!CONFIGS_BY_MODE[@]}"; do
    echo -e " $key   \t=> ${SCRIPTS_BY_MODE[$key]} -c ${CONFIGS_BY_MODE[$key]}";
done)

EOF
}

# defaults
SCRIPT=""; INPUT_DATASETS=""; EXT_FILES="";
DRYRUN="";
while getopts ":hs:i:t:e:fmad" opt $@;
do
    case $opt in
        h) _help; exit 1;;
        s) SCRIPT=${OPTARG};;
        i) INPUT_DATASETS=${OPTARG};;
        e) EXT_FILES=${OPTARG};;
        d) DRYRUN="echo DRY RUNNING: " ;;
        # handle errors
        \?) _usage; echo "Unknown option: -$OPTARG" >&2; exit 1;;
        :)  _usage; echo "Missing argument for -$OPTARG" >&2; exit 1;;
        *)  _usage; echo "Unimplemented option: -$OPTARG" >&2; exit 1;;
    esac
done
shift $((OPTIND-1))

# check required args
if [[ "$#" -ne 1 ]]; then
    echo "ERROR: Please specify a running mode after optional arguments" >&2
    _usage
    exit 1
fi
MODE=$1

if [[ -z ${SCRIPTS_BY_MODE[$MODE]+foo} ]]; then
    echo "ERROR: Invalid mode! Run ${0##*/} -h for allowed modes" >&2
    exit 1
fi
# this is where all the source files are
BASE=$(realpath --relative-to=$PWD $(dirname $(readlink -e ${BASH_SOURCE[0]}))/../..)
echo $BASE
INPUTS_DIR=${BASE}/Ftagtt/grid/inputs
echo $INPUTS_DIR
WORK_DIR=$PWD
echo $WORK_DIR

# if arguments are not specified, use mode
if [[ -z "$SCRIPT" ]]; then SCRIPT=${SCRIPTS_BY_MODE[$MODE]}; fi
if [[ -z "$INPUT_DATASETS" ]]; then INPUT_DATASETS=$INPUTS_DIR/${INPUTS_BY_MODE[$MODE]}; fi
if [[ "$DRYRUN" ]]; then echo -e $BREAK '\nDRY RUNNING'; fi

# let the user know what options we are using
echo $BREAK
echo -e "Script\t: $SCRIPT"
echo -e "Inputs\t: $INPUT_DATASETS"
echo -e "External files\t: $EXT_FILES"
echo $BREAK

###################################################
# Check for early exit
###################################################

# check arguments
if [[ ! -f $INPUT_DATASETS ]]; then echo "Inputs file doesn't exist!"; exit 1; fi

# check for panda setup
if ! type prun &> /dev/null ; then
    echo "ERROR: You need to source the grid setup script before continuing!" >&2
    exit 1
fi

# check to make sure you've properly set up the environemnt: if you
# haven't sourced the setup script in the build directory the grid
# submission will fail, so we check here before doing any work.
if ! type $SCRIPT &> /dev/null ; then
    echo "ERROR: Code setup with the wrong release or you haven't sourced build/x*/setup.sh" >&2
    exit 1
fi

###################################################
# Some variable definitions
###################################################
# users's grid name
GRID_NAME=${RUCIO_ACCOUNT-${USER}}

######################################################
# Prep the submit area
######################################################
# this is the subdirectory we submit from
SUBMIT_DIR=submit

echo "Preparing submit directory"
if [[ -d ${SUBMIT_DIR} ]]; then
    echo "Removing old submit directory"
    rm -rf ${SUBMIT_DIR}
fi

mkdir ${SUBMIT_DIR}

if [ -n "${EXT_FILES}" ]; then
    # copying all files as external files
    IFS=',' read -r -a EXT_FILES_ARR <<< "${EXT_FILES}"

    for element in "${EXT_FILES_ARR[@]}"
    do
    cp -r "${element}" "${SUBMIT_DIR}/${element}"
    done
fi

cd ${SUBMIT_DIR}
# build a zip of the files we're going to submit
ZIP=job.tgz
echo "Making tarball of local files: ${ZIP}" >&2

# the --outTarBall, --noSubmit, and --useAthenaPackages arguments are
# important. The --outDS and --exec don't matter at all here, they are
# just placeholders to keep panda from complianing.
PRUN_ARGS="--outTarBall=${ZIP} --noSubmit --useAthenaPackages \
--exec='ls' --outDS=user.${GRID_NAME}.x"

# check if ${EXT_FILES} is not empty and append it to the default args
if [ -n "${EXT_FILES}" ]; then
    PRUN_ARGS="${PRUN_ARGS} --extFile=${EXT_FILES}"
fi

# now run the script with the prun args
${DRYRUN} prun ${PRUN_ARGS}

######################################################
# Loop over datasets and submit
######################################################
# parse inputs file
INPUT_DATASETS=$(grep -v '^#'  ${WORK_DIR}/$INPUT_DATASETS)
INPUT_DATASETS=($INPUT_DATASETS)

# loop over all inputs
echo $BREAK
$DRYRUN
echo "Submitting ${#INPUT_DATASETS[*]} datasets as ${GRID_NAME}..."
echo $BREAK

# define a fucntion to do all the submitting
function submit-job() (
    set -eu
    DS=$1

    # this regex extracts the DSID from the input dataset name, so
    # that we can give the output dataset a unique name. It's not
    # pretty: ideally we'd just suffix our input dataset name with
    # another tag. But thanks to insanely long job options names we
    # use in the generation stage we're running out of space for
    # everything else.
    DSID=$(sed -r 's/[^\.]*\.([0-9]{6,8})\..*/\1/' <<< ${DS})
    
    a1=`cut -c 23-28 <<< $DS`
    a2=`cut -c 54-58 <<< $DS`
    a3=`cut -c 69- <<< $DS`
    a4=$(sed 's/.\{42\}$//' <<< "$a3")
    a=$a1$a2$a4.root
    #This is local file outDS
    OUTDS=user.$USER.$a.$(date +'%Y%-m%d').$((1000 + RANDOM % 999999)).root
    #This is global outDS
    OUT_DS=user.${GRID_NAME}.${DSID}.$((1000 + RANDOM % 999999))
    echo ${OUT_DS}
	echo ${OUTDS}
    # check to make sure the grid name isn't too long
    if [[ $(wc -c <<< ${OUT_DS}) -ge 120 ]] ; then
        echo "ERROR: dataset name ${OUT_DS} is too long, can't submit!" 1>&2
        return 1
    fi

    # now submit
    printf "${DS} \n\t-> ${OUT_DS}\n"
    ${DRYRUN} prun --exec "${SCRIPT} %IN "\
         --outDS ${OUT_DS} --inDS ${DS}\
         --useAthenaPackages --inTarBall=${ZIP}\
		 --outputs output.root
)
# --outputs mytest1234file.root\
# we have to export some environment variables so xargs can read them
export -f submit-job
export  GRID_NAME ZIP SCRIPT DRYRUN EXT_FILES

# use xargs to submit all these jobs in batches of 10
printf "%s\n" ${INPUT_DATASETS[*]} | xargs -P 10 -I {} bash -c "submit-job {}"
echo $BREAK
echo "Submission successful"
