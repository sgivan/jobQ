package CGRB::CGRBAdmin::Admin;
# $Id: Admin.pm,v 1.2 2005/04/27 19:34:38 givans Exp $

use warnings;
use strict;
use Carp;
use vars qw/ @ISA /;
#use lib '/home/cgrb/givans/dev/lib/perl5';
use CGRB::CGRBDB;

@ISA = qw/ CGRBDB /;

my $debug = 0;

1;


sub new {
  my $self = shift;
  my $adm_obj = shift;
  print "machAdmin::new()\n" if ($debug);
  my $obj = $self->SUPER::new($adm_obj);

  #   $obj->_initialize($adm_obj);

  return $obj;
}

sub _initialize {
  my $self = shift;
  my $adm_obj = shift;

  $self->admin($adm_obj);
}

sub admin {
  my $self = shift;
  my $adm_obj = shift;

  $adm_obj ? $self->_set_admin($adm_obj) : $self->_get_admin();
}

sub _set_admin {
  my $self = shift;
  my $adm_obj = shift;

  $self->{_admin} = $adm_obj;
}

sub _get_admin {
  my $self = shift;

  return $self->{_admin};
}

sub param {
  my $self = shift;
  my $admin = $self->admin();

  $admin->param(@_);
}
