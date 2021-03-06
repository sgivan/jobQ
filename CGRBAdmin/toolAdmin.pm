package CGRB::CGRBAdmin::toolAdmin;
#
# $Id: toolAdmin.pm,v 1.8 2007/12/20 08:41:41 givans Exp $

use warnings;
use strict;
use Carp;
#use lib '/home/cgrb/givans/dev/lib/perl5';
use CGRB::CGRBAdmin::Admin;
#use CGRB::CGRBAdmin;
use vars qw/ @ISA /;
@ISA = qw/ CGRB::CGRBAdmin::Admin /;
#@ISA = qw/ CGRB::CGRBAdmin /;

1;

sub queryRegisteredTools {
  my $self = shift;
  my $dbh = $self->dbh();
  my ($sth,$rtn);

  $sth = $dbh->prepare("select * from `jobInfo`");
  $rtn = $self->dbAction($dbh,$sth,2);

  if (ref $rtn eq 'ARRAY') {
    return $rtn;
  } else {
    return undef;
  }
}

sub queryToolInfo {
  my $self = shift;
  my $toolID = shift;

  $toolID ? $self->_queryToolInfo($toolID) : undef;
}

sub _queryToolInfo {
  my $self = shift;
  my $toolID = shift;
  my $dbh = $self->dbh();
  my ($sth,$rtn);
  
  $sth = $dbh->prepare("select * from `jobInfo` where `ID` = ?");
  $sth->bind_param(1,$toolID);
  $sth->execute();

  $rtn = $sth->fetchrow_hashref();

  if (ref $rtn eq 'HASH') {
    return $rtn;
  } else {
    return undef;
  }
}

sub queryToolMasters { # this method is the same as runmapAdmin::queryTypeMap()
  my $self = shift;
  my $toolID = shift;
  my $dbh = $self->dbh();
  my ($sth,$rtn);
    
  $sth = $dbh->prepare("select * from `jobRunMap` where `JobType` = ?");
  $sth->bind_param(1,$toolID);

  $rtn = $self->dbAction($dbh,$sth,2);

  return $rtn if ($rtn);
  return undef;
  

}

sub newTool {
  my $self = shift;
  my $toolName = shift;
  my $toolCMD = shift;
  my $toolOUT = shift;
  my $toolDIR = shift;
  my $toolECODE = shift;
  my ($dbh,$table,$sth,$rtn) = ($self->dbh(),$self->admin()->toolTable());
  $toolECODE = 'NULL' unless ($toolECODE);

  return undef unless ($self && $toolName && $toolCMD && $toolOUT && $toolDIR);

  $sth = $dbh->prepare("insert into $table (`Name`,`CMD`,`OUT`,`DIR`,`ExitCode`) values (?,?,?,?,?)");
  $sth->bind_param(1,$toolName);
  $sth->bind_param(2,$toolCMD);
  $sth->bind_param(3,$toolOUT);
  $sth->bind_param(4,$toolDIR);
  $sth->bind_param(5,$toolECODE);

  $rtn = $self->dbAction($dbh,$sth,1);

  if ($rtn) {
    return $rtn->[0]->[0];
  } else {
    $sth = $dbh->prepare("select max(`ID`) from $table");
    $rtn = $self->dbAction($dbh,$sth,2);
    if ($rtn) {
      return $rtn->[0]->[0];
    } else {
      return undef;
    }
  }
}

sub removeTool {
  my $self = shift;
  my $toolID = shift;
  my ($dbh,$table,$sth,$rtn) = ($self->dbh(),$self->admin()->toolTable());
  my $runmapAdmin = $self->admin()->obj_runmapAdmin();

  foreach my $row ($runmapAdmin->queryTypeMap($toolID)) {
    $runmapAdmin->remove($row->[0]);
  }

  $sth = $dbh->prepare("delete from `$table` where `ID` = ?");
  $sth->bind_param(1,$toolID);

  $rtn = $self->dbAction($dbh,$sth,4);

  if ($rtn) {
    return $rtn->[0]->[0];
  } else {
    return undef;
  }
}

