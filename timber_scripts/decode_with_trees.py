import sys
import cdec
import argparse

parser = argparse.ArgumentParser()
parser.add_argument('--weights', '-w', required=True)
parser.add_argument('--config', '-c', required=True)
args = parser.parse_args()

# Load decoder configuration
with open(args.config) as config_file:
	config = config_file.read()
decoder = cdec.Decoder(config)

# Read weights
decoder.read_weights(args.weights)

# Input sentence
for line in sys.stdin:
	source = line.decode('utf-8').strip()

	# Decode
	forest = decoder.translate(source)

	# Output viterbi translation
	source_tree, target_tree = forest.viterbi_trees()
	target = forest.viterbi()
	score = forest.viterbi_features().dot(decoder.weights)
	print '%f\t%s' % (score, target.encode('utf8'))
	print source_tree.encode('utf8')
	print target_tree.encode('utf8')
	sys.stdout.flush()
