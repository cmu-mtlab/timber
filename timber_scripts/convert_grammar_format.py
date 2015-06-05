import sys

for line in sys.stdin:
	line = line.decode('utf-8').strip()
	if line.startswith('Sentence '):
		continue
        parts = [part.strip() for part in line.split('|||')]
        if len(parts) == 6:
		type, lhs, srcRhs, tgtRhs, aligns, nodeTypes = parts
		count = '1'
	elif len(parts) == 7:
		type, lhs, srcRhs, tgtRhs, aligns, nodeTypes, count = parts
	else:
		raise Exception("Invalid input grammar format!")
	output = '%s\t%s\t%s\t%s\t%s\t%s' % (type, lhs, srcRhs, tgtRhs, aligns, count)
	print output.encode('utf-8')
