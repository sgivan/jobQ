package CGRBDB;
# $Id: CGRBDB.pm,v 3.19 2011/07/27 21:35:16 givans Exp $

use strict;
#use lib '/home/sgivan/lib/perl5';
use vars qw/ @ISA /;
use DBI qw(:sql_types);
use Exporter;
@ISA = qw/ DBI /;

my $debug = 0;
#my $HOST = 'ircf-login-0-1.local';
my $HOST = 'localhost';
my $port = 3306;

if ($debug) {
#  $| = 1;
  open(LOG,">/home/sgivan/log/CGRBDB.log") or die "can't open CGRBDB.log: $!";
  print LOG "\n\n", "+" x 50;
  print LOG "\nCGRBDB called: " . scalar(localtime()) . "\n\n";
}

1;


sub new {
  my $pkg = shift;
  my $obj;
  printlog("CGRBDB::new() called:  " . join ' ', caller()) if ($debug);
  if (ref($_[0])) {
    printlog("CGRBDB::new(): new was passed something") if ($debug);
    if (ref($_[0]) =~ /CGRB::(\S+)/) {  
      $obj = generate($pkg,$_[0]->{_dbase},$_[0]->{_user},$_[0]->{_pass},$_[0]->dbh(),@_);
      printlog("CGRBDB::new() was passed a CGRB::$1") if ($debug);
      return $obj;
    } elsif (ref($_[0]) eq 'HASH') {
       	printlog("CGRBDB::new() was passed a hash reference") if ($debug);
       	if (defined($_[0]->{host})) {
       		my $hashref = $_[0];
       		printlog("setting global \$HOST to '" . $hashref->{host} . "'") if ($debug);
       		_set_host($hashref->{host});
       		$obj = generate($pkg, $hashref->{db}, $hashref->{user}, $hashref->{password});
       		return $obj;
       	}
    } else {
    	printlog("CGRBDB::new() was passed a " . ref($_[0])) if ($debug);
    }

  } else {
    printlog("CGRBDB::new() was not passed a reference to anything") if ($debug);
  }
  $obj = generate($pkg,@_);
  return $obj;
}


sub generate {
#  my ($pkg,$dbase,$user,$pass,$dbh) = @_;
  my $pkg = shift;
  my $dbase = shift;
  my $user = shift;
  my $pass = shift;
  my $dbh = shift;

  if ($debug) {
    my ($p,$f,$l) = caller();
    printlog("creating '$pkg' object: $f, $l");
    printlog("\thost = '$HOST'\n\tdbase = '$dbase'\n\tuser = '$user'\n\tpass = '$pass'");
  }
  my $tries = 0;

  my $cgrb = bless {
 		     _dbase 	=>	$dbase,
 		     _user	=>	$user,
 		     _pass	=>	$pass,
 		     _host	=>	$HOST,
 		   }, $pkg;


  if ($dbh && (ref $dbh eq 'DBI::db')) {
#    print "reusing a dbh for package '$pkg'\n" if ($debug);
    $cgrb->dbh($dbh);
#    print "set dbh for package '$pkg'\n" if ($debug);
  } else {
    $cgrb->_dbConnect();
  }
  $cgrb->_initialize(@_) if ($cgrb->can('_initialize'));
  return $cgrb;

}

sub _dbConnect {
  my $self = shift;
#  return $self if ($self->{_init}{__PACKAGE__}++);
  return $self->dbh() if ($self->{_init}{dbConnect}++);
  my $dbase = $self->{_dbase};
  my $user = $self->{_user};
  my $pass = $self->{_pass};
#  my $host = $self->{_host};
  my ($tries,$dbh) = (0);
  printlog("connecting to $dbase as $user") if ($debug);
  my %attr = (
	      PrintError	=>	0,
	      RaiseError	=>	0,
	      );

  while ($tries < 1) {# this probably shouldn't be set to anything other than 1 unless there are connection problems
# DBI->connect("DBI:mysql:$dbase:$HOST;port=$port",$user,$pass,\%attr)) 
    if ($dbh = DBI->connect("DBI:mysql:$dbase:$HOST;port=$port",$user,$pass,\%attr)) {
      $tries = 0;
      $self->dbh($dbh);
	  printlog("connected to $dbase as $user") if ($debug);
      return $dbh;
    } else {
      warn($DBI::errstr);
	printlog($DBI::errstr) if ($debug);
      ++ $tries;
	  printlog("can't connect; sleeping 2 sec") if ($debug);
#      sleep(2);
      next;
    }
  }
  warn  "can't connect to database: $DBI::errstr" if ($tries > 3);
  printlog("can't connect to database: $DBI::errstr") if ($debug && $tries > 3);
  return undef;
}

sub dbAction {
  my $self = shift;
  $self->_dbAction(@_);
}

