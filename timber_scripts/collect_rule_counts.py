import sys
import argparse
import collections
import exceptions

parser = argparse.ArgumentParser()
parser.add_argument('scoreNamesIn')
parser.add_argument('scoreNamesOut')
args = parser.parse_args()

count_name = 'count'
def num(s):
	try:
		return int(s)
	except exceptions.ValueError:
		return float(s)

try:
	with open(args.scoreNamesIn) as f:
		score_names = f.read().decode('utf-8').strip().split()
except IOError:
	print >>sys.stderr, 'ERROR: Unable to open input scoreNames file: %s' % args.scoreNamesIn
	sys.exit(1)

count_indices = [index for index, score_name in enumerate(score_names) if score_name == count_name]
if len(count_indices) != 1:
	print >>sys.stderr, 'ERROR: Input rules don\'t have count field, or score names file incorrect.'
	sys.exit(1)
count_index = count_indices[0]

if len(score_names) > 1:
	print >>sys.stderr, 'WARNING: This step will remove all rule scores other than the count.'

# Accumulator for multiple copies of the same rule with different word aligns:
current_rule = None
align_counts = collections.Counter()
total_count = 0

def output_current_rule():
	if total_count > 0:
		align_string = ' '.join('%d-%d/%d' % (i, j, count) for ((i, j), count) in sorted(align_counts.iteritems()))
		type, lhs, srcRhs, tgtRhs = current_rule
		print '\t'.join((type, lhs, srcRhs, tgtRhs, align_string, str(total_count))).encode('utf-8')

# Read rule instances from standard in, one per line:
# NOTE: This assumes rules are sorted by fields 1-4!
for line in sys.stdin:
	line = line.decode('utf-8').strip()

	# Break rule line into fields:
	type, lhs, srcRhs, tgtRhs, aligns, scores = line.split('\t')
	key = (type, lhs, srcRhs, tgtRhs)	
	scores = scores.split()
	aligns = aligns.split()

	# If different rule than previous one, write out old rule with counts:
	if key != current_rule:
		output_current_rule()
		# Reset accumulators:
		current_rule = key
		total_count = 0
		align_counts = collections.Counter()

	# Add this rule's word alignment link counts to the accumulators:
	count = num(scores[count_index])
	for link in aligns:
		i, j = (num(i) for i in link.split('-'))
		align_counts[(i, j)] += count
	total_count += count

# At end, write out final rule still in accumulators:
output_current_rule()

# Write out new list of score names, which is just the count:
try:
	with open(args.scoreNamesOut, 'w') as f:
		f.write('%s\n' % count_name)
except IOError:
	print >>sys.stderr, 'ERROR: Unable to open output scoreNames file: %s' % args.scoreNamesOut
	sys.exit(1)
