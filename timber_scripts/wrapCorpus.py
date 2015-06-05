import sys
import os

if len( sys.argv ) < 2:
	print "USAGE: cat Corpus | python %s grammar_dir (StartID)" % sys.argv[ 0 ]
	sys.exit( 4 )

grammar_dir = sys.argv[ 1 ]
ID = int(sys.argv[2]) if len( sys.argv ) > 2 else 1

for line in sys.stdin:
	line = line.strip()
	parts = [part.strip() for part in line.split('|||')]
	grammar_file = os.path.join(grammar_dir, "%d.gz" % ID)
	parts[0] = '<seg id="%d" grammar="%s">%s</seg>' % (ID - 1, grammar_file, parts[0])
	print ' ||| '.join(parts)
	ID += 1
