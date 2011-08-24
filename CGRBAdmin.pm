package CGRB::CGRBAdmin;
# $Id: CGRBAdmin.pm,v 3.10 2008/08/01 17:08:18 givans Exp $

use warnings;
use strict;
use Carp;
#use lib '/home/cgrb/givans/dev/lib/perl5';
#use lib '/home/cgrb/cgrblib/perl5/perl5.new';
use CGRB::CGRBDB;
#use CGRB::CGRBAdmin::machAdmin;
use vars qw/ @ISA /;

@ISA = qw/ CGRBDB /;

my %tables = (
	      master 		=> 	'jobMaster',
	      slot		=>	'jobSlot',
	      info		=>	'jobInfo',
	      runmap		=>	'jobRunMap',
	      complete		=>	'jobComplete',
	      config		=>	'jobConfig',
	      queue		=>	'jobQueue',
	      run		=>	'jobRun',
	      src		=>	'jobSRC',
	      submit		=>	'jobSubmit',
	      user		=>	'jobUser',
	      usercategory	=>	'jobUserCategory',
	      usergrouplist	=>	'jobUserGroupList',
	      userlab		=>	'jobUserLab',
	);

1;

sub new {
  my $pkg = shift;

  my $obj = $pkg->SUPER::generate('CGRBjobs','queue','CGRBq',@_);

  return $obj;
}

sub _get_Table {
	my $self = shift;
	my $table = shift;
	
	return $tables{$table};
}

sub masterTable {
	my $self = shift;
	$self->_get_Table('master');
}

sub slotTable {
	my $self = shift;
	$self->_get_Table('slot');
}

sub infoTable {
	my $self = shift;
	$self->_get_Table('info');
}

sub toolTable {
  my $self = shift;
  $self->_get_Table('info');
}

sub runmapTable {
	my $self = shift;
	$self->_get_Table('runmap');
}

sub completeTable {
  my $self = shift;
  $self->_get_Table('complete');
}

sub configTable {
  my $self = shift;
  $self->_get_Table('config');
}

sub queueTable {
  my $self = shift;
  $self->_get_Table('queue');
}

sub runTable {
  my $self = shift;
  $self->_get_Table('run');
}

sub srcTable {
  my $self = shift;
  $self->_get_Table('src');
}

sub submitTable {
  my $self = shift;
  $self->_get_Table('submit');
}

sub userTable {
  my $self = shift;
  $self->_get_Table('user');
}

sub usercategoryTable {
  my $self = shift;
  $self->_get_Table('usercategory');
}

sub usergroupTable {
  my $self = shift;
  $self->_get_Table('usergroupTable');
}

sub usergrouplistTable {
  my $self = shift;
  $self->_get_Table('usergrouplist');
}

sub userlabTable {
  my $self = shift;
  $self->_get_Table('userlab');
}

sub param {
	my $self = shift;
	my $table = shift;
	my $ID = shift;
	my $IDvalue = shift;
	my $paramName = shift;
	my $paramValue = shift;

	return undef unless ($self && $table && $paramName && $ID && $IDvalue);
	
	$paramValue ? $self->_set_param($table,$paramName,$ID,$IDvalue,$paramValue) : $self->_get_param($table,$paramName,$ID,$IDvalue);
}

sub _set_param {
	my $self = shift;
	my $table = shift;
	my $paramName = shift;
	my $ID = shift;
	my $IDvalue = shift;
	my $paramValue = shift;
	my ($dbh,$sth,$rtn) = $self->dbh();
	
	$sth = $dbh->prepare("update `$table` set `$paramName` = ? where `$ID` = ?");
	$sth->bind_param(1,$paramValue);
	$sth->bind_param(2,$IDvalue);
	
	$rtn = $self->dbAction($dbh,$sth,3);
	
	if ($rtn) {
		return $rtn->[0]->[0];
	} else {
		return undef;
	}
}

sub _get_param {
	my $self = shift;
	my $table = shift;
	my $paramName = shift;
	my $ID = shift;
	my $IDvalue = shift;
	my ($dbh,$sth,$rtn) = $self->dbh();
	
	$sth = $dbh->prepare("select `$paramName` from `$table` where `$ID` = ?");
	$sth->bind_param(1,$IDvalue);
	
	$rtn = $self->dbAction($dbh,$sth,2);
	
	if ($rtn) {
		return $rtn->[0]->[0];
	} else {
		return undef;
	}
}

sub obj_machAdmin {
  my $self = shift;
  my ($p, $f, $l) = caller();

  eval {
    require CGRB::CGRBAdmin::machAdmin;
  };
  if ($@) {
    return undef;
  }

#  my $machAdmin = CGRB::CGRBAdmin::machAdmin->new($self->dbh());
  my $machAdmin = CGRB::CGRBAdmin::machAdmin->new($self);
  return $machAdmin;
}

sub obj_toolAdmin {
  my $self = shift;

  eval {
    require CGRB::CGRBAdmin::toolAdmin;
  };
  return undef if ($@);

#  my $toolAdmin = CGRB::CGRBAdmin::toolAdmin->new($self->dbh());
  my $toolAdmin = CGRB::CGRBAdmin::toolAdmin->new($self);
  return $toolAdmin;

}

sub obj_slotAdmin {
  my $self = shift;

  eval {
    require CGRB::CGRBAdmin::slotAdmin;
  };
  return undef if ($@);

#  my $slotAdmin = CGRB::CGRBAdmin::slotAdmin->new($self->dbh());
  my $slotAdmin = CGRB::CGRBAdmin::slotAdmin->new($self);
  return $slotAdmin;
}

sub obj_runmapAdmin {
  my $self = shift;

  eval {
    require CGRB::CGRBAdmin::runmapAdmin;
  };
  return undef if ($@);

#  my $runmapAdmin = CGRB::CGRBAdmin::runmapAdmin->new($self->dbh());
  my $runmapAdmin = CGRB::CGRBAdmin::runmapAdmin->new($self);
  return $runmapAdmin;
}
