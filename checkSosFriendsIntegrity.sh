#!/bin/bash

function dohelp() { printf "Usage: $(basename $0) <sample-to-check>\n\n"; exit 0; }
friendsToCheck=FriendTrees2018
#friendsToCheck=FriendTrees2018_MC

for arg in "$@"; do
    { [[ $1 =~ \-{,2}help ]] || [ "$1" == "-h" ]; } && dohelp
    [ "$1" == "--debug" ] && { set -x; shift; continue; }
done
sample=$1
[ -z $sample ] && dohelp

echo "----- Log File       #  Return Value      # ------- Output root file"
for chunklog in $(ls $friendsToCheck/logs/*$sample* | grep "\<log\>"); do
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
sampleName=$(ls $friendsToCheck/$sample* | sed -r 's@.*/(.*_Friend).*@\1@' | uniq)
rootFiles=$(find $friendsToCheck -maxdepth 1 | grep $sample.*chunk)

## Hadd the chunks
ans=""
while ! [[ $ans =~ [yn] ]]; do
    printf "Want to merge them in the file $sampleName.root? [y/n]";
    read ans
done
[ "$ans" == 'y' ] && {
    hadd -ff $friendsToCheck/$sampleName.root $rootFiles || { echo "hadd failed"; exit 1; }
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
	    || { echo "Archive of $file failed."; exit 2; }
    done
}

exit 0
