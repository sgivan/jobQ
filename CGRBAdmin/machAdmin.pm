package CGRB::CGRBAdmin::machAdmin;
# $Id: machAdmin.pm,v 1.6 2008/08/01 19:19:35 givans Exp $

use warnings;
use strict;
use Carp;
#use lib '/home/cgrb/givans/dev/lib/perl5';
#use lib '/home/cgrb/cgrblib/perl5/perl5.new';
use CGRB::CGRBAdmin::Admin;
use vars qw/ @ISA /;
@ISA = qw/ CGRB::CGRBAdmin::Admin /;

my $debug = 0;

1;

#  sub new {
#    my $pkg = shift;

#    my $obj = $pkg->SUPER::generate('CGRBjobs','queue','CGRBq');

#    return $obj;
#  }

sub queryRegisteredMachines {
  my $self = shift;
  my $dbh = $self->dbh();
  my ($sth,$rtn);

  $sth = $dbh->prepare("select * from jobMaster");

  $rtn = $self->dbAction($dbh,$sth,2);

  if ($rtn) {
    return $rtn;
  } else {
    return undef;
  }
}

sub registerMachine {
  my $self = shift;
  my $machName = shift;
  my $runMethod = shift;
  my $addr = shift;
  my $rank = shift;
  my $slots = shift;
  my $type = shift;
  my ($dbh,$sth,$rtn) = $self->dbh();
  my $table = $self->admin()->masterTable();
  return undef unless ($self && $machName && $runMethod && $addr && $rank && $slots && $type);

  $sth = $dbh->prepare("insert into $table (MachName, Method, ADDR, RANK, SLOTS, TYPE) values (?,?,?,?,?,?)");
  $sth->bind_param(1,$machName);
  $sth->bind_param(2,$runMethod);
  $sth->bind_param(3,$addr);
  $sth->bind_param(4,$rank);
  $sth->bind_param(5,$slots);
  $sth->bind_param(6,$type);

  $rtn = $self->dbAction($dbh,$sth,1);

  if ($rtn) {
    return $rtn->[0]->[0];
  } else {
     my $rtn = $self->sselect('ID',$table,'MachName',$machName,'ID');
     if ($rtn) {
       return $rtn->[0]->[0];
     }
  }
}

sub deleteMachine {
  my $self = shift;
  my $machID = shift;
  my ($dbh,$table,$sth,$rtn) = ($self->dbh(),$self->admin()->masterTable());

  return undef unless ($machID);

  $sth = $dbh->prepare("delete from $table where ID = ?");
  $sth->bind_param(1,$machID);

  $rtn = $self->dbAction($dbh,$sth,4);

  if ($rtn) {
    return $rtn->[0]->[0];
  } else {
    return undef;
  }
}

# sub param {
#   my $self = shift;
#   my $admin = $self->admin();

#   $admin->param(@_);
# }


sub runMethod {
  my $self = shift;
  my $machID = shift;
  my $method = shift;

  $method ? $self->_set_runMethod($machID,$method) : $self->_get_runMethod($machID);
}

sub _set_runMethod {
	my $self = shift;
	my $machID = shift;
	my $runMethod = shift;

	$self->param($self->admin()->masterTable(),'ID',$machID,'Method',$runMethod);
}

sub _get_runMethod {
  my $self = shift;
  my $machID = shift;

  $self->param($self->admin()->masterTable(),'ID',$machID,'Method',);
}

sub slotMaster {
  my $self = shift;
  my $slotID = shift;
  my $masterID = shift;
  print "machAdmin::slotMaster():  ", join ' ', caller(), "\n" if ($debug);
  $masterID ? $self->_set_slotMaster($slotID,$masterID) : $self->_get_slotMaster($slotID);

}

sub _set_slotMaster {
	my $self = shift;
	my $slotID = shift;
	my $masterID = shift;
	print "setting master of slot $slotID to $masterID\n" if ($debug);
	$self->param($self->admin()->slotTable(),'ID',$slotID,'HOST',$masterID);
}

