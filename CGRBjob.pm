package CGRBjob;
# $Id: CGRBjob.pm,v 3.19 2008/07/25 20:32:45 givans Exp $

use strict;
use Carp;
use warnings;
#use DBI;
#use lib '/home/cgrb/givans/dev/lib/perl5';
#use lib '/home/cgrb/cgrblib/perl5/perl5.new';
use CGRB::CGRBDB; # this pulls in DBI methods
use vars qw/ @ISA $AUTOLOAD /;

@ISA = qw/ CGRBDB /;
my $debug = 0;
my $fh;

if ($debug) {
  printlog("+" x 25);
  printlog(scalar(localtime));
}

1;


sub new {
  my ($pkg) = shift;
#  print "creating CGRBjob object\n";
  my $db = 'CGRBjobs';
  my $user = 'queue';
  my $password = 'CGRBq';
#  print "creating a '$pkg' object\n";
  printlog("Establishing connection to CGRBjobs") if ($debug);

#  my $CGRBjob = $pkg->SUPER::new($db, $user, $password);
  my $CGRBjob = $pkg->SUPER::generate($db, $user, $password,@_);

  $CGRBjob->{_tables} = ['jobInfo', 'jobQueue', 'jobRun', 'jobComplete', 'jobSubmit', 'jobMaster', 'jobSRC'];

  printlog("Returning CGRBjob handle") if ($debug);

  return $CGRBjob;

}

# sub AUTOLOAD {
#   printlog("AUTOLOAD was called '$AUTOLOAD'") if ($debug);
# }


sub submitJob { ## this should be the method used to submit jobs to the queue
  my $obj = shift;
  my $type = shift;
  my $args = shift;
  my $user = shift;
  my $submitSRC = shift;
  my $priority = shift;
	my $ip_addr = shift || 'na';
#  my $dbh = $obj->{_dbh};
  my $dbh = $obj->dbh();
  my ($sth,$jobID,$rtn);

  $user = 'anonymous' unless ($user);
  $submitSRC = 'web' unless ($submitSRC);
  $priority = 1 unless ($priority);
 
  if ($debug) {
    printlog("CGRBjob::submitJob  type = '$type', flags = '$args', submitSRC = '$submitSRC', user = '$user', priority = '$priority', ip_addr = '$ip_addr'");
    printlog("locking table jobSubmit");
  }

  my $lock = $obj->_lockTable('jobSubmit write');
  if ($debug) {
    if (!$lock) {
      printlog("jobSubmit is locked");
    } else {
      printlog("could not lock jobSubmit: $lock");
    }
  }

  $sth = $dbh->prepare("insert into jobSubmit (`Type`, `Args`, `User`, `Time`, `SubmitSRC`, `Priority`, `IP_addr`) values (?,?,?,now(),?,?,?)");
  $sth->bind_param(1,$type);
  $sth->bind_param(2,$args);
  $sth->bind_param(3,$user);
  $sth->bind_param(4,$submitSRC);
  $sth->bind_param(5,$priority);
	$sth->bind_param(6,$ip_addr);
  $rtn = $obj->_dbAction($dbh,$sth,1);

  $jobID = $obj->lastJob();

  printlog("unlocking tables") if ($debug);

  my $unlock = $obj->_unlockTable();
  if ($debug) {
    if (!$unlock) {
      printlog("tables were unlocked successfully");
    } else {
      printlog("could not unlock tables: $unlock");
    }
  }
  printlog("returning new jobID: '$jobID'") if ($debug);
  return $jobID;

}

# Check to see if there are jobs that have been submitted, but not queued yet.
# Take these jobs and change their status to "Q" (Queued)
# Basically, change Submitted jobs to Queued jobs.
sub jobQ {
  my $obj = shift;
#  my $jobID = shift;
#  my $dbh = $obj->{_dbh};
  my $dbh = $obj->dbh();
  my ($sth,$rtn);

  if ($debug) {
    my ($p,$f,$l) = caller();
    printlog("jobQ was called: $p, $f, $l");
  }

  my $newIDs = $obj->checkSubmit($obj);# number of jobs in 'S' state

  if ($newIDs) {
    $sth = $dbh->prepare("insert into jobQueue (`jobID`, `Time`) values (?, now())");

    foreach my $jobID (@$newIDs) {
      printlog("\tqueueing $jobID") if ($debug);
      $sth->bind_param(1,$jobID);
      $rtn = $obj->_dbAction($dbh,$sth,1);

      printlog("\tchanging status of job $jobID to 'Q'") if ($debug);
      my $statusChange = $obj->jobStatus($jobID,'Q');
      return $statusChange if ($statusChange);
    }
    return $newIDs;
  } else {
    printlog("No jobs to queue") if ($debug);
    return 0;
  }

}

