import os
import re
import sys
import argparse
from collections import defaultdict, Counter

parser = argparse.ArgumentParser()
parser.add_argument('oovs')
parser.add_argument('ntcounts')
parser.add_argument('output_dir')
args = parser.parse_args()

ntcounts = defaultdict(dict)
nttotals = Counter()
for line in open(args.ntcounts):
	line = line.decode('utf-8').strip()
	source_label, target_label, count = line.split('\t')
	count = int(count)
	ntcounts[source_label][target_label] = count
	nttotals[source_label] += count

oovs = set()
for line in open(args.oovs):
	line = line.decode('utf-8').strip()
	oovs.add(line)

for i, line in enumerate(sys.stdin):
	out = open(os.path.join(args.output_dir, '%d.txt' % (i+1)), 'w')
	line = line.decode('utf-8').strip()
	for source_label, word in [s[1:-1].split(' ', 1) for s in re.findall(r'\([^()]+\)', line)]:
		if word not in oovs:
			continue
		for target_label, count in [max(ntcounts[source_label].iteritems(), key=lambda (k, v): v)]:
			tGslabel = 1.0 * count / nttotals[source_label]
			if tGslabel < 0.05:
				continue
			features = 'synthetic?=1 tGslabel=%f' % tGslabel
			out.write(('[%s::%s] ||| %s ||| %s ||| %s\n' % (source_label, target_label, word, word, features)).encode('utf-8'))
	out.close()