sub _get_slotMaster {
  my $self = shift;
  my $slotID = shift;
  print "retrieving master of slot $slotID\n" if ($debug);
  $self->param($self->admin()->slotTable(),'ID',$slotID,'HOST');
}

sub machName {
  my $self = shift;
  my $machID = shift;
  my $machName = shift;
  
  $machName ? $self->_set_machName($machID,$machName) : $self->_get_machName($machID);
}

sub _set_machName {
	my $self = shift;
	my $machID = shift;
	my $machName = shift;
	
	$self->param($self->admin()->masterTable(),'ID',$machID,'MachName',$machName);
}

sub _get_machName {
  my $self = shift;
  my $machID = shift;
  my $rtn;

  $self->param($self->admin()->masterTable(),'ID',$machID,'MachName');
}

sub machAddr {
  my $self = shift;
  my $machID = shift;
  my $machAddr = shift;

  $machAddr ? $self->_set_machAddr($machID,$machAddr) : $self->_get_machAddr($machID);

}

sub _set_machAddr {
	my $self = shift;
	my $machID = shift;
	my $machAddr = shift;
	
	$self->param($self->admin()->masterTable(),'ID',$machID,'ADDR',$machAddr);
}

sub _get_machAddr {
  my $self = shift;
  my $machID = shift;

  $self->param($self->admin()->masterTable(),'ID',$machID,'ADDR');
}

sub machRANK {
	my $self = shift;
	my $machID = shift;
	my $machRank = shift;
	
	return undef unless ($self && $machID);
	
	$machRank ? $self->_set_machRANK($machID,$machRank) : $self->_get_machRANK($machID);
}

sub _set_machRANK {
	my $self = shift;
	my $machID = shift;
	my $machRank = shift;
	
	$self->param($self->admin()->masterTable(),'ID',$machID,'RANK',$machRank);
}

sub _get_machRANK  {
	my $self = shift;
	my $machID = shift;
	
	$self->param($self->admin()->masterTable(),'ID',$machID,'RANK');
}

sub machSLOTS {
	my $self = shift;
	my $machID = shift;
	my $slots = shift;
	
	return undef unless ($self && $machID);
	
	$slots ? $self->_set_machSLOTS($machID,$slots) : $self->_get_machSLOTS($machID);
}

sub _set_machSLOTS {
	my $self = shift;
	my $machID = shift;
	my $machSLOTS = shift;
	
	$self->param($self->admin()->masterTable(),'ID',$machID,'SLOTS',$machSLOTS);
}

sub _get_machSLOTS {
	my $self = shift;
	my $machID = shift;
	
	$self = $self->param($self->admin()->masterTable(),'ID',$machID,'SLOTS');
}

sub machTYPE {
	my $self = shift;
	my $machID = shift;
	my $machTYPE = shift;
	
	return undef unless ($self && $machID);
	
	$machTYPE ? $self->_set_machTYPE($machID,$machTYPE) : $self->_get_machTYPE($machID);
}

sub _set_machTYPE {
	my $self = shift;
	my $machID = shift;
	my $machTYPE = shift;
	
	$self->param($self->admin()->masterTable(),'ID',$machID,'TYPE',$machTYPE);
}

sub _get_machTYPE {
	my $self = shift;
	my $machID = shift;
	
	$self->param($self->admin()->masterTable(),'ID',$machID,'TYPE');
}

sub machLOAD {
	my $self = shift;
	my $machID = shift;
	my $machLOAD = shift;
	
	return undef unless ($self && $machID);
	
	$machLOAD ? $self->_set_machLOAD($machID,$machLOAD) : $self->_get_machLOAD($machID);

}

sub _set_machLOAD {
	my $self = shift;
	my $machID = shift;
	my $machLOAD = shift;
	
	$self->param($self->admin()->masterTable(),'ID',$machID,'LOAD',$machLOAD);

}

sub _get_machLOAD {
	my $self = shift;
	my $machID = shift;
	
	$self->param($self->admin()->masterTable(),'ID',$machID,'LOAD');

}