sub job_deQ {
  my $obj = shift;
  my $jobID = shift;
#  my $dbh = $obj->{_dbh};
  my $dbh = $obj->dbh();
  my ($sth,$rtn);

  $sth = $dbh->prepare("delete from jobQueue where `jobID` = ?");
  $sth->bind_param(1,$jobID);
  $rtn = $obj->_dbAction($dbh,$sth,4);

  if (ref $rtn eq 'ARRAY') {
    return $rtn->[0]->[0];
  } else {
    return 0;
  }
}

sub job_delete {
    my $self = shift;
    my $jobID = shift;
    my $dbh = $self->dbh();
    my ($sth,$rtn) = ();

    $sth = $dbh->prepare("delete from jobSubmit where `ID` = ?");
    $sth->bind_param(1,$jobID);
    $rtn = $self->_dbAction($dbh,$sth,4);

    $sth = $dbh->prepare("delete from jobRun where `jobID` = ?");
    $sth->bind_param(1,$jobID);
    $rtn = $self->_dbAction($dbh,$sth,4);

    $self->job_deQ($jobID);

#    if (ref $rtn eq 'ARRAY') {
#        return $rtn->[0]->[0];
#    } else {
#        return 0;
#    }
    return 1;
}

# return reference to array containing the job ID's of
# submitted jobs (ie, jobs that haven't run yet)
sub checkSubmit {
  my $obj = shift;
#  my $dbh = $obj->{_dbh};
  my $dbh = $obj->dbh();
  my ($sth,$rtn);
  my @jobIDs;
  if ($debug) {
    my ($p,$f,$l) = caller();
    printlog("checkSubmit called: $p, $f, $l");
  }

  $sth = $dbh->prepare("select `ID` from jobSubmit where `Status` = 'S'");
  $rtn = $obj->_dbAction($dbh,$sth,2);
  
  if (ref $rtn eq 'ARRAY') {

    foreach my $r (@$rtn) {
      push(@jobIDs, $r->[0]);
    }
  }

  return \@jobIDs;

}

sub jobStatus { ## accessor method
  my $obj = shift;
  my $jobID = shift;
  my $status = shift;
  $status ? return $obj->_jobStatus($jobID, $status) : $obj->_jobStatus($jobID);
}

sub _jobStatus {
  my $obj = shift;
  my $jobID = shift;
  my $status = shift;
#  my $dbh = $obj->{_dbh};
  my $dbh = $obj->dbh();
  my ($sth,$rtn);

  if ($debug) {
    my ($p,$f,$l) = caller();
    printlog("_jobStatus called.  p: $p, f: $f, l: $l");
    my $reftype = ref $obj;
    printlog("passed object has type '$reftype'");
    printlog("_jobStatus called for jobID = '$jobID'");
  }

  if ($status) {
    printlog("setting status of job $jobID to '$status'") if ($debug);
    $sth = $dbh->prepare("update jobSubmit set `Status` = ? where `ID` = ?");
    $sth->bind_param(1,$status);
    $sth->bind_param(2,$jobID);

    $rtn = $obj->_dbAction($dbh,$sth,3);
  } else {
    printlog("retrieving status of job $jobID") if ($debug);
    $rtn = $obj->_sselect('Status','jobSubmit','ID',$jobID);
  }
  printlog("rtn has reftype: " . ref($rtn)) if ($debug);
  if (ref $rtn eq 'ARRAY') {
    return $rtn->[0]->[0];
  } else {
#    return $rtn;
    return undef;
  }
}

sub checkQ {
  my $obj = shift;
#  my $dbh = $obj->{_dbh};
  my $dbh = $obj->dbh();
  my (@jobIDs,$rtn) = ();
  if ($debug) {
    my ($p,$f,$l) = caller();
    printlog("checkQ called: $p, $f, $l");
  }

  my $sth = $dbh->prepare("select `jobID` from jobQueue");

  $rtn = $obj->_dbAction($dbh,$sth,2);

  if (ref $rtn eq 'ARRAY') {
    foreach my $r (@$rtn) {
      push(@jobIDs, $r->[0]);
    }
  }

  printlog("\n\ncheckQ query returned '@jobIDs'\n\n") if ($debug);


#  return \@jobIDs;
  return @jobIDs;

}

# return number of queued jobs
sub jobQs {
    my $obj = shift;
    my $jobcnt = 0;
    if ($debug) {
        my ($p,$f,$l) = caller();
        printlog("jobQs called: $p, $f, $l");
    }

    my @queuedJobs = $obj->checkQ();

    $jobcnt = @queuedJobs;

    printlog("returning '$jobcnt' from jobQs\n\n") if ($debug);

    return $jobcnt;
}

