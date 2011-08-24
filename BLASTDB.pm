package CGRB::BLASTDB;
# $Id: BLASTDB.pm,v 1.4 2004/11/16 21:38:43 givans Exp $
use warnings;
use strict;
use Carp;
use CGRB::CGRBDB;
use vars qw/ @ISA /;

@ISA = qw/ CGRBDB /;

1;

sub new {
  my $pkg = shift;
  my $user = shift;
  my $psswd = shift;

  $user = 'gcg' unless ($user);
  $psswd = 'sequences' unless ($psswd);

#  print "using user=$user, passwd=$psswd\n";

  my $self = $pkg->generate('seq_databases',$user,$psswd);

  return $self;
}

sub availDB {
  my $self = shift;
  my $db = shift;
  my $avail = shift;


  $avail ? $self->_set_availDB($db,$avail) : $self->_get_availDB($db);

}

sub _set_availDB {
   my $self = shift;
   my $db = shift;
   my $avail = shift;# should be T or F
   my $dbh = $self->dbh();
   my ($sth,$rslt);
   my $dbFile = $self->dbFile($db);# dbFile will be name of DB

   if ($avail ne 'T' && $avail ne 'F') {
     return "database available should be either 'T' or 'F'";
   }

   $sth = $dbh->prepare("update DB set Avail = ? where db_file = ?");
   $sth->bind_param(1,$avail);
   $sth->bind_param(2,$dbFile);

   $rslt = $self->_dbAction($dbh,$sth,3);

   if (ref $rslt eq  'ARRAY') {
     return $rslt->[0]->[0];
   } else {
     return 0;
   }

}

sub _get_availDB {
  my $self = shift;
  my $db = shift;
  my $dbh = $self->dbh();
  my ($sth,$rslt);
  my $dbFile = $self->dbFile($db);

  $sth = $dbh->prepare("select Avail from DB where db_file = ?");
  $sth->bind_param(1,$dbFile);
  $rslt = $self->_dbAction($dbh,$sth,2);

  if (ref $rslt eq 'ARRAY') {
    return $rslt->[0]->[0];
  } else {
    return 0;
  }
}

sub availDB_byType {
  my $self = shift;
  my $dbType = shift;
  my $avail = shift;

  $avail ? $self->_set_availDB_byType($dbType,$avail) : $self->_get_availDB_byType($dbType);

}

sub _set_availDB_byType {
  warn("setting DB availability by type no yet implemented");
}

sub _get_availDB_byType {
  my $self = shift;
  my $dbType = shift;
  my $dbh = $self->dbh();
  my ($sth,$rslt);

  $sth = $dbh->prepare("select db_name from DB where db_type = ? and Avail = 'F'");
  $sth->bind_param(1, $dbType);
  $rslt = $self->_dbAction($dbh,$sth,2);

  if (ref $rslt eq 'ARRAY') {
    if ($rslt->[0]->[0]) {
      return 'F';
    } else {
      return 'T';
    }
  } else {
    return 0;
  }
}

sub dbFile {
  my $self = shift;
  my $db = shift;
  my $file = shift;

  $file ? $self->_set_dbFile($db,$file) : $self->_get_dbFile($db);


}

sub _set_dbFile {
  warn("setting db file not yet implemented");
}

sub _get_dbFile {
  my $self = shift;
  my $db = shift;
  my $dbh = $self->dbh();
  my ($sth,$rslt);

  $sth = $dbh->prepare("select db_file from DB where db_name = ?");
  $sth->bind_param(1,$db);
  $rslt = $self->_dbAction($dbh,$sth,2);

  if (ref $rslt eq 'ARRAY') {
    return $rslt->[0]->[0];
  } else {
    return 0;
  }

}

sub dbInfo {
  my $self = shift;
  my $dbh = $self->dbh();
  my ($sth,$dates,%date);

  $sth = $dbh->prepare("select D.displayName, D.dwnld_date, D.description, T.type, D.displayOrder, D.db_name from DB D, DBType T where D.db_type = T.number AND D.displayOrder > 0");

  $dates = $self->_dbAction($dbh,$sth,2);


  if (ref $dates eq 'ARRAY') {

    foreach my $ref (@$dates) {
#		print "Dababase: '$ref->[0]', Date: '$ref->[1]'<br>";
      $date{$ref->[0]} = [$ref->[1], $ref->[2], $ref->[3], $ref->[4], $ref->[5]];
    }
    return \%date;
  } else {
    return 0;
  }
}
