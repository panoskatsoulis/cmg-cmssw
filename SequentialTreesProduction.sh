#!/bin/bash

## help
for arg in ${@}; do
    { [ "$arg" == "--help" ] || [ "$arg" == "-h" ] || [ "$arg" == "-help" ]; } \
	&& { printf "Usage $(basename $0) --pycfg <cfg> --workpath <path> [--dogfreq <freq>, --year <year>, --preprocessor, --log]\n\n"; exit 0; }
done

## env variables
maxRunningSamples=2
finished=false
## this tool cleans the variables that are used by the script
function cleanVariables() {
    dogfreq=""
    pycfg=""
    year=""
    preprocessor=""
    log=""
    workpath=""
    process=""
    runningSamples=""
    maxRunningSamples=""
    jobsScheduled=""
    jobsFinished=""
    sample=""
    yearFound=""
    finished=""
    return 0
}
## this tool print all variables that are used by the script
function printVariables() {
    echo "dogfreq=$dogfreq"
    echo "pycfg=$pycfg"
    echo "year=$year"
    echo "preprocessor=$preprocessor"
    echo "log=$log"
    echo "workpath=$workpath"
    echo "process=$process"
    echo "runningSamples=$runningSamples"
    echo "maxRunningSamples=$maxRunningSamples"
    echo "jobsScheduled=$jobsScheduled"
    echo "jobsFinished=$jobsFinished"
    echo "sample=$sample"
    echo "yearFound=$yearFound"
    echo "finished=$finished"
    return 0
}