# get job ID and priority from jobQueue
# returns reference to a 2-element array
sub getNextJob {
    my $obj = shift;
    my $jobID = shift;
    printlog("retrieving next job") if ($debug);
    my $dbh = $obj->dbh();
    my ($sth,$rtn,$rslt);

    if (!$jobID) {
        $sth = $dbh->prepare("select Q.jobID, S.Priority from jobQueue Q, jobSubmit S where Q.jobID = S.ID order by S.Priority, Q.jobID");
    } else {
        $sth = $dbh->prepare("select Q.jobID, S.Priority from jobQueue Q, jobSubmit S where Q.jobID = S.ID AND S.ID > ? order by S.Priority, Q.jobID");
        $sth->bind_param(1,$jobID);
    }
    $rtn = $obj->_dbAction($dbh,$sth,2);
    if (ref $rtn eq 'ARRAY') {
        $rslt = $rtn->[0]->[0];
    }

   if ($rslt) {
        printlog("next job is '$rslt'") if ($debug);
        return $rslt;
   } else {
        printlog("can't retrieve next job") if ($debug);
        return 0;
   }

}

sub getJobParams {
  my $obj = shift;
  my $jobIDs = shift;
#  my $dbh = $obj->{_dbh};
  my $dbh = $obj->dbh();
  printlog("preparing to run jobs") if ($debug);

#  my $queuedJobs = $obj->checkQ();
  my @queuedJobs = $obj->checkQ();

#  foreach my $jobID (@$queuedJobs) {
  foreach my $jobID (@queuedJobs) {
    next if ($obj->jobSRC($jobID) eq 'PSD');

    printlog("getting parameters for job '$jobID'") if ($debug);
    my $cmd = $obj->jobCMD($jobID);
    my $args = $obj->jobArgs($jobID);
    printlog("cmd: '$cmd', flags: '$args'") if ($debug);

  }

}

sub getJobOutput {
  my $obj = shift;
  my $jobID = shift;
#  my $dbh = $obj->{_dbh};
  my $dbh = $obj->dbh();
  my $rtn;
  printlog("retrieving job output for job '$jobID'") if ($debug);

  my $output = $obj->_sselect('stdout','jobComplete','jobID',$jobID);
  if (ref $output eq 'ARRAY') {
    $rtn = $output->[0]->[0];
  } else {
    $rtn = 0;
  }
#  printlog("returning output: '$rtn'") if ($debug);
  return $rtn;
}

sub jobRun {
  my $obj = shift;
  my $jobID = shift;
  my $dbh = $obj->dbh();
  my ($sth,$rtn);
  if ($debug) {
    my ($p,$f,$l) = caller();
    printlog("jobRun called:  $p, $f, $l");
  }

  my $deQ = $obj->job_deQ($jobID);
  return $deQ if ($deQ);

  $sth = $dbh->prepare("insert into jobRun (`jobID`,`Time`) values (?, now())");
  $sth->bind_param(1,$jobID);
  $rtn = $obj->_dbAction($dbh,$sth,1);

  printlog("changing status of job $jobID to 'R'") if ($debug);
  my $statusChange = $obj->jobStatus($jobID, 'R');
  return $statusChange if ($statusChange);

  return 0;
}

sub job_derun {
  my $obj = shift;
  my $jobID = shift;
#  my $dbh = $obj->{_dbh};
  my $dbh = $obj->dbh();
  my ($sth,$rtn);

  $sth = $dbh->prepare("delete from jobRun where `jobID` = ?");
  $sth->bind_param(1,$jobID);

  $rtn = $obj->_dbAction($dbh,$sth,4);

  if (ref $rtn eq 'ARRAY') {
    return $rtn->[0]->[0];
  } else {
    return 0;
  }
}

sub finishJob {
  my $obj = shift;
  my $jobID = shift;
  my $jobMaster = $obj->jobMaster($jobID);
  my $stdout = shift;
  my $signal = shift;
#  my $dbh = $obj->{_dbh};
  my $dbh = $obj->dbh();
  my ($sth,$rtn,$status,$statusChange,$derun);
  $status = $obj->jobStatus($jobID);

  if ($debug) {
    my ($p,$f,$l) = caller();
    printlog("finishJob called:  $p, $f, $l");
  }
  printlog("removing job from jobRun table") if ($debug);
  $derun = $obj->job_derun($jobID);

#   unless ($status eq 'E' || $status eq 'K') {
#     printlog("changing status of job to 'C' in jobSubmit table") if ($debug);
#     $statusChange = $obj->jobStatus($jobID, 'C');
#   }

  $sth = $dbh->prepare("insert into jobComplete (`jobID`, `signal`, `stdout`, `jobMaster`, `Time`, `ElapsedTime`) values (?, ?, ?, ?, now(), ?)");
  $sth->bind_param(1,$jobID);
  $sth->bind_param(2,$signal);
  $sth->bind_param(3,$stdout);
  $sth->bind_param(4,$jobMaster);
  $sth->bind_param(5,"00:00:00");

  $rtn = $obj->_dbAction($dbh,$sth,1);

   unless ($status eq 'E' || $status eq 'K') {
     printlog("changing status of job to 'C' in jobSubmit table") if ($debug);
     $statusChange = $obj->jobStatus($jobID, 'C');
   }

  if (ref $rtn eq 'ARRAY') {
    return $rtn->[0]->[0];
  } else {
    return 0;
  }
}

