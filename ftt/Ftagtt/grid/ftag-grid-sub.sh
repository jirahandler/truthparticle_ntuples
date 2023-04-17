#!/usr/bin/env bash

if [[ $- == *i* ]] ; then
    echo "Don't source me!" >&2
    return 1
else
    set -eu
fi

# defaults
JO=main
DS=mc15_13TeV:mc15_13TeV.410000.PowhegPythiaEvtGen_P2012_ttbar_hdamp172p5_nonallhad.merge.DAOD_FTAG2.e3698_s2608_s2183_r7725_r7676_p2625/
OUTDS="user.sgoswami.test1234"
N_FILES_PER_JOB=5

_usage() {
    echo "usage: ${0##*/} [-h] [options]"
}
_help() {
    _usage
    cat <<EOF

Submit job over some dataset. Internally figures out the output
dataset name and special permissions (based on the options you setup
with voms).

Note that this should be run from the directory where your job options
live.

Requires that:
 - You're in a git-controlled directory
 - All changes have been committed

Options:
 -h: get help
 -n <number>: n files to use (default all)
 -j <python script>: jobOptions to use (default ${JO})
 -d <dataset>: input dataset to use (default ${DS})
 -z <file>: create / submit a gziped tarball
 -e: test run, just echo command
 -p <number>: nfiles per job (default ${N_FILES_PER_JOB})

EOF
}

OPTS=""
ECHO=""
TAG=""
UPLOAD_LOCAL=""
ZIP=""
while getopts ":hn:j:d:l:z:uep:" opt $@; do
    case $opt in
        h) _help; exit 1;;
        n) OPTS+=" --nFiles ${OPTARG}";;
        j) JO=${OPTARG};;
        d) DS=${OPTARG};;
		l) OUTDS=${OPTARG};;
        z) ZIP=${OPTARG};;
        u) UPLOAD_LOCAL=1;;
        e) ECHO=1;;
        p) N_FILES_PER_JOB=${OPTARG};;
        # handle errors
        \?) _usage; echo "Unknown option: -$OPTARG" >&2; exit 1;;
        :) _usage; echo "Missing argument for -$OPTARG" >&2; exit 1;;
        *) _usage; echo "Unimplemented option: -$OPTARG" >&2; exit 1;;
    esac
done


SCRIPT_DIR=$(dirname $BASH_SOURCE)

# setup options
OPTS+=" --nGBPerJob=MAX"
OPTS+=" --nFilesPerJob $N_FILES_PER_JOB"
OPTS+=" --site UKI-LT2"
OUT_OPTS=$(${SCRIPT_DIR}/ftag-grid-nm.sh $DS)
OPTS+=" ${OUT_OPTS}"

# pack stuff into a tarball before submitting
if [[ -n $ZIP ]] ; then
    if [[ ! -f $ZIP ]]; then
        echo "making tarball of local files: ${ZIP}" >&2
        prun --exec ${JO} --outTarBall=${ZIP} $OPTS --noSubmit
    fi
    OPTS+=" --inTarBall=${ZIP}"
fi

a1=`cut -c 23-28 <<< $DS`
a2=`cut -c 54-58 <<< $DS`
a3=`cut -c 69- <<< $DS`
a4=$(sed 's/.\{42\}$//' <<< "$a3")
a=$a1$a2$a4
OUTDS="user.$USER.$a$(date +'%Y%-m%d')"
echo "submitting over dataset ${DS}" >&2
CMD="prun  --exec '${JO} %IN ${OUTDS}' --inDS ${DS} --useAthenaPackages  $OPTS"
export 
echo $CMD
if [[ -n $ECHO ]] ; then
    echo $CMD >&2
else
    eval $CMD
fi
echo $OUT_OPTS | cut -d ' ' -f 2
