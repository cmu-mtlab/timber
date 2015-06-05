import sys

for line in sys.stdin:
	line = line.strip()
	if line.startswith('Alignment'):
		hyp = sys.stdin.next()
		ref = sys.stdin.next()
		header = sys.stdin.next()

		for line in sys.stdin:
			line = line.strip()
			if len(line) == 0:
				print
				break

			hyp_pair, ref_pair, module, score = line.split()
			
			if module == '-1':
				continue

			(hyp_start, hyp_len) = hyp_pair.split(':')
			(ref_start, ref_len) = ref_pair.split(':')
			hyp_start, hyp_len = int(hyp_start), int(hyp_len)
			ref_start, ref_len = int(ref_start), int(ref_len)
			for i in range(hyp_start, hyp_start + hyp_len):
				for j in range(ref_start, ref_start + ref_len):
					print '%d-%d' % (i, j),