sub job_isComplete {
  my $obj = shift;
  my $jobID = shift;
  if ($debug) {
    my ($p,$f,$l) = caller();
    printlog("job_isComplete called:  $p, $f, $l");
    printlog("checking status of job '$jobID'");
    printlog("passed object has type: " . ref($obj));
  }

  my $status = $obj->jobStatus($jobID);
  if ($status && ($status eq 'C' || $status eq 'E' || $status eq 'K')) {
    printlog("returning '1' for status") if ($debug);
    return 1;
  } else {
    printlog("returning '0' for status") if ($debug);
    return 0;
  }

}

sub jobPID {
  my $obj = shift;
  my $jobID = shift;

  @_ ? $obj->_jobPID($jobID, shift) : $obj->_jobPID($jobID);

}

sub _jobPID {
  my $obj = shift;
  my $jobID = shift;
  my $pid = shift;
#  my $dbh = $obj->{_dbh};
  my $dbh = $obj->dbh();
  my ($rtn,$sth);

  if ($pid) {
    $sth = $dbh->prepare("update jobRun set `pid` = ? where `jobID` = ?");
    $sth->bind_param(1,$pid);
    $sth->bind_param(2,$jobID);
    $rtn = $obj->_dbAction($dbh,$sth,3);
  } else {
    $pid = $obj->_sselect('pid','jobRun','jobID',$jobID);
    if (ref $pid eq 'ARRAY') {
      $rtn = $pid->[0]->[0];
    } else {
      $rtn = 0;
    }
  }

  return $rtn;
}

sub job_remotePID {
  my $obj = shift;
  my $jobID = shift;
  my $remotePID = shift;

  if ($jobID) {
    $remotePID ? $obj->_set_remotePID($jobID,$remotePID) : $obj->_get_remotePID($jobID);
  } else {
    return 0;
  }
}

sub _set_remotePID {
  my $obj = shift;
  my $jobID = shift;
  my $remotePID = shift;
  my $dbh = $obj->dbh();
  my ($sth,$rtn);

  $sth = $dbh->prepare("update jobRun set `r_pid` = ? where `jobID` = ?");
  $sth->bind_param(1,$remotePID);
  $sth->bind_param(2,$jobID);

  $rtn = $obj->_dbAction($dbh,$sth,3);

  if (ref $rtn eq 'ARRAY') {
    return $rtn->[0]->[0];
  } else {
    return 0;
  }
}

sub _get_remotePID {
  my $obj = shift;
  my $jobID = shift;
  my $dbh = $obj->dbh();
  my ($sth,$rtn);

  $sth = $dbh->prepare("select `r_pid` from jobRun where `jobID` = ?");
  $sth->bind_param(1,$jobID);

  $rtn = $obj->_dbAction($dbh,$sth,2);

  if (ref $rtn eq 'ARRAY') {
    return $rtn->[0]->[0];
  } else {
    return undef;
  }
}

sub jobSlot {
  my $obj = shift;
  my $jobID = shift;
  my $jobSlot = shift;

  $jobSlot ? $obj->_set_jobSlot($jobID,$jobSlot) : $obj->_get_jobSlot($jobID);

}

sub _set_jobSlot {
  my $obj = shift;
  my $jobID = shift;
  my $jobSlot = shift;
  my $dbh = $obj->dbh();
  my ($sth,$rtn);

  $sth = $dbh->prepare("update jobRun set `jobSlot` = ? where `jobID` = ?");
  $sth->bind_param(1,$jobSlot);
  $sth->bind_param(2,$jobID);

  $rtn = $obj->_dbAction($dbh,$sth,3);

  if (ref $rtn eq 'ARRAY') {
    return $rtn->[0]->[0];
  } else {
    return undef;
  }
}

sub _get_jobSlot {
  my $obj = shift;
  my $jobID = shift;
  my $dbh = $obj->dbh();
  my ($sth,$rtn);

  $sth = $dbh->prepare("select `jobSlot` from jobRun where `jobID` = ?");
  $sth->bind_param(1,$jobID);

  $rtn = $obj->_dbAction($dbh,$sth,2);

  if (ref $rtn eq 'ARRAY') {
    return $rtn->[0]->[0];
  } else {
    return undef;
  }
}

sub jobActive {
  my $obj = shift;
  if ($debug) {
    my ($p,$f,$l) = caller();
    printlog("jobActive called:  $p, $f, $l");
  }
  my @jobs;
  my $activeJobs = $obj->_sselect('jobID','jobRun','','','jobID');

  if (ref $activeJobs eq 'ARRAY') {

    foreach my $r (@$activeJobs) {
      push(@jobs,$r->[0]);
    }
  }

  if (scalar(@jobs) > 0) {
    return \@jobs;
  } else {
    return [];
  }
}

sub jobActiveCount {
  my $obj = shift;

  my $activeJobs = $obj->jobActive();
  my $jobCount = @$activeJobs;

  return $jobCount;
}

