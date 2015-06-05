import sys
import argparse
import os

parser = argparse.ArgumentParser(description='Generates a script that will score a set of grammar rule instances')
parser.add_argument( "--lexE2F", default="/dev/null", help="The E2F lexical probability file. Only necessary if you're scoring lexical probabilities." )
parser.add_argument( "--lexF2E", default="/dev/null", help="The F2E lexical probability file. Only necessary if you're scoring lexical probabilities." )
parser.add_argument( "--srcLCTable", default="/dev/null", help="The source-side label collapsing table" )
parser.add_argument( "--tgtLCTable", default="/dev/null", help="The target-side label collapsint table" )
parser.add_argument( "--sortRAM", default="1G", help="The amount of RAM to be used during sorting. Format is 2G. Default is 1G." )
parser.add_argument( "--sortTempDir", default=".", help="The directory to store temporary files while sorting. Default is $PWD." )
parser.add_argument( "--numCores", type=int, default="1", help="The number of processors on which to score the grammar. Default is 1." )
parser.add_argument( "--glueGrammar", default="glueGrammar", help="The output filename for the glue grammar. Default is $PWD/glueGrammar")
parser.add_argument( "--gzip", action='store_true', default=False, help="Read and write to gzipped files. This decreases disk space used, but greatly increases time taken.")
parser.add_argument( "RuleInstances", help="The input filename containing the rule instances to be scored, in raw rulelearner output format")
parser.add_argument( "ScoredGrammar", help="The output filename for the scored grammar")
parser.add_argument( "ScoreNames", help="The output filename for the score names file")
args = parser.parse_args()
SortedGrammar = os.path.join( args.sortTempDir, "rl-rules-sorted.txt" )

class ScoringPipeline:
	def __init__( self, Steps=[] ):
		self.Steps = Steps

	def getHeaderCommands( self ):	
		Commands = [ \
		"#!/bin/bash",
		"",
		"set -e",
		"set -o pipefail",
		"set -u",
		"set -x",
		"",	
		"# Inputs:",
		"ruleInstances='%s'" % args.RuleInstances,
		"lexE2F=%s" % args.lexE2F,
		"lexF2E=%s" % args.lexF2E,
		"srcLCTable=%s" % args.srcLCTable,
		"tgtLCTable=%s" % args.tgtLCTable,	
		"",
		"# Outputs:",
		"glueFile=%s" % args.glueGrammar,
		"scoredFile=%s" % args.ScoredGrammar,
		"scoreNames=%s" % args.ScoreNames,
		"",
		"# Temp files:",
		"sortedFile=%s" % SortedGrammar,
		"",
		"# Parameters: ",
		"sortRAM=\"%s\"" % args.sortRAM,
		"sortTempDir=\"%s\"" % args.sortTempDir,
		"numCores=%d" % args.numCores,
		""
		"echo 'Starting...'",
		"pv $ruleInstances > $scoredFile",
		'echo "count" > $scoreNames',
		"date",
		"",
		]
		return Commands

	def getFooterCommands( self ):
		return []	

	def getCommands( self ):
		Commands = []
		BlankLine = [ "" ]
		Commands += self.getHeaderCommands()

		for Step in self.Steps:
			Commands += Step.getCommands()
			Commands += [ "" ] # Add a blank line just for pretiness

		Commands += self.getFooterCommands()
		return Commands

	def gen( self ):
		return "\n".join( self.getCommands() )

