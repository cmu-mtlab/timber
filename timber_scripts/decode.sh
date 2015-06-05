set -e
set -o pipefail
set -u
set -x

TEMPDIR=./temp
WRAPPEDSOURCE=$1
CDECINI=$2
WEIGHTS=$3
CORES=$4

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
	# echo "$SOURCE" | cdec -c $CDECINI -w $WEIGHTS -r -k 1000 > $OUTPUTDIR/$ID # for N-best
}

export -f DecodeSentence

mkdir -p $TEMPDIR
NUMSENTS=$(wc -l $WRAPPEDSOURCE | cut -f 1 -d ' ')
paste <(seq 1 $NUMSENTS) $WRAPPEDSOURCE | parallel -j $CORES "echo {} 1>&2; DecodeSentence {} $CDECINI $WEIGHTS $TEMPDIR";

for file in `ls -1 $TEMPDIR | sort -n`;
do
	if [[ $(wc -l $TEMPDIR/$file | cut -f 1 -d ' ') -ne 1 ]];
	then
		echo ""
	else
		cat $TEMPDIR/$file
	fi
done
rm -rf $TEMPDIR
