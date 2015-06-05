# Author: Greg Hanneman
use strict;


# Check usage:
if($#ARGV != 2)
{
	print STDERR "Usage:\n";
	print STDERR "  perl $0 <lc-map> <nt-pair-counts> <src|tgt>\n";
	exit(1);
}

# Make sure third parameter is either "src" or "tgt":
my $side = lc($ARGV[2]);
if($side ne "src" && $side ne "tgt")
{
	print STDERR "ERROR:  Third parameter must either be 'src' or 'tgt'!\n";
	exit(1);
}

# Read in and store label frequency counts for the appropriate side:
my %NTCounts = ();
open(my $FILE, $ARGV[1]) or die "Can't open input file $ARGV[1]: $!";
while(my $line = <$FILE>)
{
	chomp $line;
	my ($srcNt, $tgtNt, $count) = split(/\t/, $line);
	if($side eq "src") { $NTCounts{$srcNt} += $count; }
	elsif($side eq "tgt") { $NTCounts{$tgtNt} += $count; }
}
close($FILE);

# Read in and store label-collapsed cluster names:
my %ClusterNames = ();
open(my $FILE, $ARGV[0]) or die "Can't open input file $ARGV[0]: $!";
while(my $line = <$FILE>)
{
	chomp $line;
	my ($orig, $collapsed) = split(/\t/, $line);
	$ClusterNames{$collapsed} = "";
}
close($FILE);

# Try to assign a short name to each cluster, based on the most common
# nonterminals inside it:
my %ShortNames = ();
foreach my $cluster (sort keys %ClusterNames)
{
	# Find the three most common labels in the cluster:
	my @Labels = split(/\|/, $cluster);
	my $oneLabel = ""; my $twoLabel = ""; my $threeLabel = "";
	my $oneFreq = 0; my $twoFreq = 0; my $threeFreq = 0;
	foreach my $label (@Labels)
	{
		my $f = $NTCounts{$label};
		if($f > $oneFreq)
		{
			# Found a new first best:
			$threeLabel = $twoLabel;
			$threeFreq = $twoFreq;
			$twoLabel = $oneLabel;
			$twoFreq = $oneFreq;
			$oneLabel = $label;
			$oneFreq = $f;
		}
		elsif($f < $oneFreq && $f > $twoFreq)
		{
			# Found a new second best:
			$threeLabel = $twoLabel;
			$threeFreq = $twoFreq;
			$twoLabel = $label;
			$twoFreq = $f;
		}
		elsif($f < $twoFreq && $f > $threeFreq)
		{
			# Found a new third best:
			$threeLabel = $label;
			$threeFreq = $f;
		}
	}

	# Try to name this cluster based on one of them:
	my $name = ProcessLabelName($oneLabel);
	if(exists($ShortNames{$name}))
	{
		$name = ProcessLabelName($twoLabel);
		if(exists($ShortNames{$name}))
		{
			$name = ProcessLabelName($threeLabel);
			if(exists($ShortNames{$name}))
			{
				# Give up and use full name if top three all fail:
				print STDERR "WARNING:  Can't find short name for $cluster\n";
				$name = ProcessLabelName($cluster);
			}
		}
	}
	$ClusterNames{$cluster} = $name;
	$ShortNames{$name} = 1;
}

# Now %ClusterNames should be a map from collapse-output names to short ones.
# Rewrite the label collapsing map file with the new names:
open(my $FILE, $ARGV[0]) or die "Can't open input file $ARGV[0]: $!";
while(my $line = <$FILE>)
{
	chomp $line;
	my ($orig, $collapsed) = split(/\t/, $line);
	print "$orig\t$ClusterNames{$collapsed}\n";
}
close($FILE);


# ProcessLabelName($label)
#    Turns a monolingual nonterminal label, such as "NP" or "-LRB-" or ".-NNS",
#    into the name of a label cluster, such as "CNP" or "CLRB" or "CFNNS".
sub ProcessLabelName
{
	my $label = shift(@_);
	$label =~ s/-//g;
	$label =~ s/\|/-/g;
	$label =~ s/\./F/g;
	$label =~ s/,/I/g;
	$label =~ s/:/M/g;
	$label =~ s/\`\`/LQ/g;
	$label =~ s/''/RQ/g;
	$label =~ s/\"/Q/g;
	$label =~ s/\$/S/g;
	return ("C" . $label);
}