sub jobInfo {
  my $obj = shift;
  my $jobID = shift;
#  my $dbh = $obj->{_dbh};
  my $dbh = $obj->dbh();
  my ($sth,$rtn);

  $sth = $dbh->prepare("select S.ID, I.Name, S.Time, S.User, S.Status from jobSubmit S, jobInfo I where Type = I.ID AND S.ID = ?");
  $sth->bind_param(1,$jobID);
  $rtn = $obj->_dbAction($dbh,$sth,2);

  if (ref $rtn eq 'ARRAY') {
    return $rtn->[0];
  } else {
    return undef;
  }

}

sub jobList {
  my $self = shift;
  $self->joblist();
}

sub joblist {
  my $obj = shift;
#  my $sort = shift; # optional
#  my $dir = shift; # optional
   my $options = shift;
   my $sort = $options->{sort} || 'S.ID';
   my $dir = $options->{dir} || 'desc';
   my $limit = $options->{limit} || 10;

  my $dbh = $obj->dbh();
  my ($order,$sth,$rtn);

#    if ($sort && $dir) {
#      $order = "order by $sort $dir"; ## $sort can be any column header, $dir should be either asc or desc
#    } elsif ($sort) {
#      $order = "order by $sort";
#    } else {
#      $order = "order by S.ID asc";
#    }

#  $sth = $dbh->prepare("select S.ID, I.Name, S.Time, S.User, S.Status from jobSubmit S, jobInfo I where Type = I.ID $order");
  $sth = $dbh->prepare("select S.ID, I.Name, S.Time, S.User, S.Status, S.IP_addr from jobSubmit S, jobInfo I where Type = I.ID order by $sort $dir LIMIT ?");

   $sth->bind_param(1,$limit,4);

  $rtn = $obj->_dbAction($dbh,$sth,2);

  if (ref $rtn eq 'ARRAY') {
    return $rtn;
  } else {
    return undef;
  }

}

sub jobUser {
	my $self = shift;
	my $jobID = shift;
	return undef unless ($jobID);
	
	my $jobInfo = $self->jobInfo($jobID);

	if ($jobInfo && ref($jobInfo) eq 'ARRAY') {
		return $jobInfo->[3];
	}
	
}

sub joblistByUser {
  my $obj = shift;
  my $user = shift; # this is required
  my $options = shift;
  my $sort = $options->{sort} || 'S.ID';
  my $dir = $options->{dir} || 'desc';
  my $limit = $options->{limit} || 10;
  my $dbh = $obj->dbh();
  my ($sth,$rtn);

  $sth = $dbh->prepare("select S.ID, I.Name, S.Time, S.User, S.Status from jobSubmit S, jobInfo I where Type = I.ID AND User = ? order by $sort $dir LIMIT ?");

  $sth->bind_param(1,$user);
  $sth->bind_param(2,$limit, 4);

  $rtn = $obj->_dbAction($dbh,$sth,2);
  if (ref $rtn eq 'ARRAY') {
    return $rtn;
  } else {
    return undef;
  }

}

sub joblistActiveByUser {
	my $self = shift;
	my $user = shift;
	my $options = shift;
	my $dbh = $self->dbh();
	my ($sth,$rtn);
	return undef unless ($user);
	
	#$sth = $dbh->prepare("select R.jobID from `jobRun` R, `jobSubmit` S where S.User = ? AND S.ID = R.jobID");
	$sth = $dbh->prepare("select ID from `jobSubmit` S where S.User = ? AND S.Status = 'R'");
	$sth->bind_param(1,$user);
	
	$rtn = $self->dbAction($dbh,$sth,2);

    my @jobs = ();
	if (ref($rtn) eq 'ARRAY') {
	
		#my @jobs = ();
		foreach my $row (@$rtn) {
			push(@jobs,$row->[0]);
		}
	
		return \@jobs;
	}# else {
#		return undef;
#	}
    return \@jobs;
}

sub joblistByType {
  my $obj = shift;
  my $type = shift; # this is required
  my $options = shift;
  my $sort = $options->{sort} || 'S.ID';
  my $dir = $options->{dir} || 'desc';
  my $limit = $options->{limit} || 10;
  my $user = $options->{user} || undef;
  my $dbh = $obj->dbh();
  my ($sth,$rtn,$qstring);

  $qstring = "select S.ID, I.Name, S.Time, S.User, S.Status from jobSubmit S, jobInfo I where Type = ? AND Type = I.ID ";
  $qstring .= "AND User = ? " if ($user);
  $qstring .= "order by $sort $dir LIMIT ?";

  $sth = $dbh->prepare($qstring);
#  $sth = $dbh->prepare("select S.ID, I.Name, S.Time, S.User, S.Status from jobSubmit S, jobInfo I where Type = ? AND Type = I.ID order by $sort $dir LIMIT ?");

  $sth->bind_param(1,$type);
  if ($user) {
    $sth->bind_param(2,$user);
    $sth->bind_param(3,$limit,4);
  } else {
    $sth->bind_param(2,$limit, 4);
  }

  $rtn = $obj->_dbAction($dbh,$sth,2);
  if (ref $rtn eq 'ARRAY') {
    return $rtn;
  } else {
    return undef;
  }

}

