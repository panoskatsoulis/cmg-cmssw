#!/bin/bash
## load functions
source treeProduction.dep

## parse arguments
while ! [ -z "$1" ]; do
    { [ "$1" == "-h" ] || [[ $1 =~ \-*help ]]; } && do_treeProd_help $2
    [ "$1" == "--task" ] && { TASK_NAME=$2; shift 2; continue; }
    [ "$1" == "--type" ] && { TASK_TYPE=$2; shift 2; continue; }
    [ "$1" == "--year" ] && { TASK_YEAR=$2; shift 2; continue; }
    [ "$1" == "--events" ] && { N_EVENTS=$2; shift 2; continue; }
    [ "$1" == "--freq" ] && { FREQ=$2; shift 2; continue; }
    { [ "$1" == "-in" ] || [ "$1" == "--input" ]; } && { IN_FILE_DIR=$2; shift 2; continue; }
    { [ "$1" == "-out" ] || [ "$1" == "--output" ]; } && { OUT_TREES_DIR=$2; shift 2; continue; }
    [ "$1" == "--friends-only" ] && { FRIENDS_ONLY=true; shift; continue; }
    [ "$1" == "--skip-jetCorrs" ] && { SKIP_JETCORRS=true; shift; continue; }
    [ "$1" == "--debug" ] && { set -x; shift; continue; }
    [ "$1" == "--force-rm" ] && { FORCE_RM_DIRS=true; shift; continue; }
    echo "Unsupported argument $1."
    exit 1
done

## define undefined arguments
{ [ -z "$TASK_NAME" ] || [ -z "$TASK_TYPE" ] || [ -z "$TASK_YEAR" ] \
    || [ -z "$IN_FILE_DIR" ] || [ -z "$OUT_TREES_DIR" ]; } && {
    echo "Arguments 'task', 'type', 'year', 'input' & 'output' are necessary."
    exit 1
}
[ -z "$FRIENDS_ONLY" ] && FRIENDS_ONLY=false
[ -z "$SKIP_JETCORRS" ] && SKIP_JETCORRS=false
[ -z "$FORCE_RM_DIRS" ] && FORCE_RM_DIRS=false
[ -z "$N_EVENTS" ] && N_EVENTS=500000
[ -z "$FREQ" ] && FREQ=10m
{ [ -z $PY_CFG ] && ! $FRIENDS_ONLY; } && {
    echo "Either a Python cfg file is required or the Friends Only mode must be specified."
    exit 1
}
{ ! [ -z $PY_CFG ] && $FRIENDS_ONLY; } && {
    echo "The Friends Only mode has been selected but a Python cfg has been given as input. The PyCfg is not required for this mode. Aborting.."
    exit 1
}

## setup environment
! [ -z $CMSSW_BASE ] && CMSSW_DIR=$CMSSW_BASE/src || { echo "do cmsenv"; exit 1; }
OUT_PATH=$OUT_TREES_DIR/$YEAR/$TASK_NAME-$(date | awk '{print $3$2$6}')
# SPACE_CLEANER=$CMSSW_DIR/spaceCleaner-v2.dog ## required for the Full Production mode (to be fixed)
PY_FTREES_CMD=prepareEventVariablesFriendTree.py
TTHANALYSIS_MACRO_PATH=$CMSSW_DIR/CMGTools/TTHAnalysis/macros
FRIENDS_DIR=friends

## clean existing working paths if the user allows
checkRmPath $OUT_PATH $FORCE_RM_DIRS
checkRmPath $CMSSW_DIR/$TASK_NAME $FORCE_RM_DIRS

## setup the required directories
mkdir $OUT_PATH/postprocessor_chunks -p
mkdir $OUT_PATH/friends_chunks
mkdir $OUT_PATH/jetmetUncertainties_chunks
OUT_PATH_POSTPROC=$OUT_PATH/postprocessor_chunks
OUT_PATH_FRIENDS=$OUT_PATH/friends_chunks
OUT_PATH_JETMET=$OUT_PATH/jetmetUncertainties_chunks
# AFS_DIR_POSTPROC_CHUNKS=$CMSSW_DIR/$TASK_NAME
AFS_DIR_FRIENDS_CHUNKS=$CMSSW_DIR/$TASK_NAME/friends_chunks
AFS_DIR_JETMET_CHUNKS=$CMSSW_DIR/$TASK_NAME/jetmetUncertainties_chunks

