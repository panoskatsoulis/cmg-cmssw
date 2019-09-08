#!/bin/bash

## help
for arg in ${@}; do
    { [ "$arg" == "--help" ] || [ "$arg" == "-h" ] || [ "$arg" == "-help" ]; } \
	&& { printf "Usage $(basename $0) --pycfg <cfg> [--dogfreq <freq>, --year <year>, --preprocessor]\n\n"; exit 0; }
done

## env variables
## this tool cleans the variables that are used by the script
function cleanVariables() {
    dogfreq=""
    process=""
    pycfg=""
    year=""
    preprocessor=""
    return 0
}

## this tool parses the options (help: parseOptions <args>)
function parseOptions() {
    while [ ! -z $1 ]; do
	[ "$1" == "--dogfreq" ] && { dogfreq=$2; shift 2; continue; }
	[ "$1" == "--pycfg" ] && { pycfg=$2; shift 2; continue; }
	[ "$1" == "--year" ] && { year=$2; shift 2; continue; }
	[ "$1" == "--preprocessor" ] && { preprocessor="--option nanoPreProcessor"; shift; continue; }
	echo "Unknown option $1"
	return 1
    done
    ## define undefined vars
    [ -z $pycfg ] && { echo "The cfg is required to be given ad input."; return 1; }
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
    return 0
}

## this tool prepares the next sample of the cfg in line to run
function prepareNextSample() {

    return 0
}

## this tool runs the nanopy_batch script (help: condorSubmit <process>)
function condorSubmit() {
    nanopy_batch.py -o $1 $pycfg --option year=$year $preprocessor -B -b 'run_condor_simple.sh -t 1200 ./batchScript.sh' \
	&& return 0 \
	|| return 1
}

## this tool is a watchdog, checks if any running samples has finished
function checkIfAnyFinished() {

    return
}

## this tool hadds the root files in the chunks of a given output folder
function haddRootFiles() {

    return 0
}



##########################################################################
parseOptions $@
copyCfgHereAndPrepare $pycfg

exit 0
