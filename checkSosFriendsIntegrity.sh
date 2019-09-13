#!/bin/bash

function dohelp() { printf "Usage: $(basename $0) --friends-path <dir>\n\n"; exit 0; }

for arg in "$@"; do
    { [[ $arg =~ \-{,2}help ]] || [ "$1" == "-h" ]; } && dohelp
    [ "$arg" == "--debug" ] && { set -x; shift; continue; }
    [ "$arg" == "--friends-path" ] && { friendsToCheck=$2; shift 2; continue; }
done

samples=$(ls $friendsToCheck/logs/log.* | sed "s@.*\<log\>\.[0-9]*\.@@; s/\.[0-9]*$//" | sort -u)
for sample in $samples; do
    [ -z $sample ] && dohelp
    ! [ -e $friendsToCheck ] && { echo "The requested path to process $friendsToCheck does not exist"; exit 1; }

    echo "----- Log File       #  Return Value      # ------- Output root file"
    for chunklog in $(ls $friendsToCheck/logs/*$sample* | grep "\<log\>.*\<$sample\>"); do
	# get the log file
	info="$(echo $chunklog | grep -o "\<logs\>.*$")  #  "
	# get the return value
	info="$info$(grep "return value [0-9]*" $chunklog -o)  #  "
	# get the root files
	info="$info$(find $friendsToCheck -maxdepth 1 | grep $sample.*chunk$(echo $chunklog | grep [0-9]*$ -o).root)"
	#print the line
	printf "$info\n\n"
    done

    ## Getting info for the chunks
    rootFiles=$(find $friendsToCheck -maxdepth 1 | grep $sample.*chunk)
    [ -z "$rootFiles" ] && continue # this happens when the sample consists of only one chunk
    targetFileName=$(ls $rootFiles | sed -r 's/\.chunk[0-9]*(\.root)/\1/' | sort -u)
    [ "$(echo $targetFileName | tr ' ' '\n' | wc | awk '{print $1}')" != "1" ] && {
	printf "The target files for the hadd command are more that 1.\nFailed to get the correct info for the chunks of the sample $sample.\n"
	exit 2
    }

    ## Hadd the chunks
    ans=""
    while ! [[ $ans =~ [yn] ]]; do
	printf "Want to merge them in the file $targetFileName? [y/n]";
	read ans
    done
    [ "$ans" == 'y' ] && {
	hadd -ff $targetFileName $rootFiles || { echo "hadd failed"; exit 3; }
    }

    ## Archive the chunks
    ans=""
    while ! [[ $ans =~ [yn] ]]; do
	printf "Want to archive the chunks in $friendsToCheck/archive? [y/n]";
	read ans
    done
    [ "$ans" == 'y' ] && {
	! [ -e $friendsToCheck/archive ] && mkdir $friendsToCheck/archive
	for file in $rootFiles; do
	    mv $file $friendsToCheck/archive/. \
		&& echo "$file archived." \
		|| { echo "Archive of $file failed."; exit 4; }
	done
    }
done

## Move the trees to the completed directory
ans=""
while ! [[ $ans =~ [yn] ]]; do
    printf "Want to move the trees into the directory $friendsToCheck/completed? [y/n]";
    read ans
done
[ "$ans" == 'y' ] && {
    completedTrees=$(find $friendsToCheck -maxdepth 1 | grep "\.root$")
    echo "Trees to be moved:"
    echo $completedTrees | tr ' ' '\n'
    printf "Continue? [y/n]"; read ans
    ! [ -e $friendsToCheck/completed ] && mkdir $friendsToCheck/completed
    [ "$ans" == 'y' ] && \
	for file in $completedTrees; do mv $file $friendsToCheck/completed/.; done
}
exit 0
