package CGRB::CGRBmachines;
# $Id: CGRBmachines.pm,v 1.12 2005/05/03 19:29:29 givans Exp $

use warnings;
use strict;
use Carp;
#use lib '/home/cgrb/givans/dev/lib/perl5';
#use lib '/home/cgrb/cgrblib/perl5/perl5.new';
use CGRB::CGRBjob;
use CGRB::CGRBAdmin;
use vars qw/ @ISA /;

@ISA = qw/ CGRBjob CGRB::CGRBAdmin /;

my $dbase = 'CGRBjobs';
my $debug = 0;
#print "using CGRBmachines.pm\n" if ($debug);
1;

#  sub new {
#    my $pkg = shift;

#    my $self = $pkg->generate('CGRBjobs','givans','6Acme7',@_);

#    return $self;

#  }

# sub machAdmin {
# 	my $self = shift;
	
# 	$self->{_machAdmin} ? $self->_get_machAdmin() : $self->_set_machAdmin();
# }

# sub _set_machAdmin {
# 	my $self = shift;
# 	my $admin = CGRB::CGRBAdmin->new();
# 	$self->{_machAdmin} = $admin->obj_machAdmin();
# 	$self->machAdmin();
# }

# sub _get_machAdmin {
# 	my $self = shift;
# 	return $self->{_machAdmin};
# }

sub getNextSlot {
  my $self = shift;
  my $jobType = shift;
  my $dbh = $self->dbh();
  my ($sth,$rtn);

  $sth = $dbh->prepare("select jobSlot.ID from jobRunMap, jobMaster, jobSlot where jobRunMap.JobType = ? and jobRunMap.Master = jobMaster.ID AND jobSlot.HOST = jobMaster.ID AND jobSlot.STATUS = 'I' order by RANK desc");
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

   $sth = $dbh->prepare("update jobSlot set STATUS = 'A' where ID = ?");
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
  print "CGRBmachines::checkOutNext()\n" if ($debug);
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

  $sth = $dbh->prepare("update jobSlot set STATUS = 'I' where ID = ?");
  $sth->bind_param(1,$slot);

  $rtn = $self->dbAction($dbh,$sth,3);

  if ($rtn) {
     return $rtn->[0]->[0];
  }
  return undef;

}


sub machCMD {
  my $self = shift;
  my $jobID = shift;
  my $slot = shift;
  print "CGRBmachines::machCMD:  jobID = $jobID, slot = $slot\n" if ($debug);
  my $jobType = $self->jobType($jobID);
  print "calling machCMD method\n" if ($debug);
  my $machAdmin = $self->obj_machAdmin();
  my $master = $machAdmin->slotMaster($slot);
  print "master: '$master'\n" if ($debug);
  my $runMethod = $machAdmin->runMethod($master);
  print "runMethod:  '$runMethod'\n" if ($debug);
  my $machName = $machAdmin->machName($master);
  print "machName:  '$machName'\n" if ($debug);
  my $rawCMD = $self->jobCMD($jobID);
  print "rawCMD:  '$rawCMD'\n" if ($debug);
  my $rawARGS = $self->jobArgs($jobID);
  print "rawARGS: '$rawARGS'\n" if ($debug);
#  $rawCMD .= " $rawARGS" if ($rawARGS);
  my $CMD;
  print "ref \$machAdmin = ", ref $machAdmin, "\n" if ($debug);
  if ($runMethod) {
    print "runMethod = '$runMethod'\n" if ($debug);
    if ($runMethod eq 'rsh') {
      $rawCMD .= " $rawARGS" if ($rawARGS);
      $rawCMD =~ s/\/data\/www\/html\/temp/\/mnt\/local\/cluster\/www_rslt/g;
      $CMD = "$runMethod $machName $rawCMD";
    } elsif ($runMethod eq 'shell') {
      $CMD = "$rawCMD $rawARGS";
    } elsif ($runMethod eq 'script') {
      if ($jobType == 6 || $jobType == 7) {
	my $host = `uname -n`;
	chomp($host);
	
	if ($host =~ /gac-web/) {
		if ($host eq 'gac-web.science.oregonstate.edu' || $host eq 'gac-web.cgrb.oregonstate.edu') {
			$host = 'bioinfo.cgrb.oregonstate.edu';
		}
	}
	
	$host =~ s/gac-web/bioinfo/;
	my $remote_host = $machAdmin->machAddr($master);
	$CMD = "$rawCMD -H $host -R $remote_host $rawARGS";
      } elsif ($jobType == 12) { ## ASRP BLAST jobs
	my $host = "asrp.cgrb.oregonstate.edu";
#	my $host = "128.193.224.143:8080";
#	my $host = "asrp-dev.cgrb.oregonstate.edu";
	my $remote_host = $machAdmin->machAddr($master);
	$CMD = "$rawCMD -H $host -R $remote_host $rawARGS";
      } else {
	$CMD = "$rawCMD $rawARGS";
      }
#      $CMD = "$rawCMD";
    }
  }

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
      warn("closing GUESS failed");
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
      print LOG "can't checkout slot\n" if ($debug);
      return "can't checkout slot<br>";
    }
    sleep(1);
    $slot = $self->checkOutNext($job_type_id);
  }

  my $machName = $self->obj_machAdmin()->machName($self->obj_machAdmin()->slotMaster($slot));
  $machName = lc($machName);
  print LOG "using slot # $slot ($machName)\n" if ($debug);
  return {name => $machName, slotID => $slot};
}

sub checkin_machine {
  my $self = shift;
  my $params = shift;
  my $slotID = $params->{slot_id};
  return undef unless ($slotID);

  print LOG "checking in slot $slotID\n" if ($debug);
  $self->checkIn($slotID);
}
