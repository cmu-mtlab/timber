import sys

if len( sys.argv ) < 3:
	print >>sys.stderr, "Usage: zcat LCOutput.tar.gz | python %s N side" % sys.argv[ 0 ]
	print >>sys.stderr, "Where N is the desired iteration number"
	print >>sys.stderr, "and side is either 'src' or 'tgt'."
	sys.exit( -1 )

N = int( sys.argv[ 1 ] )
SourceSide = False if sys.argv[ 2 ] == 'tgt' else True
Done = False

while True:
	Line = sys.stdin.readline()
	if not Line:
		break

	if Done or not Line.startswith( "===" ):
		continue

	if Line.startswith( "=== ITERATION %d TABLES ===" % N ):
		# Read the === SOURCE SIDE === header
		Line = sys.stdin.readline()
		while True:
			Line = sys.stdin.readline()
			if not Line or Line.startswith( "===" ):
				break
			elif SourceSide:
				sys.stdout.write( Line )

		while True:
			Line = sys.stdin.readline()
			if not Line or Line.startswith( "===" ):
				break
			elif not SourceSide:
				sys.stdout.write( Line )

		Done = True