sub lastjobsList {
  my $self = shift;
  my $numJobs = shift;
  my $dbh = $self->dbh();
  my ($sth,$rtn,$max,$min);

  $max = $self->lastJob();
  $min = $max - $numJobs;

  $sth = $dbh->prepare("select S.ID, I.Name, S.Time, S.User, S.Status from jobSubmit S, jobInfo I where Type = I.ID AND S.ID > ? order by S.ID");
  $sth->bind_param(1,$min);

  $rtn = $self->_dbAction($dbh,$sth,2);

  if (ref $rtn eq 'ARRAY') {
    return $rtn;
  } else {
    return [0];
  }

}

sub killJob {
  my $self = shift;
  my $jobID = shift;
  my $method;

  eval {
    require CGRB::CGRBAdmin;
  };
  return undef if ($@);
  my $admin = CGRB::CGRBAdmin->new();
  my $machAdmin = $admin->obj_machAdmin();
  my $slotAdmin = $admin->obj_slotAdmin();
  $method = $machAdmin->runMethod($slotAdmin->host($self->jobSlot($jobID)));
  if ($method eq 'rsh') {
    my $machAddr = $machAdmin->machAddr($slotAdmin->host($self->jobSlot($jobID)));
    my $r_pid = $self->job_remotePID($jobID);
    if ($r_pid) {
      open(KILL,"$method $machAddr kill -9 $r_pid |") or warn("can't kill process $r_pid on $machAddr");
      close(KILL);
      if ($?) {
	warn("KILL may have faild for process $r_pid on $machAddr") if ($?);
      } else {
	$self->jobStatus($jobID,'K');
	return undef;
      }
    }
  }
  return -1;
}


sub jobPriority {
  my $obj = shift;
  my $jobID = shift;
  my $priority = shift;

  $priority ? $obj->_jobPriority($jobID,$priority) : $obj->_jobPriority($jobID);
}

sub _jobPriority {
  my $obj = shift;
  my $jobID = shift;
  my $priority = shift;
#  my $dbh = $obj->{_dbh};
  my $dbh = $obj->dbh();
  my ($sth,$rtn);
  
  if ($priority) {
    $sth = $dbh->prepare("update jobSubmit set `Priority` = ? where `ID` = ?");
    $sth->bind_param(1,$priority);
    $sth->bind_param(2,$jobID);
    $rtn = $obj->_dbAction($dbh,$sth,3);
 #   $rslt = $rtn;
  } else {
    $sth = $dbh->prepare("select `Priority` from jobSubmit where `ID` = ?");
    $sth->bind_param(1,$jobID);
    $rtn = $obj->_dbAction($dbh,$sth,2);
#    $rslt = $rtn->[0]->[0];
  }
  
  if (ref $rtn eq 'ARRAY') {
	  return $rtn->[0]->[0];
  } else {
	  return undef;
  }

#  return $rslt;
}

sub jobSRC { ## I should change this to get/set jobSRC
  my $obj = shift;
  my $jobID = shift;
#  my $dbh = $obj->{_dbh};
  my $dbh = $obj->dbh();
  printlog("CGRBjob::jobSRC  retrieving SRC for job '$jobID'") if ($debug);

  my $sth = $dbh->prepare("select `SubmitSRC` from jobSubmit where `ID` = ?");
  return $dbh->errstr unless ($sth);
  return $dbh->errstr unless ($sth->execute($jobID));

  my $r = $sth->fetchrow_arrayref;
  printlog("CGRBjob::jobSRC  returning SRC '$r->[0]'") if ($debug);

  return $r->[0];

}

sub jobCMD {
  my $obj = shift;
#  my $dbh = $obj->{_dbh};
  my $dbh = $obj->dbh();
  my $jobID = shift;
  my ($sth,$rtn);
  printlog("CGRBjob::jobCMD  retrieving CMD for job '$jobID'") if  ($debug);

  $sth = $dbh->prepare("select I.CMD from jobInfo I, jobSubmit S where S.Type = I.ID AND S.ID = $jobID");
#  return $dbh->errstr unless ($sth);
#  return $dbh->errstr unless ($sth->execute);
#  return $sth->fetchrow_arrayref->[0];

  $rtn = $obj->_dbAction($dbh,$sth,2);
  if (ref $rtn eq 'ARRAY') {
    printlog("CGRBjob::jobCMD  returning CMD for job $jobID") if ($debug);
    return $rtn->[0]->[0];
  } else {
    return undef;
  }

}

sub jobArgs {
  my $obj = shift;
  my $jobID = shift;
  printlog("retrieving flags for job '$jobID'") if ($debug);

#  my $args = $obj->_sselect($obj->{_dbh},'Args','jobSubmit','ID',$jobID);
  my $args = $obj->_sselect('Args','jobSubmit','ID',$jobID);

  if (ref $args eq 'ARRAY') {
    printlog("returning args '$args->[0]->[0]'") if ($debug);
    return $args->[0]->[0];
  } else {
    return undef;
  }
}

