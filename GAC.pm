package GAC;
# $Id: GAC.pm,v 1.24 2010/06/03 22:08:42 givans Exp $
# $Revision: 1.24 $  2004/01/05 20:18:38  givans
# Added Id and Log
#
#
use strict;
use Carp;

my $debug = 0;

1;

=head1

new() instantiates the CGRB::GAC object.

=cut

sub new {
  my $pkg = shift;

  my $obj = {
	     author	=>	"Scott Givan",
	     };

  bless $obj, $pkg;

#  return $obj;
}

sub _author {
  my $obj = shift;
  return $obj->{author};
}

=head1

author()

=cut

sub author {
  my $obj = shift;
  @_ ? $obj->{author} = shift : $obj->_author();
}

=head1

gacENV()

Sets common environment variables. Based largely on .cshrc file from GAC, so may be mostly out of date now.

=cut

sub gacENV {
  my $obj = shift;
  @_ ? $obj->_gacENV($_[0]) : $obj->_gacENV();
}

sub _gacENV {
  my $obj = shift;
  my $envFile = shift;

  if (!$envFile) {
    $envFile = "/home/cgrb/givans/lib/perl5/env.txt";
  }

  open(ENV,$envFile) or die "can't open $envFile: $!";

  my @ENV = <ENV>;

  if (!close(ENV)) {
    die "can't close ENV: $!";
  }

  foreach my $line (@ENV) {
    chomp($line);
    my($key,$value) = split /=/,$line;
    $ENV{$key} = $value;
  }

  $ENV{SAG} = "blah";

}

=head1

machLoad()

Arguments: optional loadline text

Returns: the load average as a float value.

=cut

sub machLoad {
  my $obj = shift;
  my $loadline = shift;
  my ($load,$loadavg,@load,@loadvals);
  my $bin = '/usr/bin/uptime';

	if (!$loadline) {
		print "retrieving uptime\n" if ($debug);
		open(LOAD, "$bin |") or croak("can't run $bin: $!");
	
		while (<LOAD>) {
			push(@load,$_);
		}
	
		if (!close(LOAD)) {
			croak("can't close $bin");
		}
  } else {
		print "received uptime from external call\n" if ($debug);
  	push(@load,$loadline);
  }

  if (scalar(@load) > 1) {
    croak("problem with return value of $bin:  too many lines");
  }

  $load = $load[0];

  @loadvals = split /,/, $load;

	if ($debug) {

		for (my $i = 0; $i < scalar(@loadvals); ++$i) {
			print "loadvals[$i] = '$loadvals[$i]'\n";
		}
	}

  if ($loadvals[3] =~ /load\saverage\:\s([\d\.]+)/) {
    $loadavg = $1;
	} elsif ($loadvals[2] =~ /load\saverage\:\s([\d\.]+)/) {
		$loadavg = $1;
  } else {
    return 0;
  }
	print "GAC::machLoad returning '$loadavg'\n" if ($debug);
  return $loadavg;

}

=head1

jobCheck()

Arguments: job PID

Returns: 1 if job exists, 0 if it doesn't

=cut

sub jobCheck {
  my $obj = shift;
  my $jobNum = shift;

  my $check = jobInfo($obj, $jobNum);

  if (scalar(@$check) > 1) {
    return [1];
  } else {
    return [0];
  }

}

=head1

jobInfo()

Arguments: process PID

Returns: reference to an array containing

=cut

=over 
=item userID

=item PID, etime, rsz, comm

=back

=cut

sub jobInfo {
  my $obj = shift;
  my $jobNum = shift;
  my  $query;

#  $query = "/bin/ps -eo 'user pid etime vsz comm'";
  $query = "/bin/ps -eo 'user pid etime rsz comm'";

  open(JOBS, "$query |") or warn("can't run query: $!");

  my @jobs = <JOBS>;

  close(JOBS);

  foreach my $jobLine (@jobs) {
    chomp($jobLine);
    $jobLine =~ s/^\s*//;
    my @jobValues = split /\s+/, $jobLine;
    if ($jobValues[1] == $jobNum) {
      return \@jobValues;
    }
  }

  return [0];

}

=head1

jobTime()

Arguments: process PID

Returns: runtime in format 00:00:00

=cut 

sub jobTime {
  my $obj = shift;
  my $jobNum = shift;
  my $runTime = "00:00:00";
  my $jobInfo;

  $jobInfo = jobInfo($obj,$jobNum);
  $jobInfo = 0 unless ($jobInfo);
  if ($jobInfo) {
    $runTime = $jobInfo->[2];
  }


  return $runTime;
}

=head1

jobOwner()

Arguments: process PID

Returns: userID of process owner

=cut

sub jobOwner {
  my $obj = shift;
  my $jobNum = shift;


  my $jobInfo = $obj->jobInfo($jobNum);
  if ($jobInfo) {
    return $jobInfo->[0];
  } else {
    return 0;
  }
}

=head1

jobRAM()

Arguments: process PID

Returns: amount of RAM associated with process in bytes

=cut

sub jobRAM {
	my $self = shift;
	my $jobNum = shift;
	my $ram = '0';

	my $jobInfo = $self->jobInfo($jobNum);
	if ($jobInfo) {
		$ram = $jobInfo->[3];
	}
	return $ram;
}

=head1

killJob()

Arguments: process PID

Returns: number of jobs killed

=cut

sub killJob {
  my $obj = shift;
  my $jobNum = shift;

  my $killCnt  = 0;

  $killCnt = kill 9, $jobNum;

  return $killCnt;

}

=head1

searchJobNames()

searches for processes whose cmd value match a search string

Arguments: search term string

Returns: reference to an array of PID's for processes matching search term

=cut

sub searchJobNames {
	my $self = shift;
	my $searchterm = shift;
	my @PIDs = ();
	my $pscmd = 'ps -Ao pid,cmd';

	foreach my $line (`$pscmd`) {
		if ($line =~ /(\d+)\s.+$searchterm/) {
			#push(@PIDs, (split /\d+\s/, $line)[0]);
			push(@PIDs,$1);
		}
	}
	return \@PIDs;
}

