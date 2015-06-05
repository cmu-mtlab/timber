#! /bin/bash
set -e
set -o pipefail
set -u
set -x

# Change these four variables:
# The source side of the tuning or testing set
# The parse trees of the target side of the training data
# The directory housing the system
# The directory to which to output filtered grammars
FULLGRAMMAR=$1
TESTSOURCESENTS=$2
TARGETTRAININGPARSES=$3
SCORENAMES=$4
CORES=$5
OUTPUTDIR=$6
RARITYTHRESHOLD=$7

# Rarity = [e^(1/count)-1] / (e-1), 2 = 0.3776 20 = 0.0299, 50 = 0.01176
# When computing, be sure to round up!
RARITYTHRESHOLD=$7

GRASCORE=$timberRoot/grascore
PHRASESIZELIMIT=5
PARTIALLYFILTEREDGRAMMAR=$OUTPUTDIR/partiallyFilteredGrammar.txt
SPLITTEMP=$OUTPUTDIR/Split
SPLITOUTPUTTEMP=$SPLITTEMP/Output

Split()
{
	File=$1
	N=$2
	OutputDir=$3
	LinesPerFile=$(expr \( $(wc -l $File | cut -f 1 -d ' ') - $CORES \) / $N)
	split -d -l $LinesPerFile $File $OutputDir/
	for f in `ls -1 $OutputDir`;
	do
		NewFileName=$(echo $f | sed 's/^0*\([^$]\)/\1/g')
		if [ "$f" != "$NewFileName" ];
		then
			mv $OutputDir/$f $OutputDir/$NewFileName
		fi
	done
}

FilterSentence()
{
	set -e
	set -o pipefail
	set -u
	set -x

	INPUTLINE=$1
	i=$(echo "$INPUTLINE" | cut -f 1)
	SOURCE=$(echo "$INPUTLINE" | cut -f 2)
	PARTIALLYFILTEREDGRAMMAR=$2
	PHRASESIZELIMIT=$3
	GRASCORE=$4
	OUTPUTDIR=$5
	SCORENAMES=$6
	TEMP=$OUTPUTDIR
	sTemp=$TEMP/s$i
	echo "$SOURCE" > $sTemp

	filterGrammar="perl $GRASCORE/filter-grammar.pl $sTemp $PHRASESIZELIMIT"
	cat $PARTIALLYFILTEREDGRAMMAR.p | $filterGrammar > $TEMP/p$i;
	cat $PARTIALLYFILTEREDGRAMMAR.g2 | $filterGrammar> $TEMP/g$i;
	cat $PARTIALLYFILTEREDGRAMMAR.a2 $TEMP/g$i $TEMP/p$i | perl $GRASCORE/convert-to-cdec.pl true $SCORENAMES | gzip > $OUTPUTDIR/$i.gz
	rm $TEMP/p$i $TEMP/g$i

	rm $sTemp
}

export -f FilterSentence

rm -rf $OUTPUTDIR
rm -rf $SPLITTEMP
rm -rf $SPLITOUTPUTTEMP

mkdir -p $OUTPUTDIR
mkdir -p $SPLITTEMP
mkdir -p $SPLITOUTPUTTEMP

# Generally, we should sortBySource before pruneGrammarTGS, but if the scoring script
# outputs things in this order already, there's no need to redo it.
sortBySource="LC_ALL=C sort -T . -t $'\t' -k 3,3"
pruneGrammarTGS="perl $GRASCORE/prune-grammar-tgs.pl $SCORENAMES 80 rarity -1"

Split $fullGrammar $CORES $SPLITTEMP
for file in `find $SPLITTEMP -maxdepth 1 -type f`; do basename $file; done | parallel -j $CORES "echo {}; cat $SPLITTEMP/{} | $sortBySource | $pruneGrammarTGS | perl $GRASCORE/filter-grammar.pl $TESTSOURCESENTS $PHRASESIZELIMIT | perl $GRASCORE/mark-fully-abstract.pl true > $SPLITOUTPUTTEMP/{}"
ls -1 $SPLITOUTPUTTEMP/* | sort -n | xargs pv >> $PARTIALLYFILTEREDGRAMMAR

pv $PARTIALLYFILTEREDGRAMMAR | grep "^A" > $PARTIALLYFILTEREDGRAMMAR.a &
pv $PARTIALLYFILTEREDGRAMMAR | grep "^G" > $PARTIALLYFILTEREDGRAMMAR.g &
pv $PARTIALLYFILTEREDGRAMMAR | grep "^P" > $PARTIALLYFILTEREDGRAMMAR.p &
wait

# First through out any G rules that have unaligned words whose POS makes it unlikely to be a good unaligned word
# Next, prune rules that don't match a rarity threshold.
pv $PARTIALLYFILTEREDGRAMMAR.g | perl $GRASCORE/prune-grammar-tgt-ins.pl $TARGETTRAININGPARSES 0.8 DT PDT WDT TO IN CC , -LRB- -RRB- : . \`\` \'\' | perl $GRASCORE/prune-grammar-global-maxvalues.pl $SCORENAMES rarity $RARITYTHRESHOLD > $PARTIALLYFILTEREDGRAMMAR.g2

# When we remove cycles, we want to remove by count, so we have to convert rarity back into count, remove cycles, then convert it back to rarity.
# Finally, take the top 4000 of them, with lower rarity being better.
# Detecting cycles in all the A rules takes forever, so we first take the first 5000, then remove cycles, then take the top 4000.
pv $PARTIALLYFILTEREDGRAMMAR.a | perl $GRASCORE/prune-grammar-global.pl $SCORENAMES $OUTPUTDIR/PruneGrammarGlobalTemp 5000 rarity -1 > $PARTIALLYFILTEREDGRAMMAR.a1.25
pv $PARTIALLYFILTEREDGRAMMAR.a1.25 | perl $GRASCORE/map-rarity-to-count.pl $SCORENAMES > $PARTIALLYFILTEREDGRAMMAR.a1.5
pv $PARTIALLYFILTEREDGRAMMAR.a1.5 | perl $GRASCORE/prune-grammar-cycles.pl true $SCORENAMES.new $OUTPUTDIR/PruneCyclesTemp count 1 > $PARTIALLYFILTEREDGRAMMAR.a1.75
pv $PARTIALLYFILTEREDGRAMMAR.a1.75 | perl $GRASCORE/add-rarity-score.pl $SCORENAMES.new | perl $GRASCORE/prune-grammar-global.pl $SCORENAMES $OUTPUTDIR/PruneGrammarGlobalTemp 4000 rarity -1 > $PARTIALLYFILTEREDGRAMMAR.a2
rm $PARTIALLYFILTEREDGRAMMAR.a1.25 $PARTIALLYFILTEREDGRAMMAR.a1.5 $PARTIALLYFILTEREDGRAMMAR.a1.75
rm $SCORENAMES.new $SCORENAMES.new.new
rm $OUTPUTDIR/PruneCyclesTemp
rm $OUTPUTDIR/PruneGrammarGlobalTemp

NUMSENTS=$(wc -l $TESTSOURCESENTS | cut -d ' ' -f 1)
paste <(seq 1 $NUMSENTS) $TESTSOURCESENTS | parallel -j $CORES "echo {}; FilterSentence {} $PARTIALLYFILTEREDGRAMMAR $PHRASESIZELIMIT $GRASCORE $OUTPUTDIR $SCORENAMES"

rm -rf $SPLITTEMP $SPLITOUTPUTTEMP
rm $PARTIALLYFILTEREDGRAMMAR*