sub jobDIR { ## this isn't used
  my $obj = shift;
  my $jobID = shift;
  printlog("retrieving DIR for job '$jobID'") if ($debug);

#  my $DIR = $obj->_sselect($obj->{_dbh},'DIR','jobInfo','ID',$jobID);
  my $DIR = $obj->_sselect('DIR','jobInfo','ID',$jobID);

  if (ref $DIR eq 'ARRAY') {
    return $DIR->[0]->[0];
  } else {
    return undef;
  }
}

sub jobFileRoot {
  my $obj = shift;
  my $jobID = shift;
  if ($debug) {
    my ($p,$f,$l) = caller();
    printlog("jobFileRoot called.  p: $p, f: $f, l: $l");
#    printlog("obj is '" . ref($obj) . "'");
  }

  $_[0] ? $obj->_jobFileRoot($jobID,$_[0]) : $obj->_jobFileRoot($jobID);

}

sub _jobFileRoot {
  my $obj = shift;
  my $jobID = shift;
  my $fileRoot = shift;
#  my $dbh = $obj->{_dbh};
  my $dbh = $obj->dbh();
  my ($sth,$rslt);
  if ($debug) {
    my ($p,$f,$l) = caller();
    printlog("_jobFileRoot called.  p: $p, f: $f, l: $l");
    printlog("_jobFileRoot: jobID = '$jobID'");
    printlog("obj is '" . ref($obj) . "'");
    printlog("dbh is '" . ref($dbh) . "'");
  }

  if ($fileRoot) {
    $sth = $dbh->prepare("update jobSubmit set `FileRoot` = ? where `ID` = ?");
    $sth->bind_param(1,$fileRoot);
    $sth->bind_param(2,$jobID);
    $rslt = $obj->_dbAction($dbh,$sth,3);
    return $rslt;
  } else {
    $sth = $dbh->prepare("select `FileRoot` from jobSubmit where `ID` = ?");
    $sth->bind_param(1,$jobID);
    $rslt = $obj->_dbAction($dbh,$sth,2);
    printlog("returning '" . $rslt->[0]->[0] . "'") if ($debug && $rslt);
    return $rslt->[0]->[0] if ($rslt);
  }
  return "ERROR";
}

sub jobMaster {
  my $obj = shift;
  my $jobID = shift;
#  my $dbh = $obj->{_dbh};
  my $dbh = $obj->dbh();
  printlog("returning jobMaster for job $jobID") if ($debug);

#  my $jobMaster = $obj->_sselect($dbh, 'jobMaster', 'jobRun', 'jobID', $jobID);
  my $jobMaster = $obj->_sselect('jobMaster', 'jobRun', 'jobID', $jobID);

  if (ref $jobMaster eq 'ARRAY') {
    $obj->{_jobMaster} = $jobMaster->[0]->[0];
    return $jobMaster->[0]->[0];
  } else {
    return undef;
  }
}

sub jobLink { ## accessor method for _jobLink
  my $obj = shift;
  my $jobID = shift;

  $_[0] ? $obj->_jobLink($jobID, $_[0]) : $obj->_jobLink($jobID);

}

sub _jobLink {
  my $obj = shift;
  my $jobID = shift;
  my $jobLink = shift;
#  my $dbh = $obj->{_dbh};
  my $dbh = $obj->dbh();

  if ($debug) {
    my ($p,$f,$l) = caller();
    printlog("_jobLink called: $p, $f, $l");
    printlog("setting link to '$jobLink'") if ($jobLink);
  }

  if (!$jobLink) {
    my $link = $obj->_sselect('Link','jobSubmit','ID',$jobID);
    if (ref $link eq 'ARRAY') {
      return $link->[0]->[0];
    } else {
      return undef;
    }
  }

  my $sth = $dbh->prepare("update jobSubmit set `Link` = ? where `ID` = ?");
  $sth->bind_param(1,$jobLink);
  $sth->bind_param(2,$jobID);
  my $rtn = $obj->_dbAction($dbh,$sth,3);
  if ($rtn) {
    return $rtn->[0]->[0];
  } else {
    $obj->{_jobLink} = $jobLink;
    return undef;
  }

}

sub jobType {
  my $self = shift;
  my $jobID = shift;
  my $dbh = $self->dbh();
  my ($sth,$rtn);

  $sth = $dbh->prepare("select `Type` from jobSubmit where `ID` = ?");
  $sth->bind_param(1,$jobID);

  $rtn = $self->_dbAction($dbh,$sth,2);

  if (ref $rtn eq 'ARRAY') {
    return $rtn->[0]->[0];
  }
  return undef;
}

