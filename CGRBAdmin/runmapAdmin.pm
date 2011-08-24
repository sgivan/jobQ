package CGRB::CGRBAdmin::runmapAdmin;

# $Id: runmapAdmin.pm,v 1.4 2007/12/20 08:41:41 givans Exp $

use warnings;
use strict;
use Carp;
#use lib '/home/cgrb/givans/dev/lib/perl5';
use CGRB::CGRBAdmin::Admin;
use CGRB::CGRBAdmin::toolAdmin;
use vars qw/ @ISA /;
@ISA = qw/ CGRB::CGRBAdmin::Admin CGRB::CGRBAdmin::toolAdmin /;

1;


sub queryRunMap {
  my $self = shift;
  my $dbh = $self->dbh();
  my ($table,$sth,$rtn) = $self->admin()->runmapTable();

  $sth = $dbh->prepare("select * from `$table`");

  $rtn = $self->dbAction($dbh,$sth,2);

  if ($rtn) {
    return $rtn;
  } else {
    return undef;
  }
}

sub queryMasterMap {
  my $self = shift;
  my $masterID = shift;
  my ($dbh,$table,$sth,$rtn) = ($self->dbh(),$self->admin()->runmapTable());

  return undef unless ($masterID);

  $sth = $dbh->prepare("select * from `$table` where `Master` = ?");
  $sth->bind_param(1,$masterID);

  $rtn = $self->dbAction($dbh,$sth,2);

  if ($rtn) {
    return $rtn;
  } else {
    return undef;
  }
}

sub queryTypeMap { # this method is the same as toolAdmin::queryToolMasters()
  my $self = shift;
  my $typeID = shift;
  my ($dbh,$table,$sth,$rtn) = ($self->dbh(),$self->admin()->runmapTable());

  $sth = $dbh->prepare("select * from `$table` where `JobType` = ?");
  $sth->bind_param(1,$typeID);

  $rtn = $self->dbAction($dbh,$sth,2);

  if ($rtn) {
    return $rtn;
  } else {
    return undef;
  }
}

sub assoc {
  my $self = shift;
  my $masterID = shift;
  my $jobtypeID = shift;
  my ($dbh,$table,$sth,$rtn) = ($self->dbh(),$self->admin()->runmapTable());

  $sth = $dbh->prepare("select * from `$table` where `Master` = ? AND `JobType` = ?");
  $sth->bind_param(1,$masterID);
  $sth->bind_param(2,$jobtypeID);

  $rtn = $self->dbAction($dbh,$sth,2);

  if ($rtn) {
    return $rtn->[0]->[0];
  } else {
    return undef;
  }
}

sub create {
  my $self = shift;
  my $machID = shift;
  my $jobtypeID = shift;
  my ($dbh,$table,$sth,$rtn) = ($self->dbh(),$self->admin()->runmapTable());

  return undef if ($self->assoc($machID,$jobtypeID));

  $sth = $dbh->prepare("insert into `$table` (`Master`,`JobType`) values (?,?)");
  $sth->bind_param(1,$machID);
  $sth->bind_param(2,$jobtypeID);

  $rtn = $self->dbAction($dbh,$sth,1);

  if ($rtn) {
    return $rtn->[0]->[0];
  } else {
    return undef;
  }
}

sub remove {
  my $self = shift;
  my $mapID = shift;
  my ($dbh,$table,$sth,$rtn) = ($self->dbh(),$self->admin()->runmapTable());

  $sth = $dbh->prepare("delete from `$table` where `ID` = ?");
  $sth->bind_param(1,$mapID);

  $rtn = $self->dbAction($dbh,$sth,4);

  if ($rtn) {
    return $rtn->[0]->[0];
  } else {
    return undef;
  }
}

sub runmapParam {
  my $self = shift;
  my $runmapID = shift;
  my $param = shift;
  my $newValue = shift;

  return undef unless ($self && $runmapID && $param);

  $newValue ? $self->_set_runmapParam($runmapID,$param,$newValue) : $self->_get_runmapParam($runmapID,$param);

}

sub _set_runmapParam {
  my $self = shift;
  my $runmapID = shift;
  my $param = shift;
  my $newValue = shift;
  
	$self->param($self->admin()->runmapTable(),'ID',$runmapID,$param,$newValue);
}

sub _get_runmapParam {
  my $self = shift;
  my $runmapID = shift;
  my $param = shift;
  
	$self->param($self->admin()->runmapTable(),'ID',$runmapID,$param);
}

sub master {
  my $self = shift;
  my $mapID = shift;
  my $masterID = shift;

  return undef unless ($self && $mapID);

  $masterID ? $self->_set_master($mapID,$masterID) : $self->_get_master($mapID);
}

sub _set_master {
  my $self = shift;
  my $mapID = shift;
  my $masterID = shift;

  $self->runmapParam($mapID,'Master',$masterID);
}

sub _get_master {
  my $self = shift;
  my $mapID = shift;

  $self->runmapParam($mapID,'Master');
}

sub jobtype {
  my $self = shift;
  my $mapID = shift;
  my $jobtypeID = shift;

  return undef unless ($self && $mapID);

  $jobtypeID ? $self->_set_jobtype($mapID,$jobtypeID) : $self->_get_jobtype($mapID);
}

sub _set_jobtype {
  my $self = shift;
  my $mapID = shift;
  my $jobtypeID = shift;

  $self->runmapParam($mapID,'JobType',$jobtypeID);
}

sub _get_jobtype {
  my $self = shift;
  my $mapID = shift;

  $self->runmapParam($mapID,'JobType');
}
