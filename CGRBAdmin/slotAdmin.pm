package CGRB::CGRBAdmin::slotAdmin;
# $Id: slotAdmin.pm,v 1.4 2005/04/27 19:30:20 givans Exp $

use warnings;
use strict;
use Carp;
#use lib '/home/cgrb/givans/dev/lib/perl5';
use CGRB::CGRBAdmin::Admin;
use vars qw/ @ISA /;
@ISA = qw/ CGRB::CGRBAdmin::Admin /;

my $debug = 0;

1;

# BEGIN {
#     open(LOG, ">>/home/cgrb/givans/dev/bin/logs/slotAdmin.log") or die "can't open slotAdmin.log: $!";
#     print LOG "\n\n\n", "+" x 40, "\n", "slotAdmin ", scalar(localtime()), "\n\n";
# }

# END {
#     close(LOG);
# }

sub queryMachSlots {
	my $self = shift;
	my $machID = shift;
	my ($dbh,$sth,$rtn) = $self->dbh();
	my $table = $self->admin()->slotTable();
	if ($debug) {
	  print LOG "queryMachSlots():  ", scalar(caller()), "\n";
	  print LOG "select * from $table where HOST = $machID\n";
	}

	$sth = $dbh->prepare("select * from $table where HOST = ?");
	$sth->bind_param(1,$machID);
	
	$rtn = $self->dbAction($dbh,$sth,2);
	
	if ($rtn) {
		return $rtn;
	} else {
		return undef;
	}
}

sub addSlot {
  my $self = shift;
  my $machID = shift;
  my $status = shift;
  my ($dbh,$table,$sth,$rtn) = ($self->dbh(),$self->admin()->slotTable());
  $status = 'U' unless ($status);
  if ($debug) {
    print LOG "addSlot():  ", scalar(caller()), "\n";
    print LOG "insert into $table (HOST, STATUS) values ($machID,$status)\n";
  }
  return undef unless ($self && $machID && $status);

  $sth = $dbh->prepare("insert into $table (HOST, STATUS) values (?,?)");
  $sth->bind_param(1,$machID);
  $sth->bind_param(2,$status);

  $rtn = $self->dbAction($dbh,$sth,1);

  if ($rtn) {
    return $rtn->[0]->[0];
  } else {
    return undef;
  }
}

sub remvoeSlot {
  my $self = shift;
  $self->deleteSlot(@_);
}

sub deleteSlot {
  my $self = shift;
  my $slotID = shift;
  my ($dbh,$table,$sth,$rtn) = ($self->dbh(),$self->admin()->slotTable());
  if ($debug) {
    print LOG "deleteSlot():  ", scalar(caller()), "\n";
    print LOG "delete from $table where ID = $slotID\n";
  }
  return undef unless ($slotID);

  $sth = $dbh->prepare("delete from $table where ID = ?");
  $sth->bind_param(1,$slotID);

  $rtn = $self->dbAction($dbh,$sth,4);

  if ($rtn) {
    return $rtn->[0]->[0];
  } else {
    return undef;
  }
}

sub addSlots {
  my $self = shift;
  my $machID = shift;
  my $slots = shift;
  if ($debug) {
    print LOG "addSlots():  ", scalar(caller()), "\n";
  }

  return undef unless ($slots > 0 && $machID);

  while ($slots--) {
    $self->addSlot($machID);
  }
}

sub deleteSlots {# delets all slots for a machine
  my $self = shift;
  my $machID = shift;
  my $slotcnt = shift;
  my $slots = $self->queryMachSlots($machID);
  my $cnt = 0;
  print LOG "deleteSlots():  ", scalar(caller()), "\n" if ($debug);
  return undef unless ($machID);

  foreach my $slotID (@$slots) {
    $self->deleteSlot($slotID->[0]);
    ++$cnt;
    if ($slotcnt) {
      last if ($cnt == $slotcnt);
    }
  }

}
sub status {
  my $self = shift;
  my $slotID = shift;
  my $status = shift;
  print LOG "status():  ", scalar(caller()), "\n" if ($debug);
  return undef unless ($self && $slotID);

  $status ? $self->_set_status($slotID,$status) : $self->_get_status($slotID);
}

sub _set_status {
  my $self = shift;
  my $slotID = shift;
  my $status = shift;
  if ($debug) {
    print LOG "setting status of slot $slotID to '$status'\n";
  }
  $self->param($self->admin()->slotTable(),'ID',$slotID,'STATUS',$status);

}

sub _get_status {
  my $self = shift;
  my $slotID = shift;
  if ($debug) {
    print LOG "retrieving status of slot $slotID\n";
  }
  $self->param($self->admin()->slotTable(),'ID',$slotID,'STATUS');
}

sub host {
  my $self = shift;
  my $slotID = shift;
  my $hostID = shift;
  print LOG "host():  ", scalar(caller()), "\n" if ($debug);
  return undef unless ($self && $slotID);

  $hostID ? $self->_set_host($slotID,$hostID) : $self->_get_host($slotID);
}

sub _set_host {
  my $self = shift;
  my $slotID = shift;
  my $hostID = shift;
  print LOG "setting host of slot $slotID to $hostID\n" if ($debug);
  $self->param($self->admin()->slotTable(),'ID',$slotID,'HOST',$hostID);
}

sub _get_host {
  my $self = shift;
  my $slotID = shift;
  print LOG "retrieving host for slot $slotID\n" if ($debug);
  $self->param($self->admin()->slotTable(),'ID',$slotID,'HOST');
}
