package CGRB::Register;
# $Id: Register.pm,v 1.3 2005/01/19 19:05:50 givans Exp $
use warnings;
use strict;
use Carp;
#use lib '/home/cgrb/givans/dev/lib/perl5';
use CGRB::CGRBDB;
use vars qw/ @ISA /;

@ISA = ( 'CGRBDB' );

1;


sub new {
  my $pkg = shift;

  my $self = $pkg->generate('CGRBregister','cgrbWeb','webUser',@_);

  return $self;

}

sub max {
  my $self = shift;
  my $eventID = shift;
  my $max = shift;

  $max ? $self->_set_max($max) : $self->_get_max($eventID);
}

sub _set_max {
  my $self = shift;
  my $max = shift;

  warn("set max not yet implemented");
}

sub _get_max {
  my $self = shift;
  my $eventID = shift;
  my $dbh = $self->dbh();
  my ($sth,$rslt);

  $sth = $dbh->prepare("select MaxPeople from event where ID = ?");
  $sth->bind_param(1,$eventID);

  $rslt = $self->_dbAction($dbh,$sth,2);

  if (ref $rslt eq 'ARRAY') {
    return $rslt->[0]->[0];
  } else {
    return 0;
  }
}

sub eventTitle {
  my $self = shift;
  my $eventID = shift;
  my $eventTitle = shift;

  $eventTitle ? $self->_set_eventTitle($eventID,$eventTitle) : $self->_get_eventTitle($eventID);
}

sub _set_eventTitle {
  my $self = shift;
  my $eventID = shift;
  my $eventTitle = shift;

  warn("set event title not yet implemented");
}

sub _get_eventTitle {
  my $self = shift;
  my $eventID = shift;
  my $dbh = $self->dbh();
  my ($sth,$rslt);

  $sth = $dbh->prepare("select Title from event where ID = ?");
  $sth->bind_param(1,$eventID);

  $rslt = $self->_dbAction($dbh,$sth,2);

  if (ref $rslt eq 'ARRAY') {
    return $rslt->[0]->[0];
  } else {
    return 0;
  }
}

sub register {
  my $self = shift;
  my $firstname = shift;
  my $lastname = shift;
  my $email = shift;
  my $phone = shift;
  my $eventID = shift;
  my $dbh = $self->dbh();
  my ($sth,$rslt);

  if ($self->regCount($eventID) < $self->max($eventID)) {

    $sth = $dbh->prepare("insert into people (firstname, lastname, email, phone, event) values (?, ?, ?, ?, ?)");
    $sth->bind_param(1,$firstname);
    $sth->bind_param(2,$lastname);
    $sth->bind_param(3,$email);
    $sth->bind_param(4,$phone);
    $sth->bind_param(5,$eventID);

    $rslt = $self->_dbAction($dbh,$sth,1);
  } else {
    return 'max exceeded';
  }

  if (ref $rslt eq 'ARRAY') {
    return $rslt->[0]->[0];
  } else {
    return $rslt;
  }
}

sub regCount {
  my $self = shift;
  my $eventID = shift;
  my $dbh = $self->dbh();
  my ($sth,$rslt);
#  print "eventID passed: '$eventID'\n";

  $sth = $dbh->prepare("select count(ID) from people where event = ?");
  $sth->bind_param(1,$eventID);
  $rslt = $self->_dbAction($dbh,$sth,2);

  if (ref $rslt eq 'ARRAY') {
    return $rslt->[0]->[0];
  } else {
    return 0;
  }

}

sub getList {
  my $self = shift;
  my $eventID = shift;
  my $dbh = $self->dbh();
  my ($sth,$rslt);

  $sth = $dbh->prepare("select * from people where event = ? order by ID");
  $sth->bind_param(1,$eventID);

  $rslt = $self->_dbAction($dbh,$sth,2);

  if (ref $rslt eq 'ARRAY') {
    return $rslt;
  } else {
    return 0;
  }
}
