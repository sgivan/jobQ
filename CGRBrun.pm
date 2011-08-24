package CGRBrun;
# $Id: CGRBrun.pm,v 1.2 2004/07/29 01:44:56 givans Exp $
#

use warnings;
use strict;
use Carp;
use Exporter;

1;

sub new {
  my $pkg = shift;

  my $obj = bless { }, $pkg;

  return $obj;

}

sub fastacmd {
  my $obj = shift;
  my $seqID = shift;# should be an array reference
  my $dbase = shift;
  my (%seqs,@OUT,$rtn);

  $ENV{BLASTDB} = '/dbase/NCBI/db';
  my $exe = '/local/bin/fastacmd';

  my $IDs = join ' ',@$seqID;

  open(FASTACMD, "$exe -d $dbase -s '$IDs' |") or die "can't open FASTACMD: $!";

  @OUT = <FASTACMD>;

  if (! close(FASTACMD)) {
    warn "can't close FASTACMD properly";
  }
  if ($?) {
    warn "FASTACMD returned '$?'";
  }

  $rtn = $obj->parseFASTA(\@OUT);

  return $rtn;


}

sub parseFASTA {
  my $obj = shift;
  my $seqref = shift; # should be an array ref
  my %rtn;

  my ($ID);
  foreach my $line (@$seqref) {
    chomp($line);
    if ($line =~ /^\>(.+?)\s(.+)/) {
      $ID = $1;
      $rtn{$ID}{DESC} = $2;
    } else {
      $rtn{$ID}{SEQ} .= $line;
    }
  }

  return \%rtn;

}