sub _ActionType {
  my $self = shift;
  my $int = shift;

  my %type = (
	      1	=>	'INSERT',
	      2	=>	'SELECT',
	      3	=>	'UPDATE',
	      4	=>	'DELETE',
	      5	=>	'LOCK',
	      6	=>	'UNLOCK',
	     );

  return $type{$int};
}

sub _dbAction {
   my ($obj,$dbh,$sth,$type) = @_;
 #
 # $type will be an integer > 0 indicating what type of action this should be
 # if it's a SELECT statement we need to return something (type = 2)
 # if it's an INSERT or UPDATE we don't need to return anything (type = 1, type = 3)
 # DELETE statements are type 4
 # LOCK statements are type 5
 # UNLOCK statements are type 6
 #
   my $tries;
   if ($debug) {
     my ($p,$f,$l) = caller();
     printlog("CGRBDB::_dbAction called: p = $p, f = $f, l = $l");
     my $actionType = $obj->_ActionType($type);
     print LOG "CGRBDB::_dbAction type = '$actionType'\n";
   }

 #  return [[$dbh->errstr]] unless ($sth);
   return undef unless ($sth);
#   printlog("retrieving db state") if ($debug);
#   my $db_state = $dbh->state();
   my ($rtn,$db_status,$loop) = (undef,0,0);
   my $db_state = 0;
    if (!$db_state) {
      printlog("pinging database ... ") if ($debug);
      if (my $ping = $dbh->ping()) {
		  printlog("connected") if ($debug);
        $db_status = 1;
      } else {
		  printlog("not connected") if ($debug);
		  $obj->{_init}{dbConnect} = 0;
		  $obj->_dbConnect();
	  }
    } else {
		printlog("db state: '$db_state'") if ($debug);
	}

 #  $db_status = 1;

   while ($db_status) {

     ++$loop;
    $sth->execute();

     if ($dbh->errstr) {
       printlog("CGRBDB::_dbAction - Trial $loop:  " . $dbh->errstr) if ($debug);
       return [[$dbh->errstr]] if ($loop == 3);
       $db_status = 1;
       sleep(1);
     } else {
       $db_status = 0;
     }
   }


   if ($type == 2) {
     printlog("fetching results") if ($debug);
     $rtn = $sth->fetchall_arrayref;
     if (ref $rtn ne 'ARRAY') {
       printlog("SELECT statement returned nothing") if ($debug);
       $rtn = undef;
     }
#     return $sth->fetchall_arrayref;
#   } else {
#     print LOG "returning 0 from CGRBDB\n" if ($debug);
#     return undef;
   }
   $sth->finish();

   return $rtn;
 }


sub printlog {
  my $mssg = shift;

  print LOG "$mssg\n" if ($mssg);
}

sub sselect {
  my $self = shift;
  $self->_sselect(@_);
}

sub _sselect {#

  my $obj = shift;
  my $dbh = $obj->dbh();
  my $Scolumn = shift;
  my $table = shift;
  my $Qcolumn = shift;
  my $Q = shift;
  my $order= shift;
  my ($sth,$query,@params);

  if ($debug) {
    my ($p,$f,$l) = caller();
    printlog("_sselect called:  $p, $f, $l");
    my $reftype = ref $obj;
    printlog("reftype: '$reftype'");
  }

  if ($Qcolumn && $Q) {
#    $query = "\n\nselect $Scolumn from $table where $Qcolumn = '$Q'";
    $query = "select $Scolumn from $table where $Qcolumn = '$Q'";
    @params = ($Scolumn, $table, $Qcolumn, $Q);
  } elsif ($Scolumn && $table) {
    $query = "select $Scolumn from $table";
    @params = ($Scolumn, $table);
  } else {
    return 0;
  }

  if ($order) {
    $query .= " order by $order desc";
    push(@params, $order);
  }
  printlog("_sselect query: '$query'\n") if ($debug);
  $sth = $dbh->prepare($query);

  my $rtn = $obj->_dbAction($dbh,$sth,2);

  return $rtn;
}

sub _lockTable {
  my $self = shift;
  my $dbh = $self->dbh();
  my $table = shift;
  my ($sth,$rtn);
  printlog("locking table $table") if ($debug);

  $sth = $dbh->prepare("LOCK TABLES $table");

  $rtn = $self->_dbAction($dbh,$sth,5);

  if (ref $rtn eq 'ARRAY') {
    if ($rtn->[0]) {
      return $rtn->[0]->[0];
    }
  }

  return undef;
}

sub _unlockTable {
  my $self = shift;
  my $dbh = $self->dbh();
  my ($sth,$rtn);
  printlog("unlocking tables") if ($debug);

  $sth = $dbh->prepare("unlock tables");

  $rtn = $self->_dbAction($dbh,$sth,6);

  if (ref $rtn eq 'ARRAY') {
    if ($rtn->[0]) {
      return $rtn->[0]->[0];
    }
  }

  return undef;
}

