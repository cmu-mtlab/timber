import sys
if len( sys.argv ) < 2:
	print >>sys.stderr, "Usage: cat glueGrammar | python %s scoreNames" % sys.argv[ 0 ]
	sys.exit(1)

ScoreNames = open( sys.argv[ 1 ] ).read().split()
for Line in sys.stdin:
	Line = Line.strip()
	Parts = [ Part.strip() for Part in Line.split( "|||" ) ]
	Features = Parts[ 3 ].split()
	Parts[ 3 ] = " ".join( [ "%s=%s" % ( ScoreName, Feature ) for ScoreName, Feature in zip( ScoreNames, Features ) ] )
	print " ||| ".join( Parts )
