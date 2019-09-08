#!/bin/bash

## help
for arg in ${@}; do
    { [ "$arg" == "--help" ] || [ "$arg" == "-h" ] || [ "$arg" == "-help" ]; } \
	&& { printf "Usage $(basename $0) --pycfg <cfg> --workpath <path> [--dogfreq <freq>, --year <year>, --preprocessor]\n\n"; exit 0; }
done

## env variables
maxRunningSamples=2
## this tool cleans the variables that are used by the script
function cleanVariables() {
    dogfreq=""
    pycfg=""
    year=""
    preprocessor=""
    workpath=""
    process=""
    runningSamples=""
    maxRunningSamples=""
    jobsScheduled=""
    jobsFinished=""
    return 0
}

## this tool parses the options (help: parseOptions <args>)
function parseOptions() {
    while [ ! -z $1 ]; do
	[ "$1" == "--dogfreq" ] && { dogfreq=$2; shift 2; continue; }
	[ "$1" == "--pycfg" ] && { pycfg=$2; shift 2; continue; }
	[ "$1" == "--year" ] && { year=$2; shift 2; continue; }
	[ "$1" == "--workpath" ] && { workpath=$2; shift 2; continue; }
	[ "$1" == "--preprocessor" ] && { preprocessor="--option nanoPreProcessor"; shift; continue; }
	echo "Unknown option $1"
	return 1
    done
    ## define undefined vars
    [ -z $pycfg ] && { echo "The cfg is required to be given as input."; return 1; }
    [ -z $workpath ] && { echo "The workpath path is required to be given as input."; return 1; }
    [ -z $preprocessor ] && echo "The preprocessor has not been selected, will run the postprocessor."
    [ -z $year ] && year="2018"
    [ -z $dogfreq ] && dogfreq="5m"
    return 0
}

## this tool creates a local copy of the given cfg in ./ and prepares it (help: copyCfgHereAndPrepare <pycfg>)
function copyCfgHereAndPrepare() {
    [ ! -f $1 ] && { echo "Can't find the cfg $pycfg in $(pwd)."; return 1; }
    cp -a $1 pycfg.py
    sed -i -r 's@^#*([ #]+".*")@##\1@' pycfg.py ## equal grep command for LHS of sed: grep "^#*[ #]\+\".*\"" pycfg.py
    sed -i 's/.*missing.*//; s/.*FIX.*//; s/.*INVALID.*//' pycfg.py
    sed -i '0,/^##/s/^##//' pycfg.py
    process=$(grep "^#*[ #]\+\".*\"" pycfg.py | grep -v ^## | awk -F '"' '{print $2}')
    return 0
}

## this tool prepares the next sample of the cfg in line to run (help: prepareNextSample)
function prepareNextSample() {
    sed -i 's/^[^#][ #]+".*".*//' pycfg.py
    sed -i '0,/^##/s/^##//' pycfg.py
    process=$(grep "^#*[ #]\+\".*\"" pycfg.py | grep -v ^## | awk -F '"' '{print $2}')
    return 0
}

## this tool runs the nanopy_batch script (help: condorSubmit <process>)
function condorSubmit() {
    nanopy_batch.py -o $workpath/$1 $pycfg --option year=$year $preprocessor -B -b 'run_condor_simple.sh -t 1200 ./batchScript.sh' \
	&& return 0 \
	|| return 1
}

## this tool is a watchdog, checks if any running samples has finished (help: checkIfAnyFinished <dogfreq>)
function checkIfAnyFinished() {
    while true; do
	runningSamples=$(condor_q | grep $USER | wc | awk '{print $1}')
	(( $runningSamples < $maxRunningSamples )) && return 0
	sleep $1
    done
}

## this tool loops over the running processes and hadds the chunks if all the jobs have finished (help: haddRootFiles <workpath>)
function haddRootFiles() {
    for process in $(ls $1/* -d); do
	jobsScheduled=$(ls $process/*_Chunk* -d | wc | awk '{print $1}')
	jobsFinished=$(grep "return value 0" $process/*_Chunk*/*log -m 1 | wc | awk '{print $1}')
	(( $jobsFinished == $jobsScheduled )) && {
	    hadd $EOS_USER_PATH/sostrees/$year/$(basename $process).root $process/*_Chunk*/*.root
	    $? && rm -rf $process || echo "hadd failed for process $process. Remove the path manualy."
	}
    done
    return 0
}



##########################################################################
parseOptions $@
copyCfgHereAndPrepare $pycfg

exit 0
