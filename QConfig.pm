package CGRB::QConfig;

# $Id: QConfig.pm,v 3.4 2008/07/25 20:31:33 givans Exp $
# checked for gacweb

use warnings;
use strict;
use Carp;
#use lib '/home/cgrb/givans/dev/lib/perl5';
#use lib '/home/cgrb/cgrblib/perl5/perl5.new';
use CGRB::CGRBDB;
use vars qw/ @ISA /;

@ISA = qw/ CGRBDB /;

1;


sub new {
  my $pkg = shift;

#  my $obj = bless { pkg => $pkg }, $pkg;

#  my $obj = $pkg->SUPER::generate('CGRBjobs','givans','6Acme7',@_);
  my $obj = $pkg->SUPER::generate('CGRBjobs','QAdmin','qboss',@_);

  return $obj;
}

sub maxJobs {
  my $obj = shift;
  my ($dbh,$sth,$rtn) = ($obj->{_dbh});

  $sth = $dbh->prepare("select Value from jobConfig where Property = 'user_maxjobs'");

  $rtn = $obj->_dbAction($dbh,$sth,2);

  if (ref $rtn eq 'ARRAY') {
    return $rtn->[0]->[0];
  } else {
    return 0;
  }

}

sub Q_PID {
  my $obj = shift;
  my $PID = shift;

  $PID ? $obj->_set_Q_PID($PID) : $obj->_get_Q_PID();
}

sub _set_Q_PID {
  my $obj = shift;
  my $pid = shift;
  my $dbh = $obj->{_dbh};
  my ($sth, $rtn);
  $pid = '000' unless ($pid);

  $sth = $dbh->prepare("update jobConfig set Value = ? where Property = 'Q_pid'");
  $sth->bind_param(1,$pid);

  $rtn = $obj->_dbAction($dbh,$sth,3);

  if (ref $rtn eq 'ARRAY') {
    return $rtn->[0]->[0];
  } else {
    return $rtn;
  }

}

sub _get_Q_PID {
  my $obj = shift;
  my $dbh = $obj->{_dbh};
  my ($sth, $rtn);

  $sth = $dbh->prepare("select Value from jobConfig where Property = 'Q_pid'");
  $rtn = $obj->_dbAction($dbh,$sth,2);

  if (ref $rtn eq 'ARRAY') {
    return $rtn->[0]->[0];
  } else {
    return $rtn;
  }

}
