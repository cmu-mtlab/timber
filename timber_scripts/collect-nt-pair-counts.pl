# Author: Greg Hanneman
use strict;


# Check usage:
if($#ARGV != -1)
{
    print STDERR "Usage:\n";
    print STDERR "    cat <raw-rules> | perl $0\n";
    print STDERR "Input comes right from new rule learner\n";
    print STDERR "Output goes to standard out\n";
    exit(1);
}

# Read rule instances from standard in, one per line:
my %NTPairCounts = ();
while(my $line = <STDIN>)
{
    # Break rule line into fields:
    chomp $line;
    next if($line =~ /^Sentence/);
    my ($type, $lhs, $srcRhs, $tgtRhs, $aligns, $nodeTypes, $count) =
	split(/ \|\|\| /, $line);
    $count = 1 if($count eq "");

    # Figure out how to divide LHS label:
    my $src = "";
    my $tgt = "";
    if($lhs =~ /^\[(.*:)::(:.*)\]$/) # four colons
    {
	($src, $tgt) = ($1, $2);
    }
    elsif($lhs =~ /^\[(.*):::(.*)\]$/) # three colons
    {
	my ($left, $right) = ($1, $2);
	if($left eq "") { ($src, $tgt) = (":", $right); }
	elsif($right eq "") { ($src, $tgt) = ($left, ":"); }
	elsif(substr($left, -1) eq "-" && substr($left, -5) ne "-LRB-" &&
	      substr($left, -5) ne "-RRB-")
	{
	    ($src, $tgt) = ($left . ":", $right);
	}
	elsif(substr($right, 0, 1) eq "-" && substr($right, 0, 5) ne "-LRB-" &&
	      substr($right, 0, 5) ne "-RRB-")
	{
	    ($src, $tgt) = ($left, ":" . $right);
	}
    }
    elsif($lhs =~ /^\[(.+)::(.+)\]$/) # two colons
    {
	($src, $tgt) = ($1, $2);
    }

    # Add count to hash:
    if($src ne "" && $tgt ne "")
    {
	$NTPairCounts{"$src\t$tgt"}++;
    }
    else { print STDERR "Malformed label: '$lhs'\n"; }
}

# Now write out all the NT pair counts:
foreach my $k (keys %NTPairCounts)
{
    print "$k\t$NTPairCounts{$k}\n";
}
