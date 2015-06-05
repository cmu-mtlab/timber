import sys
import argparse

parser = argparse.ArgumentParser()
parser.add_argument('rules')
parser.add_argument('corpus')
args = parser.parse_args()

vocab = set()

for line in open(args.corpus):
	line = line.decode('utf-8').strip().split()
	for word in line:
		vocab.add(word)

for line in open(args.rules):
	line = line.decode('utf-8').split('\t')
	source = line[2].strip()
	for word in source.split():
		if word in vocab:
			vocab.remove(word)

for word in vocab:
	print word.encode('utf-8')