## handlers for signals
trap reconfig SIGINT ## ctrl+c
function quit() {
    echo "The loop stopped, cleanning environment and exiting..."
    [ -e ./pycfg.py ] && rm -f pycfg.py
    cleanVariables
    exit 0
}
function reconfig() {
    printf "\nOptions accessible via this prompt: --dogfreq <freq>, --maxRunningSamples <num>, exit
input > " > /dev/stderr
    read -a args
    for (( i=0; i<${#args[*]}; i++ )); do
	echo "Parsing argument ${args[$i]}..." > /dev/stderr
	[ "${args[$i]}" == "--dogfreq" ] && { dogfreq=${args[$i+1]}; echo "new dogfreq=$dogfreq" > /dev/stderr; continue 2; }
	[ "${args[$i]}" == "--maxRunningSamples" ] && { maxRunningSamples=${args[$i+1]}; echo "new maxRunningSamples=$maxRunningSamples" > /dev/stderr; continue 2; }
	[ "${args[$i]}" == "exit" ] && { quit; }
    done
    args=""
    return
}

## this tool parses the options (help: parseOptions <args>)
function parseOptions() {
    while [ ! -z $1 ]; do
	[ "$1" == "--dogfreq" ] && { dogfreq=$2; shift 2; continue; }
	[ "$1" == "--pycfg" ] && { pycfg=$2; shift 2; continue; }
	[ "$1" == "--year" ] && { year=$2; shift 2; continue; }
	[ "$1" == "--workpath" ] && { workpath=$2; shift 2; continue; }
	[ "$1" == "--preprocessor" ] && { preprocessor="--option nanoPreProcessor"; shift; continue; }
	[ "$1" == "--log" ] && { log=true; shift; continue; }
	echo "Unknown option $1"
	return 1
    done
    ## define undefined vars
    [ -z "$pycfg" ] && { echo "The cfg is required to be given as input."; return 1; }
    [ -z "$workpath" ] && { echo "The workpath path is required to be given as input."; return 1; }
    [ -z "$preprocessor" ] && echo "The preprocessor has not been selected, will run the postprocessor."
    [ -z "$log" ] && log=false
    [ -z "$year" ] && year="2018"
    [ -z "$dogfreq" ] && dogfreq="5m"
    $log && {
	echo "LOG STARTS HERE:" > SequentialTreesProduction.log
	printVariables > SequentialTreesProduction.log
    }
    return 0
}

## this tool creates a local copy of the given cfg in ./ and prepares it (help: copyCfgHereAndPrepare <pycfg>)
function copyCfgHereAndPrepare() {
    [ ! -f $1 ] && { echo "Can't find the cfg $pycfg in $(pwd)."; return 1; }
    cp -a $1 pycfg.py
    $log && { echo "[copyCfgHereAndPrepare $(date)] Copied $1 in $(pwd)" > SequentialTreesProduction.log; }
    sed -i -r 's@^#*([ #]+".*")@##\1@' pycfg.py ## equal grep command for LHS of sed: grep "^#*[ #]\+\".*\"" pycfg.py
    sed -i 's/.*missing.*//; s/.*FIX.*//; s/.*INVALID.*//' pycfg.py
    sed -i '0,/^##/s/^##//' pycfg.py
    process=$(grep "^#*[ #]\+\".*\"" pycfg.py | grep -v ^## | awk -F '"' '{print $2}')
    $log && { echo "[copyCfgHereAndPrepare $(date)] Uncommented $process" > SequentialTreesProduction.log; }
    return 0
}

## this tool prepares the next sample of the cfg in line to run, and updates the process variable (help: prepareNextSample)
function prepareNextSample() {
    sed -i 's/^[^#][ #]+".*".*//' pycfg.py
    sed -i '0,/^##/s/^##//' pycfg.py
    process=$(grep "^#*[ #]\+\".*\"" pycfg.py | grep -v ^## | awk -F '"' '{print $2}')
    $log && { echo "[prepareNextSample $(date)] Uncommented $process" > SequentialTreesProduction.log; }
    return 0
}

## this tool runs the nanopy_batch script (help: condorSubmit <process>)
function condorSubmit() {
    $log && { echo "[condorSubmit $(date)] Will submit jobs for process $process" > SequentialTreesProduction.log; }
    nanopy_batch.py -o $workpath/$1 $pycfg --option year=$year $preprocessor -B -b 'run_condor_simple.sh -t 1200 ./batchScript.sh' \
	&& return 1
    echo "condorSubmit finished"
    return 0
}

## this tool is a watchdog, checks if any running samples has finished (help: checkIfAnyFinished <dogfreq>)
function checkIfAnyFinished() {
    while true; do
	runningSamples=$(condor_q | grep $USER | wc | awk '{print $1}')
	$log && { echo "[checkIfAnyFinished $(date)] runningSamples = $runningSamples ($maxRunningSamples allowed)." > SequentialTreesProduction.log; }
	(( $runningSamples < $maxRunningSamples )) && return 0
	$log && { echo "[checkIfAnyFinished $(date)] Will sleep..." > SequentialTreesProduction.log; }
	sleep $1
    done
}

## this tool loops over the running processes and hadds the chunks if all the jobs have finished (help: haddRootFiles <workpath>)
function haddRootFiles() {
    for sample in $(ls $1/* -d); do
	jobsScheduled=$(ls $sample/*_Chunk* -d | wc | awk '{print $1}')
	jobsFinished=$(grep "return value 0" $sample/*_Chunk*/*log -m 1 | wc | awk '{print $1}')
	(( $jobsFinished == $jobsScheduled )) && {
	    hadd -f -ff $EOS_USER_PATH/sostrees/$year/$(basename $sample).root $sample/*_Chunk*/*.root
	    $? && rm -rf $sample || echo "hadd failed for process $process. Remove the path manualy."
	}
	$log && { echo "[haddRootFiles $(date)] sample $sample, jobsFinished=$jobsFinished | jobsScheduled=$jobsScheduled" > SequentialTreesProduction.log; }
    done
    return 0
}

## this tool calculates in which year is the process that will be submitted next, and echoes it (help: $(findYear))
function findYear() {
    occurrences=$(grep "^#*[ #]\+\".*\"\|^[^ ]*if year ==" pycfg.py | sed '/year/{N;N; s/\n//g; q}' | grep "\<year\>" -o | wc | awk '{print $1}')
    case $occurrences in
	1) echo "2018" ;;
	2) echo "2017" ;;
	3) echo "2016" ;;
	*) echo "unknown year" ;;
    esac
    return 0
}



##########################################################################
parseOptions $@ || { echo "parseOptions returned $?"; exit 1; }
[ -e $workpath ] && rm -r $workpath; mkdir $workpath
copyCfgHereAndPrepare $pycfg || { echo "copyCfgHereAndPrepare returned $?"; exit 1; } # this updates $process
while ! $finished; do
    condorSubmit $process || { echo "condorSubmit returned $?" > /dev/null; exit 1; }
    checkIfAnyFinished $dogfreq
    haddRootFiles $workpath
    prepareNextSample
    yearFound=$(findYear)
    [ $yearFound != $year ] && finished=true
    $log && { echo "[in loop $(date)] yearFound=$yearFound, finished=$finished" > SequentialTreesProduction.log; }
done

cleanVariables
exit 0
