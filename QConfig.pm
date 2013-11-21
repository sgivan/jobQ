package CGRB::QConfig;

# $Id: QConfig.pm,v 3.4 2008/07/25 20:31:33 givans Exp $
# checked for gacweb

use warnings;
use strict;
use Carp;
#use lib '/home/cgrb/givans/dev/lib/perl5';
#use lib '/home/cgrb/cgrblib/perl5/perl5.new';
use CGRB::CGRBDB;
use autodie;
use vars qw/ @ISA /;

@ISA = qw/ CGRBDB /;

my $debug = 0;
if ($debug) {
    open(DEBUG,">>","/tmp/QConfig.log");
    print DEBUG "+" x 50 . "\n" . localtime . "\n\n";
}

1;

sub new {
  my $pkg = shift;

#  my $obj = bless { pkg => $pkg }, $pkg;

  my $obj = $pkg->SUPER::generate('CGRBjobs','QAdmin','qboss',@_);

  return $obj;
}

# Return maximum number of jobs that can run in queue
# This value represents the maximum number of WWW jobs that can run
# simultaneously in the infrastructure job queue.
# Get value from queuing system
# Currently uses openlava
sub maxJobs {
    my $self = shift;
    my $maxjobs = 25;
    my $busers = $self->qdirectory() . "/bin/busers";

#    get output from busers command:
#    [11/20/13 14:44:32] ircf-login-0-1 bin/$ busers apache
#    USER/GROUP          JL/P    MAX  NJOBS   PEND    RUN  SSUSP  USUSP    RSV
#    apache                 -     10      0      0      0      0      0      0

#   get login name
#   taken from perldoc -f getlogin
    my $login = getlogin || getpwuid($<) || "apache";
    print DEBUG "busers command: '$busers $login'\n" if ($debug);

    #open(BUSERS,"-|","$busers $login") || die "can't  open $busers: $!";
    open(my $BUSERS,"-|","$busers $login");
    my @capture = (<$BUSERS>);
    print DEBUG "captured: '@capture'\n" if ($debug);
    #close(BUSERS) or warn "can't close $busers properly: $!";
#    close $BUSERS;

    for my $line (@capture) {
        if ($line =~ /^$login/) {
            my @vals = split/\s+/,$line;

            $maxjobs = $vals[2] unless ($vals[2] =~ /-/);
        }
    }
    print DEBUG "returning '$maxjobs' from maxJobs()\n" if ($debug);
   return $maxjobs;
}

sub user_maxJobs {
    my $self = shift;

    my $dbh = $self->{_dbh};
    my ($sth,$rtn) = ();

    $sth = $dbh->prepare("select `Value` from jobConfig where `Property` = 'user_maxjobs'");
    $rtn = $self->_dbAction($dbh,$sth,2);
    if (ref $rtn eq 'ARRAY') {
        return $rtn->[0]->[0];
    } else {
        #print "\$rtn isa '" . ref($rtn) . "' ('$rtn')\n";
        return 1;
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

sub qbinary {
    my $self = shift;

    $self->{qbinary} = $self->qdirectory() . "/bin/bsub" unless (exists($self->{qbinary}));

    return $self->{qbinary};
}

sub qdirectory {
    my $self = shift;

    $self->{qdirectory} = '/opt/openlava-2.1/' unless (exists($self->{qdirectory}));

    return $self->{qdirectory};
}

