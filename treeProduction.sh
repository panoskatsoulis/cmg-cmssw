#!/bin/bash
[[ $1 =~ \-+help ]] && {
    echo "Usage: $(basename $0) <py-cfg> <task-name> <data/mc>                          (Full Production Mode)"
    echo "Usage: $(basename $0) --friends-only <task-name> <data/mc> <in-trees-dir>     (Friends Only Production Mode)"
    printf "Directory Structure (Full Production):
EOS_PATH --+-- postprocessor_chunks
           |-- friends_chunks
           |-- jetmetUncertainties_chunks
           +-- trees --+-- <trees>.root
                       +-- friends --+-- <ftrees>.root
                                     +-- jetmetUncertainties --+-- <jetmet-trees>.root
"
    printf "Directory Structure (Friends Only):
EOS_PATH --+-- postprocessor_chunks
           |-- friends_chunks
           +-- jetmetUncertainties_chunks

IN_TREES --+-- <old-trees>.root
           +-- friends-DATE --+-- <ftrees>.root
                              +-- jetmetUncertainties --+-- <jetmet-trees>.root
"
    exit 0
}

## set -x
## parse arguments
FRIENDS_ONLY=false
IN_TREES_DIR=""
[ "$1" == "--friends-only" ] && FRIENDS_ONLY=true || py_CFG=$PWD/$1
TASK_NAME=$2
TASK_TYPE=$3 ## either 'data' or 'mc'
$FRIENDS_ONLY && IN_TREES_DIR=$4 

## setup environment
! [ -z $CMSSW_BASE ] && CMSSW_DIR=$CMSSW_BASE/src || { echo "do cmsenv"; exit 1; }
EOS_PATH=$EOS_USER_PATH/sostrees/2018/$TASK_NAME-$(date | awk '{print $3$2$6}')
[ -z $IN_TREES_DIR ] && IN_TREES_DIR=$EOS_PATH/trees
SPACE_CLEANER=$CMSSW_DIR/spaceCleaner-v2.dog
py_FTREES=prepareEventVariablesFriendTree.py
tthanalysis_macro_PATH=$CMSSW_DIR/CMGTools/TTHAnalysis/macros
friends_dir=friends
$FRIENDS_ONLY && friends_dir=friends-$(date | awk '{print $3$2$6}')
N_EVENTS=50000 # 500000

## clean existing working paths if the user allows
## Usage: checkRmPath <dir>
function checkRmPath() {
    DIR2RM=$1
    [ -e $DIR2RM ] && {
	ans=''
	while ! [[ $ans =~ [yn] ]]; do printf "The working path $DIR2RM exists, want to remove it? [y/n]"; read ans; done
	[ "$ans" == "y" ] && rm -rf $DIR2RM
    }
    return
}
checkRmPath $EOS_PATH
checkRmPath $IN_TREES_DIR/$friends_dir
checkRmPath $CMSSW_DIR/$TASK_NAME

## setup the required directories
mkdir $EOS_PATH/postprocessor_chunks -p
mkdir $EOS_PATH/friends_chunks
mkdir $EOS_PATH/jetmetUncertainties_chunks
mkdir $IN_TREES_DIR/$friends_dir/jetmetUncertainties -p

## the postprocessor block won't run in case of the Friends Only mode
if ! $FRIENDS_ONLY; then
    ## step1 condor submit the nanoAOD postprocessor
    nanopy_batch.py -o $TASK_NAME $py_CFG --option year=2018 -B -b 'run_condor_simple.sh -t 1200 ./batchScript.sh' || \
	{ echo "nanopy_batch failed, returned $?";  exit 1; }
    printf "Submimtted tasks for 2018 from $py_CFG\nnanopy_batch returned $?\n"

    ## setup env and wait untill the batch jobs finish
    $SPACE_CLEANER $TASK_NAME $EOS_PATH/postprocessor_chunks # add logic to the dog to move to eos all the root files before it exits
    wait $!

    ## hadd the nanoAOD chuncks
    postprocessor_LOGS=$(ls $TASK_NAME/*_Chunk*/*.log)
    JOBS=$(echo $postprocessor_LOGS | tr ' ' '\n' | wc | awk '{print $1}')
    FINISHED_JOBS=$(grep "return value 0" $postprocessor_LOGS | wc | awk '{print $1}')
    (( $FINISHED_JOBS == $JOBS )) && { ## if the jobs finished for each process hadd the chunks
	for process in $(ls $EOS_PATH/postprocessor_chunks | sed 's/_Chunk.*$//' | sort -u); do
	    hadd $IN_TREES_DIR/$process.root $(ls $EOS_PATH/postprocessor_chunks | grep $process)
	done
    }
fi

