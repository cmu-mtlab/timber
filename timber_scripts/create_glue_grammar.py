import sys

left_hand_sides = set()

for line in sys.stdin:
	line = line.decode('utf-8').strip()
	left_hand_sides.add(line)

glue_features = 'glue?=1'
print '[S] ||| [S,1] [X,2] ||| [S,1] [X,2] ||| %s' % (glue_features)
print '[S] ||| [X,1] ||| [X,1] ||| %s' % (glue_features)

for lhs in left_hand_sides:
	assert lhs[0] == '['
	assert lhs[-1] == ']'
	lhs = lhs[1:-1]
	lhs = lhs.encode('utf-8')
	print '[S] ||| [S,1] [%s,2] ||| [S,1] [%s,2] ||| %s' % (lhs, lhs, glue_features)
	print '[S] ||| [%s,1] ||| [%s,1] ||| %s' % (lhs, lhs, glue_features)
