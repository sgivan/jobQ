package CGRB::CGRBmachines;
# $Id: CGRBmachines.pm,v 1.18 2010/01/13 22:03:57 givans Exp $

use warnings;
use strict;
use Carp;
#use lib '/home/cgrb/givans/dev/lib/perl5';
#use lib '/home/cgrb/cgrblib/perl5/perl5.new';
use CGRB::CGRBjob;
use CGRB::CGRBAdmin;
use CGRB::QConfig;
use autodie;
use vars qw/ @ISA /;

@ISA = qw/ CGRBjob CGRB::CGRBAdmin /;

my $dbase = 'CGRBjobs';
my $debug = 0;
if ($debug) {
    open(OUT,">>",'/tmp/CGRBmachines.log');
    print OUT "+" x 50 . "\n" . localtime . "\n\n";
}
#print "using CGRBmachines.pm\n" if ($debug);
1;

sub getNextSlot {
  my $self = shift;
  my $jobType = shift;
  my $dbh = $self->dbh();
  my ($sth,$rtn);

#  $sth = $dbh->prepare("select jobSlot.ID from jobRunMap, jobMaster, jobSlot where jobRunMap.JobType = ? and jobRunMap.Master = jobMaster.ID AND jobSlot.HOST = jobMaster.ID AND jobSlot.STATUS = 'I' order by jobMaster.RANK desc");
  $sth = $dbh->prepare("select `jobSlot`.`ID` from `jobRunMap`, `jobMaster`, `jobSlot` where `jobRunMap`.`JobType` = ? and `jobRunMap`.`Master` = `jobMaster`.`ID` AND `jobSlot`.`HOST` = `jobMaster`.`ID` AND `jobSlot`.`STATUS` = 'I' order by `jobMaster`.`RANK` desc, `jobMaster`.`LOAD` asc");

  $sth->bind_param(1,$jobType);

  $rtn = $self->_dbAction($dbh,$sth,2);

  if (ref $rtn eq 'ARRAY') {
    if ($rtn->[0]) {
      return $rtn->[0]->[0];
    }
  }
  return undef;

}

sub checkOut {
  my $self = shift;
  my $slot = shift;
  my $dbh = $self->dbh();
  my ($sth,$rtn);
#  my $slotAdmin = $self->obj_slotAdmin();


#  $slotAdmin->status($slot,'A');

   $sth = $dbh->prepare("update jobSlot set `STATUS` = 'A' where `ID` = ?");
   $sth->bind_param(1,$slot);

   $rtn = $self->_dbAction($dbh,$sth,3);

   if (ref $rtn eq 'ARRAY') {
     if ($rtn->[0]) {
       return $rtn->[0]->[0];
     }
   }
   return undef;

}

sub checkOutNext {
  my $self = shift;
  my $jobType = shift;
  my $dbh = $self->dbh();
  my ($sth,$rtn,$slot);
  print OUT "CGRBmachines::checkOutNext()\n" if ($debug);
  $self->_lockTable('jobSlot write, jobRunMap read, jobMaster read');

  $slot = $self->getNextSlot($jobType);

  if ($slot) {
    $self->checkOut($slot);
  }

  $self->_unlockTable();

  if ($slot) {
    return $slot;
  } else {
    return undef;
  }

}

sub checkIn {
  my $self = shift;
  my $slot = shift;
  my $dbh = $self->dbh();
  my ($sth,$rtn);

  $sth = $dbh->prepare("update jobSlot set `STATUS` = 'I' where `ID` = ?");
  $sth->bind_param(1,$slot);

  $rtn = $self->dbAction($dbh,$sth,3);

  if ($rtn) {
     return $rtn->[0]->[0];
  }
  return undef;

}