## the postprocessor block won't run in case of the Friends Only mode ============================================ NEEDS TO BE TESTED =========================================
if ! $FRIENDS_ONLY; then
    echo "===================================================<< THIS MODE NEEDS TO BE TESTED >>==================================================="
    sleep 2s
    echo "===================================================<< THIS MODE NEEDS TO BE TESTED >>==================================================="
    exit 0

    # ! [ -f $IN_FILE_DIR ] && { echo "Input must be a file in the Full Production mode."; exit 2; }
    # ## step1 condor submit the nanoAOD postprocessor
    # nanopy_batch.py -o $TASK_NAME $py_CFG --option year=$YEAR -B -b 'run_condor_simple.sh -t 1200 ./batchScript.sh' || \
    # 	{ echo "nanopy_batch failed, returned $?";  exit 1; }
    # printf "Submimtted tasks for 2018 from $py_CFG\nnanopy_batch returned $?\n"

    # ## setup env and wait untill the batch jobs finish
    # $SPACE_CLEANER $FREQ $TASK_NAME $OUT_PATH_POSTPROC # add logic to the dog to move to eos all the root files before it exits
    # wait $!

    # ## hadd the nanoAOD chuncks
    # postprocessor_LOGS=$(ls $TASK_NAME/*_Chunk*/*.log)
    # JOBS=$(echo $postprocessor_LOGS | tr ' ' '\n' | wc | awk '{print $1}')
    # FINISHED_JOBS=$(grep "return value 0" $postprocessor_LOGS | wc | awk '{print $1}')
    # (( $FINISHED_JOBS == $JOBS )) && { ## if the jobs finished for each process hadd the chunks
    # 	for process in $(ls $OUT_PATH/postprocessor_chunks | sed 's/_Chunk.*$//' | sort -u); do
    # 	    hadd $OUT_TREES_DIR/$process.root $(ls $OUT_PATH_POSTPROC | grep $process)
    # 	done
    # }

    ## redirecting the input to be the directory which is expected below
    IN_FILE_DIR=$OUT_PATH_POSTPROC
fi
## =============================================================================================================== NEEDS TO BE TESTED =========================================

## run the friend tree modules
! [ -d $IN_FILE_DIR ] && { echo "Input must be a directory in the Friends Only mode."; exit 2; } 
cd $TTHANALYSIS_MACRO_PATH && echo "$PWD"
if [ $TASK_TYPE == "data" ]; then
    python $PY_FTREES_CMD -t NanoAOD $IN_FILE_DIR $AFS_DIR_FRIENDS_CHUNKS -D '.*Run.*' -I CMGTools.TTHAnalysis.tools.nanoAOD.susySOS_modules recleaner_step1,recleaner_step2_data,tightLepCR_seq -N $N_EVENTS -q condor --maxruntime 240 --batch-name $TASK_NAME-data

    wait_friendsModule $AFS_DIR_FRIENDS_CHUNKS $FREQ \
	&& haddProcesses $AFS_DIR_FRIENDS_CHUNKS $OUT_PATH_FRIENDS \
	|| exit 1

elif [ $TASK_TYPE == "mc" ]; then
    ! $SKIP_JETCORRS && {
	python $PY_FTREES_CMD -t NanoAOD $IN_FILE_DIR $AFS_DIR_JETMET_CHUNKS -D '^(?!.*Run).*' -I CMGTools.TTHAnalysis.tools.nanoAOD.susySOS_modules jetmetUncertainties$TASK_YEAR -N $N_EVENTS -q condor --maxruntime 240 --batch-name $TASK_NAME-mc_jetcorrs

	wait_friendsModule $AFS_DIR_JETMET_CHUNKS $FREQ \
	    && haddProcesses $AFS_DIR_JETMET_CHUNKS $OUT_PATH_JETMET \
	    || exit 1
    }

    echo "Files ($(ls $OUT_PATH_JETMET | wc | awk '{print $1}')) in the directory $IN_FILE_DIR/$FRIENDS_DIR/jetmetUncertainties:"
    ls $OUT_PATH_JETMET

    python $PY_FTREES_CMD -t NanoAOD $IN_FILE_DIR $AFS_DIR_FRIENDS_CHUNKS -D '^(?!.*Run).*' -F $OUT_PATH_JETMET/{cname}_Friend.root Friends -I CMGTools.TTHAnalysis.tools.nanoAOD.susySOS_modules recleaner_step1,recleaner_step2_mc,tightLepCR_seq -N $N_EVENTS -q condor --maxruntime 240 --batch-name $TASK_NAME-mc

    wait_friendsModule $AFS_DIR_FRIENDS_CHUNKS $FREQ \
	&& haddProcesses $AFS_DIR_FRIENDS_CHUNKS $OUT_PATH_FRIENDS \
	|| exit 1

else
    echo "TASK_TYPE is neither 'data' nor 'mc'"
    exit 1
fi

cd -
exit 0