class FeatureScorer:
	def __init__( self, Name, Script ):
		self.Name = Name
		self.Script = Script

	def getInputPipe( self, fileName ):
		if args.gzip:
			return "pv %s | zcat |" % fileName
		else:
			return "pv %s |" % fileName

	def getOutputPipe( self, fileName ):
		if args.gzip:
			return "| gzip > %s" % fileName
		else:
			return "> %s" % fileName

	def getHeaderCommands( self ):
		return []

	def getFooterCommands( self ):
		return [ "mv $scoreNames.new $scoreNames",
			 "rm $sortedFile",
			 "date" ]

	def getSortCommands( self ):
		return [ "mv $scoredFile $sortedFile" ]

	def getToolCommands( self ):
		return [ 'echo "Running the %s"' % self.Name,
			 "%s perl %s $scoreNames %s" % ( self.getInputPipe( "$sortedFile" ), self.Script, self.getOutputPipe( "$scoredFile" ) ) ]

	def getCommands( self ):
		r = []
		r += self.getHeaderCommands()
		r += self.getSortCommands()	
		r += self.getToolCommands()
		r += self.getFooterCommands()
		return r

	def gen( self ):
		return "\n".join( self.getCommands() )

class NonSortingFeatureScorer(FeatureScorer):
	def __init__( self, Name, Script ):
		FeatureScorer.__init__( self, Name, Script )


class SerialSortingFeatureScorer(FeatureScorer):
	def __init__( self, Name, Script, Key ):
		FeatureScorer.__init__( self, Name, Script )
		self.Key = Key
	
	def getToolCommands( self ):
		return [ 'echo "Running the %s"' % self.Name,
		         '%s perl %s $scoreNames %s' % ( self.getInputPipe( "$sortedFile" ), self.Script, self.getOutputPipe( "$scoredFile" ) ) ]

	def getSortCommands( self ):
		return [ 'echo "Sorting for the %s"' % self.Name,
			"%s LC_ALL=C sort -S $sortRAM -T $sortTempDir -t $'\\t' -k %s %s" % ( self.getInputPipe( "$scoredFile" ), self.getKeyString(), self.getOutputPipe( "$sortedFile" ) ) ]

	def getKeyString( self ):
		return "%d,%d" % self.Key


class ParallelSortingFeatureScorer(FeatureScorer):
	def __init__( self, Name, Script, Key ):
		FeatureScorer.__init__( self, Name, Script )
		self.Key = Key
		self.SplitTempDir = "./SplitTemp"
		self.SplitOutputDir = "./SplitOutput"

	def getSplitCommands( self ):
		return [ "SplitSize=$(expr $(%s wc -l | cut -d ' ' -f 1) / $(expr $numCores + 1) )" % ( self.getInputPipe( "$sortedFile" ) ),
			 "%s python $scriptDir/split.py -k %s -d $'\t' -s $SplitSize -o %s" % ( self.getInputPipe( "$sortedFile" ), self.getKeyString(), self.SplitTempDir ) ]
	
	def getToolCommands( self ):
		return [ 'echo "Running the %s"' % self.Name,
			 "rm -rf %s" % self.SplitTempDir,
			 "rm -rf %s" % self.SplitOutputDir,
			 "mkdir -p %s" % ( self.SplitTempDir ),
			 "mkdir -p %s" % ( self.SplitOutputDir ) ] + \
			  self.getSplitCommands() + \
		       [ "ls -1 %s | parallel -j $numCores \"echo {}; cat \\\"%s/{}\\\" | perl %s $scoreNames > \\\"%s/{}\\\" \"" % ( self.SplitTempDir, self.SplitTempDir, self.Script, self.SplitOutputDir ),
			 "for file in `ls -1 \"%s\" | sort -n`; do cat \"%s/$file\" >> \"%s/output.txt\"; done" % ( self.SplitOutputDir, self.SplitOutputDir, self.SplitOutputDir ),
			 "cat \"%s/output.txt\" %s" % ( self.SplitOutputDir, self.getOutputPipe( "$scoredFile" ) ),
			 "rm -rf %s %s" % ( self.SplitTempDir, self.SplitOutputDir ) ]

	def getSortCommands( self ):
		# The --parallel=$numCores flag seems to be unsupported on some machines.
		return [ 'echo "Sorting for the %s"' % self.Name,
			"%s LC_ALL=C sort -S $sortRAM -T $sortTempDir -t $'\\t' -k %s %s --parallel=$numCores" % ( self.getInputPipe( "$scoredFile" ), self.getKeyString(), self.getOutputPipe( "$sortedFile" ) ) ]

	def getKeyString( self ):
		return "%d,%d" % self.Key