# Determine how to run jobs on cluster nodes.
# This should be greatly simplified if we are depending on a cluster queueing system.
sub machCMD {
    my $self = shift;
    my $jobID = shift;
    my $slot = shift;
    print OUT "CGRBmachines::machCMD:  jobID = $jobID, slot = $slot\n" if ($debug);
    my $jobType = $self->jobType($jobID);
    print OUT "calling machCMD method\n" if ($debug);
    my $machAdmin = $self->obj_machAdmin();
    my $master = $machAdmin->slotMaster($slot);
    print OUT "master: '$master'\n" if ($debug);
    my $runMethod = $machAdmin->runMethod($master);
    print OUT "runMethod:  '$runMethod'\n" if ($debug);
    my $machName = $machAdmin->machName($master);
    print OUT "machName:  '$machName'\n" if ($debug);

#   jobCMD data comes from jobInfo table
    my $rawCMD = $self->jobCMD($jobID);
    print OUT "rawCMD:  '$rawCMD'\n" if ($debug);

#   jobARGS data comes from jobSubmit table
    my $rawARGS = $self->jobArgs($jobID);
    print OUT "rawARGS: '$rawARGS'\n" if ($debug);

    my $CMD;
    print OUT "ref \$machAdmin = ", ref $machAdmin, "\n" if ($debug);
  if ($runMethod) {
    print OUT "runMethod = '$runMethod'\n" if ($debug);
    # all jobs on IRCF BioCluster will have runMethod 'qbinary'
    if ($runMethod eq 'qbinary') {
        my $qconfig = CGRB::QConfig->new();
        my $qbinary = $qconfig->qbinary();
        $CMD = "$qbinary '$rawCMD $rawARGS'";
#       maybe use -sp argument to adjust job priority
#       ie, make all www jobs a low priority via -sp 5 flag
    } elsif ($runMethod eq 'rsh') {
      $rawCMD .= " $rawARGS" if ($rawARGS);
      $rawCMD =~ s/\/data\/www\/html\/temp/\/mnt\/local\/cluster\/www_rslt/g;
      $CMD = "$runMethod $machName $rawCMD";
    } elsif ($runMethod eq 'shell') {
      $CMD = "$rawCMD $rawARGS";
    } elsif ($runMethod eq 'script') {
			my $host;
			my  $toolAdmin = $self->obj_toolAdmin();
			$host = $toolAdmin->toolHost($jobType);
      if ($jobType == 6 || $jobType == 7) {
				if (!$host) {
					$host = `uname -n`;
					chomp($host);
				}
	
				if ($host =~ /gac-web/) {
					if ($host eq 'gac-web.science.oregonstate.edu' || $host eq 'gac-web.cgrb.oregonstate.edu') {
						$host = 'bioinfo.cgrb.oregonstate.edu';
					}
				}
	
				$host =~ s/gac-web/bioinfo/;
				my $remote_host = $machAdmin->machAddr($master);
				$CMD = "$rawCMD -H $host -R $remote_host $rawARGS";
      } elsif ($jobType == 12) { ## ASRP BLAST jobs
				$host = "asrp.cgrb.oregonstate.edu" unless ($host);
#				my $host = "128.193.224.143:8080";
#				my $host = "asrp-dev.cgrb.oregonstate.edu";
				my $remote_host = $machAdmin->machAddr($master);
				$CMD = "$rawCMD -H $host -R $remote_host $rawARGS";
			} elsif ($jobType == 21) {
				$host = "www.brachybase.org" unless ($host);
				my $remote_host = $machAdmin->machAddr($master);
				$CMD = "$rawCMD -H $host -R $remote_host $rawARGS";
			} elsif ($jobType == 22) {
				$host = "www.brachybase.org:8080" unless ($host);
				my $remote_host = $machAdmin->machAddr($master);
				$CMD = "$rawCMD -H $host -R $remote_host $rawARGS";
			} elsif ($jobType == 29) {
				$host = "corylus.cgrb.oregonstate.edu" unless ($host);
				my $remote_host = $machAdmin->machAddr($master);
				$CMD = "$rawCMD -H $host -R $remote_host $rawARGS";
			} elsif ($jobType == 30) {
				$host = "corylus.cgrb.oregonstate.edu:8075" unless ($host);
				my $remote_host = $machAdmin->machAddr($master);
				$CMD = "$rawCMD -H $host -R $remote_host $rawARGS";
			} else {
				$CMD = "$rawCMD $rawARGS";
      }
#      $CMD = "$rawCMD";
    } # end of if ($runMethod eq 'script') {}
  } # end of if ($runMethod) {}

  return $CMD;

}

sub guess_remotePID {
  my $obj = shift;
  my $jobID = shift;
  my $slot = shift;
  my $user = shift;
  my $machAdmin = $obj->obj_machAdmin();
  my $slotMaster = $machAdmin->slotMaster($slot);
  my $runmethod = $machAdmin->runMethod($slotMaster);
  my $addr = $machAdmin->machAddr($slotMaster);
  my $cmd = $obj->jobCMD($jobID);
  $user = 'nobody' unless ($user);
  my ($guessCMD,@lines,$pid);

  if ($runmethod eq 'rsh') {
    $guessCMD = "rsh $addr ps -eo pid,user,cmd | grep $user | grep $cmd | grep -v tcsh";

    open(GUESS,"$guessCMD |") or warn "can't open GUESS: $!";
    @lines = <GUESS>;
    close(GUESS);
    if ($?) {
      warn("closing GUESS failed: $?.  This usually is harmless.");
    }

    if (scalar(@lines) == 1) {
      if ($lines[0] =~ /\s*(\d+?)\s/) {
	$pid = $1;
	if ($pid =~ /^[\d]+$/) {
	  return $pid;
	}
      }
    }

  }
  return undef;
}

sub checkout_machine {
  my $self = shift;
  my $params = shift;
  my $job_type_id = $params->{job_type_id};
  return undef unless ($job_type_id);

  my $slot = $self->checkOutNext($job_type_id);

  my $cnt = 0;
  while (!$slot) {
    ++$cnt;
    if ($cnt > 10) {
      print OUT "can't checkout slot\n" if ($debug);
      return "can't checkout slot<br>";
    }
    sleep(1);
    $slot = $self->checkOutNext($job_type_id);
  }

  my $machName = $self->obj_machAdmin()->machName($self->obj_machAdmin()->slotMaster($slot));
  $machName = lc($machName);
  print OUT "using slot # $slot ($machName)\n" if ($debug);
  return {name => $machName, slotID => $slot};
}

sub checkin_machine {
  my $self = shift;
  my $params = shift;
  my $slotID = $params->{slot_id};
  return undef unless ($slotID);

  print OUT "checking in slot $slotID\n" if ($debug);
  $self->checkIn($slotID);
}