## tool that checks if the friend trees module finished
## Usage: wait_friendsModule <output-dir>
function wait_friendsModule() {
    DIR=$1
    while true; do
	jobs_logs=$(ls $DIR/logs/log.* | wc | awk '{print $1}')
	jobs_finished=$(grep -o "return value 0" $DIR/logs/log.* | wc | awk '{print $1}')
	root_files=$(ls $DIR/*.root | wc | awk '{print $1}')
	echo "job_logs=$jobs_logs, jobs_finished=$jobs_finished, root_files=$root_files"
	echo "logs = finished : $(( $jobs_logs == $jobs_finished ))"
	echo "logs = files    : $(( $jobs_logs == $root_files ))"
	echo "logs > files    : $(( $jobs_logs > $root_files ))"
	if (( $jobs_logs == $jobs_finished )) && (( $jobs_logs == $root_files )); then
	    echo "true is (( $jobs_logs == $jobs_finished )) && (( $jobs_logs == $root_files ))"
	    return 0
	elif (( $jobs_logs == $jobs_finished )) && (( $jobs_logs > $root_files )); then
	    echo "true is (( $jobs_logs == $jobs_finished )) && (( $jobs_logs > $root_files ))"
	    echo "[ ERROR ]"
	    echo "All jobs included in $DIR finished, but the number of the produced root files is less than the jobs run."
	    return 1
	else
	    echo "none is true"
	    jobs_failed=$(grep -o "return value [1-9]+" $DIR/logs/log.* | wc | awk '{print $1}')
	    (( $jobs_failed > 0 )) && echo "[ WARNING ] $jobs_failed have failed in directory $DIR"
	    sleep 5m
	fi
    done
}

## tool that hadds all processes in a given path and stores them wherever specified
## Usage: haddProcesses <in-dir> <out-dir>
function haddProcesses() {
    IN_DIR=$1
    OUT_DIR=$1
    processes=$(ls $IN_DIR/*root | sed -r 's@^.*/([^/\.]*).*[Cc]hunk[0-9]*.*root$@\1@' | sort -u)
    for process in $processes; do
	hadd $OUT_DIR/$process.root $IN_DIR/$process.chunk*.root || {
	    echo "hadd failed for path $IN_DIR and process $process"
	    return 1
	}
    done
    return 0
}

## run the friend tree modules
cd $tthanalysis_macro_PATH && echo "$PWD"
if [ $TASK_TYPE == "data" ]; then
    python $py_FTREES -t NanoAOD $IN_TREES_DIR $CMSSW_DIR/$TASK_NAME/friends_chunks -D '.*Run.*' -I CMGTools.TTHAnalysis.tools.nanoAOD.susySOS_modules recleaner_step1,recleaner_step2_data,tightLepCR_seq -N $N_EVENTS -q condor --maxruntime 240 --batch-name $TASK_NAME-data

    wait_friendsModule $CMSSW_DIR/$TASK_NAME/friends_chunks \
	&& haddProcesses $CMSSW_DIR/$TASK_NAME/friends_chunks $IN_TREES_DIR/friends \
	|| exit 1

elif [ $TASK_TYPE == "mc" ]; then
    python $py_FTREES -t NanoAOD $IN_TREES_DIR $CMSSW_DIR/$TASK_NAME/jetmetUncertainties_chunks -D '^(?!.*Run).*' -I CMGTools.TTHAnalysis.tools.nanoAOD.susySOS_modules jetmetUncertainties2018 -N $N_EVENTS -q condor --maxruntime 240 --batch-name $TASK_NAME-mc_jetcorrs

    wait_friendsModule $CMSSW_DIR/$TASK_NAME/jetmetUncertainties_chunks \
	&& haddProcesses $CMSSW_DIR/$TASK_NAME/jetmetUncertainties_chunks $IN_TREES_DIR/$friends_dir/jetmetUncertainties \
	|| exit 1

    python $py_FTREES -t NanoAOD $IN_TREES_DIR $CMSSW_DIR/$TASK_NAME/friends_chunks -D '^(?!.*Run).*' -F $IN_TREES_DIR/$friends_dir/jetmetUncertainties/{cname}_Friend.root Friends -I CMGTools.TTHAnalysis.tools.nanoAOD.susySOS_modules recleaner_step1,recleaner_step2_mc,tightLepCR_seq -N $N_EVENTS -q condor --maxruntime 240 --batch-name $TASK_NAME-mc

    wait_friendsModule $CMSSW_DIR/$TASK_NAME/friends_chunks \
	&& haddProcesses $CMSSW_DIR/$TASK_NAME/friends_chunks $IN_TREES_DIR/friends \
	|| exit 1

else
    echo "TASK_TYPE is neither 'data' nor 'mc'"
    exit 1
fi

cd -
exit 0