sub dbh {
  my $self = shift;
  my $dbh = shift;

  $dbh ? $self->_set_dbh($dbh) : $self->_get_dbh();
}

sub _set_dbh {
  my $self = shift;
  my $dbh = shift;

  $self->{_dbh} = $dbh;
}

sub _get_dbh {
  my $self = shift;

  return $self->{_dbh};
}

sub host {
  my $self = shift;
  my $host = shift;

#  $host ? $self->_set_host($host) : $self->_get_host();
  $host ? _set_host($host) : $self->_get_host();
}

sub _set_host {
#  my $self = shift;
  my $host = shift;
  #warn("not yet implemented");
  #return undef;
  
  $HOST = $host;
#  $self->{_host} = $HOST;
  return $HOST;
}

sub _get_host {
  my $self = shift;
  return $self->{_host};
}

sub DESTROY {
  my $self = shift;
#  return if ($self->{DESTROY}{__PACKAGE__}++);
  my $dbh = $self->dbh();
  $dbh->disconnect() if (ref($dbh) eq 'DBI::db');
}


=head1 Name

CGRBDB  base module of the CGRB:: architecture

=head1 Synopsis

use CGRB::CGRBDB;

my $cgrb = CGRBDB->generate('CGRBjobs', 'username', 'password');


B<Or, inherit from CGRBDB:>

use CGRB::CGRBDB;

@ISA = qw / CGRBDB /;

sub new {
    my $pkg;

    my $CGRB = $pkg->generate('CGRBjobs', 'username', 'password');

    if (ref $CGRB neq 'CGRBjobs') {
      print "ERROR:  $CGRB\n";
      die;
    }

    return $CGRB;

 }


B<Preferred idiom for database interactions:>

 my $rtn = $CGRB->dbAction($dbh,$sth,2);
 if ($rtn) {
    return $rtn->[0]->[0];
 } else {
    return undef;
 }

=head1 Description

This package serves as a base package for any other package that will interact with CGRB SQL databases.  It knows all the information necessary to establish a connection and return an active database handle.  It also imports all DBI methods, so inherited modules inherit DBI methods of the correct type (ie, mysql, oracle, etc.).  Almost all database actions should be routed through the dbAction method of CGRBDB.  This makes managing database handles easier and more stable.

=head1 Constructor

=head2 new( [CGRB:: object or hash reference] )

=over

new() will create a new CGRBDB object, which may or may not be connected to an actual database. If new() is passed a CGRB:: object that itself inherits from CGRBDB, then a new object will be created that re-uses the passed object's database handle. If new() is passed a hash reference containing a value for "host", then a new database handle will be generated that interacts with the host address passed. In either case, new() internally calls generate(), see below, to create the database handle. Currently, new() is the preferred method to use if connecting to a non-default database server. Such a connection could be achieved in a package inheriting from CGRBDB like this:

=over

  my $mgdb = $pkg->SUPER::new(
          { 
            host      =>  'my.server.name',
            db        =>  $db,
            user      =>  $user,
            password  =>  $password,
          }
     );

=back

=back




=head2 generate( PACKAGE, DATABASENAME, USERNAME, PASSWORD )

=over

Usually CGRBDB serves as the base class, so the package name is passed and the resulting object is blessed into the correct namespace.  Also, the name of the database, the username, and the password are required to connect.  If after 3 tries no connection can be established to the database a text message containing a description of the error will be returned as a scalar.  Otherwise a properly blessed object will be returned.  The reftype of the return value should be checked to make sure it is a) not a scalar b) of the correct package.

=back


=head1 Public Methods

B<dbAction($dbh, $sth, ACTIONTYPE)>

=over

=item Required Arguments:  database handle, statement handle, integer

=item Optional Arguments:  none

=item Return Value:  reference to an array reference or undef

=back

=over

Almost all actions on the SQL database should be routed through this method.  This enables more stable database connections and troubleshooting.  If a query fails it will be attempted 2 more times before it gives up.  If failure occurs 3 times an error message will be returned as a reference to an array.  The database handle and statement handle are the first two arguments passed.  The $sth should be fully self-contained, ie. all variables should be properly bound to the query before it gets here.  The ACTIONTYPE specifies whether dbAction() should return an arrayref containing the result of the query.  The current ACTIONTYPEs are as below:

                 1.  INSERT
                 2.  SELECT
                 3.  UPDATE
                 4.  DELETE
                 5.  LOCK
                 6.  UNLOCK

Therefore, currently only ACTIONTYPE 2 returns anything, unless an error occurs.  If something is returned, it is guaranteed to be a reference to an array.

=back


B<dbh([$dbh])>

=over

=item Required Arguments:  none

=item Optional Arguments:  database handle

=item Return Value:  database handle

=back

=over

Method either sets or returns current database handle.

=back

=cut