sub toolParam {
  my $self = shift;
  my $toolID = shift;
  my $param = shift;
  my $newValue = shift;

  return undef unless ($self && $toolID && $param);

  $newValue ? $self->_set_toolParam($toolID,$param,$newValue) : $self->_get_toolParam($toolID,$param);

}

sub _set_toolParam {
  my $self = shift;
  my $toolID = shift;
  my $param = shift;
  my $newValue = shift;
  
	$self->param($self->admin()->infoTable(),'ID',$toolID,$param,$newValue);
}

sub _get_toolParam {
  my $self = shift;
  my $toolID = shift;
  my $param = shift;
  
	$self->param($self->admin()->infoTable(),'ID',$toolID,$param);
}

sub toolName {
  my $self = shift;
  my $toolID = shift;
  my $toolName = shift;
  my $param = 'Name';
  
  return unless ($self && $toolID);

  $toolName ? $self->_set_toolName($toolID,$param,$toolName) : $self->_get_toolName($toolID,$param);
}

sub _set_toolName {
  my $self = shift;
  $self->toolParam(@_);
}

sub _get_toolName {
  my $self = shift;
  $self->toolParam(@_);
}

sub toolCMD {
  my $self = shift;
  my $toolID = shift;
  my $toolCMD = shift;
  my $param = 'CMD';

  return undef unless ($self && $toolID);

  $toolCMD ? $self->_set_toolCMD($toolID,$param,$toolCMD) : $self->_get_toolCMD($toolID,$param);
}

sub _set_toolCMD {
  my $self = shift;
  $self->toolParam(@_);
}

sub _get_toolCMD {
  my $self = shift;
  $self->toolParam(@_);
}

sub toolOUT {
  my $self = shift;
  my $toolID = shift;
  my $toolOUT = shift;
  my $param = 'OUT';

  return undef unless ($self && $toolID);

  $toolOUT ? $self->_set_toolOUT($toolID,$param,$toolOUT) : $self->_get_toolOUT($toolID,$param);
}

sub _set_toolOUT {
  my $self = shift;
  $self->toolParam(@_);
}

sub _get_toolOUT {
  my $self = shift;
  $self->toolParam(@_);
}

sub toolDIR {
  my $self = shift;
  my $toolID = shift;
  my $toolDIR = shift;
  my $param = 'DIR';

  return undef unless ($self && $toolID);

  $toolDIR ? $self->_set_toolDIR($toolID,$param,$toolDIR) : $self->_get_toolDIR($toolID,$param);
}

sub _set_toolDIR {
  my $self = shift;
  $self->toolParam(@_);
}

sub _get_toolDIR {
  my $self = shift;
  $self->toolParam(@_);
}

sub toolExitCode {
  my $self = shift;
  my $toolID = shift;
  my $toolExitCode = shift;
  my $param = 'ExitCode';

  return undef unless ($self && $toolID);

  $toolExitCode ? $self->_set_toolExitCode($toolID,$param,$toolExitCode) : $self->_get_toolExitCode($toolID,$param);
}

sub _set_toolExitCode {
  my $self = shift;
  $self->toolParam(@_);
}

sub _get_toolExitCode {
  my $self = shift;
  $self->toolParam(@_);
}

sub toolHost {
	my $self = shift;
	my $toolID = shift;
	my $toolHost = shift;
	my $param = 'Host';

	return undef unless ($self && $toolID);

	$toolHost ? $self->_set_toolHost($toolID,$param,$toolHost) : $self->_get_toolHost($toolID,$param);
}

sub _set_toolHost {
	my $self = shift;
	$self->toolParam(@_);
}

sub _get_toolHost {
	my $self = shift;
	$self->toolParam(@_);
}

