set -e
set -o pipefail
set -u
set -x

NUMCORES=$1; shift
SOURCETREES=$1; shift
TARGETTREES=$1; shift;
ALIGNMENTS=$1; shift;

RULELEARNERARGS="$@"
TEMPDIR=$(mktemp -d -p .)

# First split the input files into $NUMCORES pieces.
INPUTLINES=$(wc -l $SOURCETREES | cut -f 1 -d ' ')
LINESPERCORE=$(expr $INPUTLINES / $NUMCORES + 1)
split $SOURCETREES -l $LINESPERCORE -d -a 2 $TEMPDIR/s
split $TARGETTREES -l $LINESPERCORE -d -a 2 $TEMPDIR/t
split $ALIGNMENTS  -l $LINESPERCORE -d -a 2 $TEMPDIR/a

# Define a little function that will actually do the rule learning
RunChunk()
{
	set -eou pipefail
	set -x
	ChunkNumber=$1
	TempDir=$2
	RULELEARNERARGS=$3
	java -jar $timberRoot/grex/RuleLearner.jar $TempDir/s$ChunkNumber $TempDir/t$ChunkNumber $TempDir/a$ChunkNumber $RULELEARNERARGS > $TempDir/o$ChunkNumber
}

# Pass each piece through the rule learner in parallel
export -f RunChunk
seq -f "%02g" 0 $(expr $NUMCORES - 1) | parallel -j $NUMCORES "echo {} >&2; RunChunk {} $TEMPDIR \"$RULELEARNERARGS\""

# Cat the output in order, and clean up!
for ChunkNumber in `seq -f "%02g" 0 $(expr $NUMCORES - 1)`
do
	cat $TEMPDIR/o$ChunkNumber
done
rm -rf $TEMPDIR