sub jobTypes {
  my $obj = shift;
#  my $dbh = $obj->{_dbh};
  my $dbh = $obj->dbh();
  my ($sth,$rtn);

  $sth = $dbh->prepare("select `ID`, `CMD`, `OUT`, `DIR`, `Name`, `ExitCode`  from jobInfo");
  $rtn = $obj->_dbAction($dbh,$sth,2);
  if (ref $rtn eq 'ARRAY') {
    return $rtn;
  } else {
    return undef;
  }
}

sub lastJob {
  my $self = shift;
  my $dbh = $self->dbh();
  my ($sth,$rtn);

  $sth = $dbh->prepare("select max(`ID`) from jobSubmit");
  $rtn = $self->_dbAction($dbh,$sth,2);

  if (ref $rtn eq 'ARRAY') {
    return $rtn->[0]->[0];
  } else {
    return undef;
    }
}

sub printlog {
  $fh = _openlog($fh);
  my $old_fh = select($fh);
  $| = 1;

  my $mssg = shift;

  print $fh "$mssg\n";

  select($old_fh);

  return undef;
}

sub _openlog {
  my $tempFH;

  if (!defined($fh)) {

    eval {
      require FileHandle;
    };

    if ($@) {
      croak ("can't load Filehandle module: $@");
    }

    $tempFH = new FileHandle ">/home/cgrb/givans/dev/bin/logs/CGRBjob.log";
    if (!defined($tempFH)) {
      croak ("can't open CGRBjob.log");
    }

    print $tempFH "-" x 50, "\nCGRBjob.pm:  ", scalar(localtime), "\n\n";

    return $tempFH;

  } else {
#    print $fh "no need to reopen CGRBlog\n" if ($debug);
    return $fh;

  }

}

=head1 NAME

 CGRBjob - module for submitting jobs to the CGRB Job Queuing System

=head1 SYNOPSIS

 use CGRB::CGRBjob;

 my $Q = CGRBjob->new();

 my $jobID = $Q->submitJob(1, $args, $options, $username, $submission_source, $priority);

 while (! $Q->job_isComplete($jobID)) {
   # waiting for job to finish
   sleep(1);
 }

 print $Q->getJobOutput($jobID);

 $Q->jobLink($jobID, "http://link/to/file");


 my $jobTypes = $Q->jobTypes();
 foreach $aref (@$jobTypes) {
    print $aref->[0], "\t", $ref->[1], "\n";
 }



=head1 DESCRIPTION

 CGRBjob contains all the methods necessary for managing jobs in the CGRB Bioinformatics job queue.  This includes job submission, tracking, and output retrieval.  From the point of view of someone who is submitting jobs to the Queue, the only methods normally used will be submitJob, job_isComplete, and possibly getJobOutput and jobLink.  Most of the other methods are used by the daemon running the jobs and managing the queue.  It is likely that in the future this module will be split into at least two separate modules.

=head1 CONSTRUCTOR

B<new()>

 The constructor requires no arguments.  It will return an object blessed into the CGRBjob class.

=head1 OBJECT METHODS

B<jobSubmit(>
$jobType, $job_arguments [, $username, $submission_source, $priority]
B<)>

 jobSubmit submits a job to the job queue.  The first two arguments are required, whereas the others are optional.  The first argument corresponds to the ID number of a program that has been registered with the Queuing system.  To retrieve a list of registered programs and their ID's, use the method jobTypes() - see below.  The second argument is a list of arguments that will be sent when the registered program is invoked.  These arguments should be what is normally  passed to the prgram when it is run from the command-line.  Note that adding a space as the first character of the $job_arguments string is currently necessary.  The other arguments are optional.  The third argument is a username from the GGRB user list.  If no argument is passed, the job will be owned by 'anonymous' in the queuing system.  The fourth argument is the source of the job submission.  This field is currently not used extensively, but it is meant to represent whether the job is being submitted, ie, from the website vs from the command-line.  The last optional argument is a priority value.  The priority value determines the how the Queue will decide which job will run next when faced with multiple queued jobs.  If two jobs of equal priority are submitted, it is a first-com, first-run decision.  However, if two jobs of unequal priorities are submitted, the job with the LOWER priority value will be run first.  Therefore, the highest priority jobs will have priority = 1.  Not that values do not need to be passed for each optional argument, but their respective places must be used when calling the method.  For example, if a job is submitted and the only optional parameter desired is the priority value, then the method call should look like:  $Q->jobSubmit(1,$args,'','',$priority).

B<job_isComplete(>
$jobID
B<)>

 job_isComplete determines whether a job, specified by the single required argument, has finished.  If the job is finished a 1 is returned; otherwise 0 is returned.

B<getJobOutput(>
$jobID
B<)>

 Many programs send output to STDOUT.  By default this is captured by the queuing engine and saved.  To retrieve this output, use getJobOutput().  The single required argument is the ID number of the job.  The output is returned as a string.

B<jobLink(>
$jobID, $hyperlink
B<)>

 jobLink is used to set/retrieve the URL of a job's results.  This is most useful when users will be viewing the results through a web browser.

B<jobTypes()>

 jobTypes() returns a reference to an array of array references representing the ID number and command-line path of each registered job type.

=cut
