#!/bin/bash

## Parameters of the request:
#PBS -q normal
#PBS -l nodes=1:ppn=32
#PBS -l walltime=12:00:00

## Job name:
#PBS -N Testing

## Where to save STDOUT and STDERR:
#PBS -o /home/armatthe/streams/Testing.out
#PBS -e /home/armatthe/streams/Testing.err

## Export environment variables from the submitting environment:
#PBS -V

### specify your project allocation
##PBS -A


## Run actual program here:

set -e
set -o pipefail
set -u
set -x

# If we have more than one ref per sentence, references can be multiple file names
# delimited by spaces
TESTSET=mt08
SOURCESENTS=/home/armatthe/Research/FBIS/TestSets/$TESTSET/source.txt
REFERENCES=/home/armatthe/Research/FBIS/TestSets/$TESTSET/target.txt.*
SYSTEMDIR=/home/armatthe/Research/FBIS/Hybrid
GRAMMARSDIR=$SYSTEMDIR/FilteredGrammars/$TESTSET

OUTPUTDIR=$SYSTEMDIR/output-$TESTSET/
TIMESTAMPS=$SYSTEMDIR/timestamps.txt
MERTDIR=$SYSTEMDIR/mert
TEMPDIR=$OUTPUTDIR/tmp/
CDECINI=$SYSTEMDIR/cdec.ini
CORES=32 # 64G / size of largest grammar, so that they can all fit in RAM at once
WEIGHTS=$MERTDIR/$(ls -1 $MERTDIR | egrep 'weights.[0-9]+$' | sort | tail -n 1)

SCRIPTS=/home/armatthe/Research/Steps/Testing/
WRAPPEDSOURCE=$OUTPUTDIR/source-wrapped.txt

DecodeSentence()
{
	set -e
	set -o pipefail
	set -u
	set -x

	ID=$(echo "$1" | cut -f 1)
	SOURCE=$(echo "$1" | cut -f 2)
	CDECINI=$2
	WEIGHTS=$3
	OUTPUTDIR=$4

	echo "$SOURCE" | cdec -c $CDECINI -w $WEIGHTS > $OUTPUTDIR/$ID
}

export -f DecodeSentence

echo "Testing:" >> $TIMESTAMPS
date >> $TIMESTAMPS

rm -rf $OUTPUTDIR
mkdir -p $OUTPUTDIR
mkdir -p $TEMPDIR
cat $SOURCESENTS | python $SCRIPTS/wrapCorpus.py $GRAMMARSDIR > $WRAPPEDSOURCE
NUMSENTS=$(wc -l $WRAPPEDSOURCE | cut -f 1 -d ' ')
paste <(seq 1 $NUMSENTS) $WRAPPEDSOURCE | parallel -j $CORES "echo {}; DecodeSentence {} $CDECINI $WEIGHTS $TEMPDIR";

for file in `ls -1 $TEMPDIR | sort -n`;
do
	if [[ $(wc -l $TEMPDIR/$file | cut -f 1 -d ' ') -ne 1 ]];
	then
		echo "" >> $OUTPUTDIR/output.txt
	else
		cat $TEMPDIR/$file >> $OUTPUTDIR/output.txt
	fi
done

METEORTASK=li
METEORLANG=other
OUTPUTFILE=$OUTPUTDIR/score.txt
$SCRIPTS/multeval/VERSIONING_UNSUPPORTED/multeval.sh eval --refs $REFERENCES --hyps-baseline $OUTPUTDIR/output.txt --meteor.task $METEORTASK --meteor.language $METEORLANG &> $OUTPUTFILE

rm -rf $TEMPDIR
rm $WRAPPEDSOURCE
date >> $TIMESTAMPS