SortingFeatureScorer = ParallelSortingFeatureScorer if args.numCores > 1 else SerialSortingFeatureScorer

class LexProbScorer(FeatureScorer):
	def __init__( self, Name, Script ):
		FeatureScorer.__init__( self, Name, Script )

	def getToolCommands( self ):
		return [ 'echo "Running the %s"' % self.Name,
			 "%s perl %s $lexE2F $lexF2E $scoreNames %s" % ( self.getInputPipe( "$sortedFile" ), self.Script, self.getOutputPipe( "$scoredFile" ) ) ]

class GlueFeatureScorer(FeatureScorer):
	def __init__( self, Name, Script, NamingScript ):
		FeatureScorer.__init__( self, Name, Script  )
		self.NamingScript = NamingScript

	def getToolCommands( self ):
		return [ 'echo "Running the %s"' % self.Name,
			 "%s perl %s $scoreNames $glueFile %s" % ( self.getInputPipe( "$sortedFile" ), self.Script, self.getOutputPipe( "$scoredFile" ) ),
			 "cat $glueFile | python %s $scoreNames.new > $glueFile.named" % self.NamingScript,
			 "mv $glueFile.named $glueFile" ]

class LabelCollapser(FeatureScorer):
	def __init__( self, Name, Script ):
		FeatureScorer.__init__( self, Name, Script )

	def getToolCommands( self ):
		return [ 'echo "Running the %s"' % self.Name, 
			 "%s perl %s $srcLCTable $tgtLCTable %s" % ( self.getInputPipe( "$sortedFile" ), self.Script, self.getOutputPipe( "$scoredFile" ) ) ]

	def getFooterCommands( self ):
		return [ "rm $sortedFile" ]

Grascore="$timberRoot/grascore"
CollapseLabels = LabelCollapser( "Label Collapser", os.path.join( Grascore, "collapse-labels-newrl.pl" ) )
CountCollector = SortingFeatureScorer( "Count Collector", os.path.join( Grascore, "collect-counts.pl" ), (1,4) )
PhrasalSGTScorer = SortingFeatureScorer( "Phrasal SGT Scorer", os.path.join( Grascore, "score-phrase-sgt.pl" ), (4,4) )
PhrasalTGSScorer = SortingFeatureScorer( "Phrasal TGS Scorer", os.path.join( Grascore, "score-phrase-tgs.pl" ), (3,3) )
LHSLabelScorer = SortingFeatureScorer( "LHS Label Scorer", os.path.join( Grascore, "score-lhs-given-rhs.pl" ), (3,4) )
LexProbScorer = LexProbScorer( "Lex Prob Scorer", os.path.join( Grascore, "add-lex-probs-jon.pl") )
RarityScorer = NonSortingFeatureScorer( "Rarity Scorer", os.path.join( Grascore, "add-rarity-score.pl") )
FullyAbsScorer = NonSortingFeatureScorer( "Fully Abstract Scorer", os.path.join( Grascore, "add-fully-abs-bin.pl") )
FullyLexScorer = NonSortingFeatureScorer( "Fully Lexical Scorer", os.path.join( Grascore, "add-fully-lex-bin.pl" ) )
GlueScorer = GlueFeatureScorer( "Glue Scorer", os.path.join( Grascore, "add-glue-bin.pl" ), os.path.join( "$timberRoot", "timber_scripts/nameGlueGrammar.py" ) )

scoringPipeline = ScoringPipeline( [ CollapseLabels, CountCollector, PhrasalSGTScorer, PhrasalTGSScorer, LHSLabelScorer, LexProbScorer, RarityScorer, FullyAbsScorer, FullyLexScorer, GlueScorer ] )
print scoringPipeline.gen()
