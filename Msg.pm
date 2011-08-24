package Genome::Msg;
# $Id: Msg.pm,v 1.2 2003/12/10 02:08:34 givans Exp $
# $Log: Msg.pm,v $
# Revision 1.2  2003/12/10 02:08:34  givans
# Allows creation of server
# Allows creation of connection
# Method to return connection socket
#
# Revision 1.1  2003/12/10 01:08:45  givans
# Initial revision
#

use strict;
use IO::Select;
use IO::Socket;
use Carp;
use warnings;

use vars qw($rd_handles $wr_handles);

$rd_handles = IO::Select->new();
$wr_handles = IO::Select->new();
my $proto = 'tcp';
my $port = 5535;
my $blocking_supported = 0;

BEGIN {
  # this checks to see if blocking is supported

  eval {
    require POSIX;
    POSIX->import(qw(F_SETFL O_NONBLOCK EAGAIN));
  };
  $blocking_supported = 1 unless $@;
}

1;

#########################################
# Establish connection with cluser node #
#########################################
sub connect {
  my($pkg, $iaddr) = @_;

  my $sock = IO::Socket::INET->new(	PeerHost	=>	$iaddr,
					PeerPort	=>	$port,
					Proto		=>	$proto,
					);
  die "can't create connection: $!" unless ($sock);

  my $conn = {
	      socket	=>	$sock,
	      iaddr	=>	$iaddr,
	      port	=>	$port,
	      proto	=>	$proto,
	      };

  bless $conn, $pkg;

  return $conn;
}

sub get_socket {
  my($obj) = shift;
  return $obj->{socket};
}


##########################################
# Create new server                      #
##########################################

sub new_server {
  my($pkg,$iaddr) = @_;
  print "iaddr = '$iaddr'\n";
  my $sock = IO::Socket::INET->new(	LocalHost	=>	$iaddr,
					LocalPort	=>	$port,
					Proto		=>	$proto,
					Listen		=>	5,
					Reuse		=>	1,
					);

  die "can't create new server: $!" unless ($sock);

  return $sock;
}


