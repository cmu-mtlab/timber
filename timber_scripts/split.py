import subprocess
import os
import sys
import threading
import shutil

MinSplitSize = 1000
KeyIndexStart = 1
KeyIndexEnd = None
OutputDir = "./SplitOutput"
Delimiter = '|||'
Prefix = ""
# Assumption: input is sorted on key index

for i, arg in enumerate( sys.argv ):
	if arg == "-s":
		MinSplitSize = int( sys.argv[ i + 1 ] )
	elif arg == "-h" or arg == "-?":
		print >>sys.stderr, "Usage: cat Grammar | python %s [-s MinSplitSize] [-k n,m] [-d Delimiter] [-o OutputDir] [-p Prefix]"
		print >>sys.stderr, "By default MinSplitSize is 1000, the key is 1,1, the delimiter is |||, the outputdir is ./SplitOutput, and the Prefix is empty."
		print >>sys.stderr, "The key is the index of the starting and ending fields, starting with 1, and including both start and end."
		print >>sys.stderr, "Output is written to OutputDir/Prefix0, OutputDir/Prefix1, ..."
		sys.exit(1)
	elif arg == "-k":
		Comma = sys.argv[ i + 1 ].find( "," )
		KeyIndexStart = int( sys.argv[ i + 1 ][ : Comma ] )
		KeyIndexEnd = int( sys.argv[ i + 1 ][ Comma + 1 : ] )
	elif arg == "-o":
		OutputDir = sys.argv[ i + 1 ]
	elif arg == "-d":
		Delimiter = sys.argv[ i + 1 ]
	elif arg == "-p":
		Prefix = sys.argv[ i + 1 ]

def GetKey( DataLine ):
	if KeyIndexEnd != None:
		return DataLine.split( Delimiter )[ KeyIndexStart - 1 : KeyIndexEnd ]
	else:
		return DataLine.split( Delimiter )[ KeyIndexStart - 1 : ]

class Splitter:
	def __init__( self ):
		pass

	def Reset( self ):
		self.CurrentPartition = []
		self.LastPartitionOffset = 0
		self.PreviousKey = None
		self.SubPartitionOffsets = []
		self.PartitionIndex = 1
		try:
			self.OutputFile.close()
		except:
			pass
		self.OutputFile = None

	def Split( self, InputStream ):
		self.Reset()
		for i, Line in enumerate( InputStream ):
			Line = Line.strip()
			Key = GetKey( Line )
			if Key != self.PreviousKey:
				self.CreateSubPartition( i - self.LastPartitionOffset )
				if i - self.LastPartitionOffset >= MinSplitSize:
					self.FinalizePartition( i )
			self.AddToCurrentPartition( Line )
			self.PreviousKey = Key
		self.CreateSubPartition( i - self.LastPartitionOffset + 1 )
		self.FinalizePartition( i )

	def AddToCurrentPartition( self, Line ):
		if self.OutputFile == None:
			self.OutputFile = open( os.path.join( OutputDir, "%s%d.txt" % ( Prefix, self.PartitionIndex ) ), "w" )
		self.OutputFile.write( Line + "\n" )

	def CreateSubPartition( self, StartIndex ):
		pass

	def FinalizePartition( self, i ):
		self.OutputFile.close()
		self.CurrentPartition = []
		self.LastPartitionOffset = i
		self.SubPartitionOffsets = []
		self.CreateSubPartition( 0 )
		self.PartitionIndex += 1
		if self.OutputFile != None:
			self.OutputFile.close()
			self.OutputFile = None

try:
	shutil.rmtree( OutputDir )
except:
	pass
os.mkdir( OutputDir )
splitter = Splitter()
splitter.Split( sys.stdin )
