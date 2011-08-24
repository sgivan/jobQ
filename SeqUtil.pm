package CGRB::SeqUtil;
# $Id: SeqUtil.pm,v 1.5 2010/06/03 22:03:05 givans Exp $
use warnings;
use strict;
use Carp;

1;


sub new {
  my $pkg = shift;
  my $self;

  $self = bless {},$pkg;

  return $self;

}

sub seqLength {
  my $self = shift;
  my $sequence = shift;
  my $seq;

  if ($sequence =~ /\>.+?[\012\015](.+)$/s) {
    $seq = $1;
  } else {
    $seq = $sequence;
  }
  $seq =~ s/[\012\015]//g;

  return length($seq);
}

sub seqChop {
	my $self = shift;
	my $seq = shift;
	my $len = shift;
	my ($rtn);

	for (my $i = 0; $i < length($seq); $i += $len) { 
		$rtn .= substr $seq, $i, $len;
		$rtn .= "\n";
	}
	return $rtn;
}

sub seqCount {
  my $self = shift;
  

}
