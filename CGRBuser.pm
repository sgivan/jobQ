package CGRBuser;
# $Id: CGRBuser.pm,v 3.39 2009/02/27 00:12:45 givans Exp $
# checked for gacweb

use strict;
#no strict 'refs';
use Carp;
use warnings;
use Exporter;
use Config::Tiny;
#use lib '/home/cgrb/cgrblib/perl5/perl5.new';
use CGRB::CGRBDB;
use vars qw/ @ISA $AUTOLOAD /;

@ISA = qw/ CGRBDB /;
my $usertable = "jobUser";
my $labtable = "jobUserLab";
my $categorytable = "jobUserCategory";
#my $sessiondir = '/home/sgivan/apache/dev/htdocs/devnull';
my $sessiondir = '/var/www/html/devnull';
#my $sessiondir = '/tmp';

my $debug = 0;

if ($debug) {
  open(LOG, ">/tmp/CGRBuser.log") or die "can't open CGRBuser.log: $!";
  print LOG "\n\n";
  print LOG "+" x 50;
  print LOG "\nXXXCGRBuser called: " . scalar(localtime) . "\n\n";
}


1;

sub new {
  my $pkg = shift;
  my $login = shift;
  printlog("creating CGRBuser object") if ($debug);
  if ($debug) {
    print LOG join ' ', caller(), "\n";
  }

  my ($dbname,$dbuser,$dbpassword) = _getConfig();

  my $CGRBuser = $pkg->generate($dbname,$dbuser,$dbpassword,@_);
  
  if ($CGRBuser) {
    if ($login) {
      if ($CGRBuser->userExists($login)) {
	$CGRBuser->login($login);
      }
    }
  }

  return $CGRBuser;

}

sub addUser {
  my $obj = shift;
  my $login = shift;
  my $password = shift;
  my $firstname = shift;
  my $lastname = shift;
  my $lab = shift;
  my $phone = shift;
  my $email = shift;
  my $category = shift;
  $category = 2 unless ($category);
  my $dbh = $obj->{_dbh};

  if ($debug) {
    my ($p,$f,$l) = caller();
    printlog("addUser called from p: $p, f: $f, l: $l");
    printlog("Login = '$login'\nPassword = '$password'\nFirst = '$firstname'\nLast = '$lastname'");
    printlog("Lab = '$lab'\nPhone = '$phone'\nEmail = '$email'\nCategory = '$category'");
  }

#  my $sth = $dbh->prepare("insert into jobUser (Login, Password, First, Last, Lab, Phone, Email Category) values (?,md5(?),?,?,?,?,?,?)");
  my $sth = $dbh->prepare("insert into jobUser (Login, Password, First, Last, Lab, Phone, Email, Category) values (?,MD5(?),?,?,?,?,?,?)");
  $sth->bind_param(1,$login);
  $sth->bind_param(2,$password);
  $sth->bind_param(3,$firstname);
  $sth->bind_param(4,$lastname);
  $sth->bind_param(5,$lab, { TYPE => 5 } );
  $sth->bind_param(6,$phone, { TYPE => 12 } );
  $sth->bind_param(7,$email, { TYPE => 12 } );
  $sth->bind_param(8,$category, { TYPE => -6 } );

  my $rtn = $obj->_dbAction($dbh,$sth,1);

  if ($rtn) {
    return $rtn->[0]->[0];
  } else {
    return 0;
  }

}

sub txfrUser { ## this is a method that was used to transfer PSD users to jobUser table
  my $obj = shift;
  my $userID = shift;
  my $first = shift;
  my $last = shift;
  my $lab = shift;
  my $login = shift;
  my $phone = shift;
  my $email = shift;
  my $password = shift;
  my $category = shift;
  my $dbh = $obj->{_dbh};

  my $sth = $dbh->prepare("insert into jobUser (ID, Login, Password, Category, First, Last, Lab, Phone, Email) values (?,?,?,3,?,?,?,?,?)");
  $sth->bind_param( 1, $userID );
  $sth->bind_param( 2, $login );
  $sth->bind_param( 3, $password, { TYPE => 1 } );
  $sth->bind_param( 4, $first );
  $sth->bind_param( 5, $last );
  $sth->bind_param( 6, $lab );
  $sth->bind_param( 7, $phone, { TYPE => 12 } );
  $sth->bind_param( 8, $email, { TYPE => 12 } );

  $obj->_dbAction($dbh,$sth,1);

}

sub password {## 	Accessor method
  my $obj = shift;
  my $login = shift;
  my $password = shift;

  $password ? $obj->_setPassword($login,$password) : $obj->_getPassword($login);
}

sub _setPassword {
  my $obj = shift;
  my $login = shift;
  my $password = shift;
  my $dbh = $obj->{_dbh};
  my ($sth,$rtn);

  $sth = $dbh->prepare("update $usertable set Password = md5(?) where Login = ?");
  $sth->bind_param(1,$password);
  $sth->bind_param(2,$login);
  $rtn = $obj->_dbAction($dbh,$sth,3);

  if (ref $rtn eq 'ARRAY') {
    return $rtn->[0]->[0];
  } else {
    return 0;
  }
}

sub _getPassword {
  my $obj = shift;
  my $user = shift;
  my $dbh = $obj->{_dbh};
  print LOG "retrieving password from $usertable table\n" if ($debug);

  my $sth = $dbh->prepare("select Password from $usertable where Login = ?");
  $sth->bind_param(1,$user);

  my $rtn = $obj->_dbAction($dbh, $sth, 2);
  if (ref $rtn eq 'ARRAY') {
    return $rtn->[0]->[0];
  } else {
    return 0;
  }
#  return $obj->_dbAction($dbh, $sth, 2)->[0]->[0];

}

sub chkPassword {
  my $obj = shift;
  my $login = shift;
  my $password = shift;

  eval {
    require Digest::MD5;
    };
  if ($@) {
    die "can't load Digest::MD5 module: $@";
  }

  if (Digest::MD5::md5_hex($password) eq $obj->password($login)) {

    return 1;
  } else {
    if ($debug) {
      print LOG "CGRBuser:  passwords don't match\n";
      print LOG "password entered = '" . Digest::MD5::md5_hex($password) . "'\n";
      print LOG "password found  = '" . $obj->password($login) . "'\n";
    }
    return 0;
  }

}

sub getUsernames {
  my $obj = shift;
  my $dbh = $obj->{_dbh};

  my $sth = $dbh->prepare("select Login from jobUser order by Login");

  my $arrayref = $obj->_dbAction($dbh, $sth, 2);

  if (ref $arrayref eq 'ARRAY') {
    return $arrayref;
  } else {
    return 0;
  }
}

sub userinfo {
  my ($obj,$username) = @_;
  my $dbh = $obj->{_dbh};
  $obj->{_username} = $username;
#  print LOG "creating userinfo hash for '$username'\n" if ($debug);
  my ($sth,$userinfo,$rtn);

  $sth = $dbh->prepare("select u.ID usernum, u.First firstname, u.Last lastname, l.Name labname, u.Lab labnum, u.Login login, u.Phone phone, u.Email email from $usertable u, $labtable l where Login = ?");
  $sth->bind_param(1,$username);
#  return "can't prepare userinfo query: " . $dbh->errstr if (!$sth);
#  return "can't execute userinfo query: " . $dbh->errstr if (!$sth->execute);
#  my $userinfo = $sth->fetchrow_hashref;
#  $sth->finish;
  
  
  $rtn = $obj->_dbAction($dbh,$sth,2);
  if (ref $rtn eq 'ARRAY') {
	  my $row = $rtn->[0];
	  $userinfo->{usernum} = $row->[0];
	  $userinfo->{firstname} = $row->[1];
	  $userinfo->{lastname} = $row->[2];
	  $userinfo->{labname} = $row->[3];
	  $userinfo->{labnum} = $row->[4];
	  $userinfo->{login} = $row->[5];
	  $userinfo->{phone} = $row->[6];
	  $userinfo->{email} = $row->[7];
  

	  $obj->{_usernum} = $userinfo->{'usernum'};
	  $obj->{_firstname} = $userinfo->{'firstname'};
	  $obj->{_lastname} = $userinfo->{'lastname'};
	  $obj->{_labname} = $userinfo->{'labname'};
	  $obj->{_labnum} = $userinfo->{'labnum'};
	  $obj->{_login} = $userinfo->{'login'};
	  $obj->{_phone} = $userinfo->{'phone'};
	  $obj->{_email} = $userinfo->{'email'};
	  
	  return $userinfo;
  } else {
	  return 0;
  }

}

sub userExists {
  my $obj = shift;
  my $login = shift;
  my $dbh = $obj->{_dbh};

  if ($debug) {
    my ($p,$f,$l) = caller();
    printlog("userExists called: p: $p, f: $f, l: $l");
    printlog("determing whether '$login' exists");
  }

  my $sth = $dbh->prepare("select ID from jobUser where Login = ?");
  $sth->bind_param(1,$login);
#  no strict 'refs';
  my $rslt = $obj->_dbAction($dbh,$sth,2);

  if (ref($rslt) eq 'ARRAY') {
    if ($rslt->[0]->[0]) {
      printlog("$login exists") if ($debug);
      return 1;
    }
  }
  printlog("$login doesn't exist") if ($debug);
  return undef;
}

sub emailExists {
  my $self = shift;
  my $email = shift;
  my($dbh,$sth,$rtn);
  
  return undef unless ($email);
  
  $dbh = $self->dbh();
  $sth = $dbh->prepare("select ID from jobUser where Email = ?");
  $sth->bind_param(1,$email);
  my $rslt = $self->dbAction($dbh,$sth,2);
  
  if (ref($rslt) eq 'ARRAY') {
    if ($rslt->[0]->[0]) {
      printlog("$email exists") if ($debug);
      return $rslt->[0]->[0];
    }
  }
  printlog("$email doesn't exist") if ($debug);
  return undef;
}

sub labExists {
  my $obj = shift;
  my $lab = shift;
  my ($labs,$rtn);

  $labs = $obj->getLabs();
  if (ref $labs eq 'ARRAY') {
    foreach my $arr_ref (@$labs) {
      if ($arr_ref->[1] eq $lab) {
	$rtn = $arr_ref->[0];
	last;
      }
    }
  } else {
    $rtn = 0;
  }
  return $rtn;
}

sub firstname {			### Accessor
  my $obj = shift;
  my $login = shift;

#  @_ ? $obj->{'_firstname'} = shift : $obj->{'_firstname'};
  @_ ? $obj->_firstname($login,$_[0]) : $obj->_firstname($login);
}

sub _firstname {
  my $obj = shift;
  my $login = shift;
  my $firstname = shift;
  my $dbh = $obj->{_dbh};
  my ($sth,$rtn);

  if ($firstname) {
    $sth = $dbh->prepare("update $usertable set First = ? where Login = ?");
    $sth->bind_param(1,$firstname);
    $sth->bind_param(2,$login);
    $rtn = $obj->_dbAction($dbh,$sth,3);
  } else {
    $sth = $dbh->prepare("select First from $usertable where Login = ?");
    $sth->bind_param(1,$login);
    $rtn = $obj->_dbAction($dbh,$sth,2);
  }

  if (ref $rtn eq 'ARRAY') {
    return $rtn->[0]->[0];
  } else {
    return 0;
  }
  
}


sub lastname {			### Accessor
  my $obj = shift;
  my $login = shift;
  my $lastname = shift;

  $lastname ? $obj->_lastname($login,$lastname) : $obj->_lastname($login);
}

sub _lastname {
  my $obj = shift;
  my $login = shift;
  my $lastname = shift;
  my $dbh = $obj->{_dbh};
  my ($sth,$rtn);

  if ($lastname) {
    $sth = $dbh->prepare("update $usertable set Last = ? where Login = ?");
    $sth->bind_param(1,$lastname);
    $sth->bind_param(2,$login);
    $rtn = $obj->_dbAction($dbh,$sth,3);
  } else {
    $sth = $dbh->prepare("select Last from $usertable where Login = ?");
    $sth->bind_param(1,$login);
    $rtn = $obj->_dbAction($dbh,$sth,2);
  }

  if (ref $rtn eq 'ARRAY') {
    return $rtn->[0]->[0];
  } else {
    return 0;
  }
  
}

sub useremail {			### Accessor
  my $self = shift;
  my $login = shift;
  my $email = shift;

  printlog("accessing email address of user: '$login'") if ($debug);

#  $email ? $obj->_useremail($login,$email) : $obj->_useremail($login);
  $email ? $self->_set_useremail($login,$email) : $self->_get_useremail($login);

}

sub _set_useremail {
  my $self = shift;
  my $login = shift;
  my $email = shift;
  my $dbh = $self->dbh();
  my ($sth,$rtn);

  $sth = $dbh->prepare("update jobUser set Email = ? where Login = ?");
  $sth->bind_param(1,$email);
  $sth->bind_param(2,$login);

  $rtn = $self->_dbAction($dbh,$sth,3);

  if (ref $rtn eq 'ARRAY') {
    return $rtn->[0]->[0];
  } else {
    return 0;
  }
}

sub _get_useremail {
  my $self = shift;
  my $login = shift;
  my $dbh = $self->dbh();
  my ($sth,$rtn);

  $sth = $dbh->prepare("select Email from jobUser where Login = ?");
  $sth->bind_param(1,$login);

  $rtn = $self->_dbAction($dbh,$sth,2);

  if (ref $rtn eq 'ARRAY') {
    return $rtn->[0]->[0];
  } else {
    return 0;
  }
}

sub _useremail { ## This method isn't used ##
  my $obj = shift;
  my $login = shift;
  my $email = shift;
  my ($dbh,$sth,$rtn) = ($obj->{_dbh});

  printlog("retrieving email address for '$login'") if ($debug);

  if ($email) {
    $sth = $dbh->prepare("update jobUser set Email = ? where Login = ?");
    $sth->bind_param(1,$email);
    $sth->bind_param(2,$login);
    $rtn = $obj->_dbAction($dbh,$sth,3);
  } else {
    $sth = $dbh->prepare("select Email from jobUser where Login = ?");
    $sth->bind_param(1,$login);
    $rtn = $obj->_dbAction($dbh,$sth,2);
  }

  if (ref $rtn eq 'ARRAY') {
    return $rtn->[0]->[0];
  } else {
    return 0;
  }

}

sub usernum {			### Accessor
  my $obj = shift;
  my $username = shift;
#  printlog("CGRBuser::usernum called for '$username'") if ($debug);

  $username ? $obj->_set_usernum($username) : $obj->_get_usernum();

}

sub _set_usernum {
  my $self = shift;
  my $username = shift;

  printlog("setting usernum for '$username'") if ($debug);
    
  $self->userinfo($username);

  printlog("_usernum:  returning " . $self->{'_usernum'}) if ($debug);
  return $self->{_usernum};
}

sub _get_usernum {
  my $self = shift;
  my $usernum;

  printlog("attempting to access usernum from previous invocation") if ($debug);
  if ($self->{_usernum}) {
    printlog("usernum retrieved: $self->{_usernum}") if ($debug);
    $usernum = $self->{_usernum};
  } else {
    printlog("usernum cannot be retrieved") if ($debug);
#    return undef;
  }
  return $usernum;
}

# sub _usernum {
#   my $obj = shift;
#   my $username = shift;

#   if ($username) {
#     printlog("retrieving usernum for '$username'") if ($debug);
    
#     $obj->userinfo($username);

#     printlog("_usernum:  returning " . $obj->{'_usernum'}) if ($debug);
#     return $obj->{'_usernum'};
#   } else {
# 	  printlog("attempting to access usernum from previous invocation") if ($debug);
#     if ($obj->{_usernum}) {
# 		printlog("usernum retrieved") if ($debug);
#       return $obj->{_usernum};
#     } else {
# 		printlog("usernum cannot be retrieved") if ($debug);
#       return 0;
#     }
#   }
# }

sub login {			## Accessor
  my $self = shift;
  my $user = shift;

  $user ? $self->_set_login($user) : $self->_get_login();
}

sub _set_login {
  my $self = shift;
  my $user = shift;
  printlog("setting login name to '$user'") if ($debug);
  $self->userinfo($user);
  $self->{_login} = $user;

}

sub _get_login {
  my $self = shift;
  my $login;

  if ($self->{_login}) {
    $login = $self->{_login};
  }#  else {

#     eval {
#       require Apache;
#       };

#     if ($@) {
#       warn("can't retrieve Apache module");
#     }

#     my $r; ## will become the Apache request object;
#     Apache->request($r);

#     if ($self->logged_in($r)) {
#       $login = $self->login();
#     }

#   }

  if ($login) {
    printlog("returning login: '$login'") if ($debug);
    return $login;
  } else {
    printlog("cannot determine login name") if ($debug);
    return undef;
  }
}

sub userName { # accessor to g/set user login name
  my $self = shift;
  my $userID = shift;
  my $userName = shift;

  $userName ? $self->_set_userName($userID,$userName) : $self->_get_userName($userID);

}

sub _set_userName {
  my $self = shift;
  my $userID = shift;
  my $userName = shift;
  my $dbh = $self->dbh();
  my ($sth,$rtn);

  $sth = $dbh->prepare("update jobUser set Login = ? where ID = ?");
  $sth->bind_param(1,$userName);
  $sth->bind_param(2,$userID);

  $rtn = $self->_dbAction($dbh,$sth,3);

  if (ref $rtn eq 'ARRAY') {
    return $rtn->[0]->[0];
  } else {
    return 0;
  }

}
sub _get_userName {
  my $self = shift;
  my $userID = shift;
  my $dbh = $self->dbh();
  my ($sth,$rtn);

  $sth = $dbh->prepare("select Login from jobUser where ID = ?");
  $sth->bind_param(1,$userID);

  $rtn = $self->_dbAction($dbh,$sth,2);

  if (ref $rtn eq 'ARRAY') {
    return $rtn->[0]->[0];
  } else {
    return 0;
  }
}

sub logged_in {
  my $obj = shift;
  my $r = shift;# new: expecting an Apache2::Request object
  my $status;
    print LOG "determining whether user is logged in\n" if ($debug);

  if ($debug) {
    my ($p,$f,$l) = caller();
    printlog("logged_in called - p: $p, f: $f, l: $l");
  }

#	I could use the $r object to set a new cookie
#	or change the content of the CGRBID cookie
#
#   eval {
#     require Apache::Request;
#     };

#   if ($@) {
#     die "can't require Apache::Request: $@";
#   }

#    Apache::Cookie->new($r,
#  		      name	=>	'CGRBtest',
#  		      value	=>	'this is a test',
#  		      path	=>	'/',
#  		      )->bake;

#  if ($r->header_in('Cookie')) {
#    if ($r->header_in('Cookie') =~ /CGRBID=(\w+)/) {
#      my $session_id = $1;
    my $session_id = $obj->get_session_id($r);
    if ($session_id) {
      my $session = $obj->session($session_id);

      my $login = $session->{username};
      print LOG "session id is '$session_id'\nlogin is '$login'\n" if ($debug);
      if ($login && $obj->userExists($login)) {
	    $status = 1;
	    $obj->login($login);
      } else {
	    $status = 0;
      }
    } else {
        print LOG "could not retrieve session ID\n" if ($debug);
      $status = 0;
    }
#  } else {
#    $status = 0;
#  }
    print LOG "returning status = '$status'\n" if ($debug);	
  return $status;
}

sub logged_in_cgi {
  my $obj = shift;
  my $cgi = shift;
  my $status = 0;
  printlog("logged_in_cgi called") if ($debug);


  if (!$cgi || ref($cgi) !~ /CGI/) {
    printlog("must create a new CGI object") if ($debug);
	  eval {
		  require CGI;
	  };

	  if ($@) {
		  die "can't get CGI: $@";
	  }

	  $cgi = CGI->new();
  }

#  my $username = $cgi->cookie('CGRBID');
  my $session_id = $cgi->cookie('CGRBID');

  my $session = $obj->session($session_id);
  my $username = $session->{username};

  if ($username) {
    if ($obj->userexists($username)) {
      $obj->login($username);
      $status = 1;
    }
  }

#  return $status;
    return $username;

}

sub localchk {
  my $obj = shift;
  my $r = shift;#new: expecting an Apache2::Request object
    # not sure if this is fixed yet
  my $ip = $r->connection->remote_ip();

#  if ($ip =~ /^128\.193\.\d{1,3}\.\d{1,3}/ || $ip =~ /^10\.\d{1,3}\.\d{1,3}\.\d{1,3}/) {
  if ($ip =~ /^128\.206\.\d{1,3}\.\d{1,3}/ || $ip =~ /^10\.\d{1,3}\.\d{1,3}\.\d{1,3}/) {
    return 1;
  } else {
    return 0;
  }

}

sub authenticate {
  my $obj = shift;
  my $r = shift;# new: expecting an Apache2::Request object
  my $user = shift;
  my $password = shift;
  my $status;
    print LOG "authenticating '$user' with password '$password'\n" if ($debug);
    print LOG "\$r isa '", ref($r), "'\n" if ($debug);

  eval {
    require Apache2::Cookie;
  };
  if ($@) {
    return "can't load Apache2::Cookie: $@";
  }

    print LOG "checking password...\n" if ($debug);
  if ($obj->chkPassword($user,$password)) {

#     my %cookies = Apache::Cookie->fetch;

#     if (exists $cookies{CGRBID}) {
#       $cookies{CGRBID}->value($user);
#       $cookies{CGRBID}->path('/');
#       $cookies{CGRBID}->bake;
#     } else {

        print LOG "password matched, setting session\n" if ($debug);
       my $session = $obj->session();
        print LOG "\$session isa '", ref($session), "'\n" if ($debug);
       $session->{username} = $user;

        print LOG "setting cookie in browser\n" if ($debug);
       my $cookie = Apache2::Cookie->new($r,
                        -name	=>	'CGRBID',
                        -value	=>	$session->{_session_id},
                        -expires=> '+4hr',
#                        -path	=>	'/genomes',
			-path	=>	'/',
                        -domain =>  '.ircf.missouri.edu',
 				      );
       $cookie->bake($r);
#    }
    $status = 1;
  } else {
    $status = 0;
  }

  print LOG "returning status = '$status'" if ($debug);
  return $status;
}

sub session {
  my $self = shift;
  my $session_id = shift;
  printlog("session called") if ($debug);

  $session_id ? $self->_get_session($session_id) : $self->_set_session();
}

sub _set_session {
  my $self = shift;
  my %session;
  printlog("_set_session called") if ($debug);

  eval {
    require Apache::Session::File;
  };

  if ($@) {
    die "can't find Apache::Session::File: $@";
  }

  tie %session, 'Apache::Session::File', undef, {
#						 Directory	=>	'/data/www/html/devnull',
						 Directory	=>	$sessiondir,
#						 LockDirectory	=>	'/data/www/html/devnull',
						 LockDirectory	=>	$sessiondir,
						};

  return \%session;
}

sub _get_session {
  my $self = shift;
  my $session_id = shift;
  my %session;
  printlog("_get_session called; session id = '$session_id'") if ($debug);

  eval {
    require Apache::Session::File;
  };

  if ($@) {
    die "can't find Apache::Session::File: $@";
  }

  eval { tie %session, 'Apache::Session::File', $session_id, {
#							      Directory		=>	'/data/www/html/devnull',
							      Directory		=>	$sessiondir,
#							      LockDirectory	=>	'/data/www/html/devnull',
							      LockDirectory	=>	$sessiondir,
							     };
       };

  if ($@) {
    return undef;
  } else {
    return \%session;
  }
}

sub get_session_id {
  my $self = shift;
  my $r = shift;
  my $session_id;
    if ($debug) {
        print LOG "get_session_id() called\n";
        print LOG "\$r isa '", ref($r), "'\n";
    }
  return undef unless ($r && ref($r) eq 'Apache2::RequestRec');
    print LOG "retrieving cookie ...\n" if ($debug);

  if ($r->headers_in->{Cookie}) {
    if ($r->headers_in->{Cookie} =~ /CGRBID=(\w+)/) {
      $session_id = $1;
    }
  }

  if ($session_id) {
    return $session_id;
  } else {
    return undef;
  }
}

sub logout {
    my $obj = shift;
    my $r = shift;# new: expecting an Apache::Request object
    my $status = 0;
    printlog("logout called") if ($debug);
    printlog("\$r isa '" . ref($r) . "'") if ($debug);
    # return $status unless ($r);


    eval {
        require Apache2::Cookie;
    };
    if ($@) {
     die "can't require Apache2::Cookie";
    }

    my $j = Apache2::Cookie::Jar->new($r);
    my $c_in = $j->cookies("CGRBID");

#    if ($debug) {
#        printlog("got a cookie from the cookie jar");
#        printlog("\$c_in isa '". ref($c_in) . "'");
#        printlog("path is '" . $c_in->path() . "'");
#        printlog("cookie name: '" . $c_in->name() . "'");
#        printlog("cookie value: '" . $c_in->value() . "'");
#        printlog("as string: '" . $c_in->as_string() . "'");
#        printlog("domain: '" . $c_in->domain() . "'");
#        printlog("version: '" . $c_in->version() . "'");
##        printlog("expires: '" . $c_in->expires() . "'");# expires is set-only
#    }

    if ($c_in && $c_in->isa('Apache2::Cookie')) {
	$c_in->path('/');
	$c_in->domain('.ircf.missouri.edu');
        $c_in->expires('-1h');
        $c_in->bake($r);
    }

#    my %cookies = Apache2::Cookie->fetch($r);
#
#    printlog("cookies retrieved. Now resetting expire setting to '-1h' for CGRBID.") if ($debug);
#    if (exists $cookies{CGRBID}) {
#        #     $cookies{CGRBID}->value(undef);
#        #     $cookies{CGRBID}->path('/');
#        printlog("cookie isa '" . ref($cookies{CGRBID}) . "'") if ($debug);
#        #my $expires = $cookies{CGRBID}->expires();
#        my $domain = $cookies{CGRBID}->domain();
#        printlog("domain is '$domain'") if ($debug);
#        $cookies{CGRBID}->expires('-1h');
##        printlog("cookie now expires: '" . $cookies{CGRBID}->expires() . "'") if ($debug);
#        $cookies{CGRBID}->bake($r);
#        $status = 1;
#        printlog("set cookie to expire '-1h'") if ($debug);
#    }

    return $status;
}

sub logout_cgi {
  my $obj = shift;
  my $r = shift;# expecting an Apache::Request object
  my $status = 0;

  eval {
    require CGI::Cookie;
    };
  if ($@) {
    die "can't require Apache::Cookie";
  }

  my %cookies = CGI::Cookie->fetch;
  if (exists $cookies{CGRBID}) {
     $cookies{CGRBID}->path('/');
    $cookies{CGRBID}->expires('-1h');
    $status = 1;
  }

  return $cookies{CGRBID};
}


sub labid {
  my $obj = shift;
  my $login = shift;
  my $labid = shift;
  printlog("CGRBuser::labid called for '$login'") if ($debug);

  $labid ? $obj->_labid($login,$labid) : $obj->_labid($login);

}

sub _labid {
  my $obj = shift;
  my $login = shift;
  my $labid = shift;
  my $dbh = $obj->{_dbh};
  my ($sth,$rtn);
  printlog("accessing labid for '$login'") if ($debug);

  if ($labid) {
    $sth = $dbh->prepare("update jobUser set Lab = ? where Login = ?");
    $sth->bind_param(1,$labid);
    $sth->bind_param(2,$login);
    $rtn = $obj->_dbAction($dbh,$sth,3);
  } else {
    $sth = $dbh->prepare("select Lab from jobUser where Login = ?");
    $sth->bind_param(1,$login);
    $rtn = $obj->_dbAction($dbh,$sth,2);
  }

  if (ref $rtn eq 'ARRAY') {
    return $rtn->[0]->[0];
  } else {
    return 0;
  }

}

sub labname {
  my $obj = shift;
  my $login = shift;

  @_ ? $obj->_labname($login,$_[0]) : $obj->_labname($login);

}

sub _labname {
  my $obj = shift;
  my $login = shift;
  my $labname = shift;
  my ($dbh,$sth,$rtn) = ($obj->{_dbh});

  if ($labname) {
    $rtn = "Not yet implemented";
    return $rtn;
  } else {
    $sth = $dbh->prepare("select L.Name from jobUserLab L, jobUser U where U.Lab = L.ID AND U.Login = ?");
    $sth->bind_param(1,$login);
    $rtn = $obj->_dbAction($dbh,$sth,2);
  }

  if (ref $rtn eq 'ARRAY') {
    return $rtn->[0]->[0];
  } else {
    return 0;
  }
}

sub userCategory {
  my $obj = shift;
  my $userID = shift;
  my $category = shift;

  $category ? $obj->_setuserCategory($userID,$category) : $obj->_getuserCategory($userID);

}

sub _setuserCategory {
  my $obj = shift;
  my $userID = shift;
  my $category = shift;

}

sub _getuserCategory {
  my $obj = shift;
  my $userID = shift;
  my $dbh = $obj->{_dbh};
  my ($sth,$rtn);

  $sth = $dbh->prepare("select U.Category, C.Title from jobUser U, jobUserCategory C where U.ID = ? AND U.Category = C.ID");
  $sth->bind_param(1,$userID);
  $rtn = $obj->_dbAction($dbh,$sth,2);

  if (ref $rtn eq 'ARRAY') {
    return $rtn->[0];
  } else {
    return 0;
  }

}

sub userLimit {
  my $self = shift;
  my $params = shift;
  my $userID = $params->{userID} || $self->usernum();
  #my $user_category = $self->userCategory($userID);
  my $limit = $params->{Limit};
  my $value = $params->{Value};

  return undef unless ($userID && $limit);

  $value ? $self->_setuserLimit($limit,$value) : $self->_getuserLimit($limit);

}

sub _setuserLimit {
  my $self = shift;
  my $limit = shift;
  my $value = shift;

  $self->{userlimit}->{$limit} = $value;
  return $self->{userlimit}->{$limit};
}

sub _getuserLimit {
  my $self = shift;
  my $limit = shift;

  if (! $self->{userlimit}->{$limit}) {
    my $dbh = $self->dbh();
    #my $user_category = $self->userCategory($self->usernum())->[0];
    my ($sth,$rtn);

    $sth = $dbh->prepare("select `Value` from `jobUserLimits` where `UserID` = ? AND `Limit` = ?");
    $sth->bind_param(1,$self->usernum());
    $sth->bind_param(2,$limit);

    $rtn = $self->dbAction($dbh,$sth,2);

    if (ref $rtn eq 'ARRAY') {
      $self->userLimit( { Limit => $limit, Value => $rtn->[0]->[0] } ) if ($rtn->[0]->[0]);
    }
  }
  return $self->{userlimit}->{$limit};
}

sub userCategoryLimit {
  my $self = shift;
  my $params = shift;
  my $userID = $params->{userID} || $self->usernum();
  my $user_category = $self->userCategory($userID);
  my $limit = $params->{Limit};
  my $value = $params->{Value};

  return undef unless ($userID && $limit);

  $value ? $self->_setuserCategoryLimit($limit,$value) : $self->_getuserCategoryLimit($limit);

}

sub _setuserCategoryLimit {
  my $self = shift;
  my $limit = shift;
  my $value = shift;

  $self->{limit}->{$limit} = $value;
  return $self->{limit}->{$limit};
}

sub _getuserCategoryLimit {
  my $self = shift;
  my $limit = shift;

  if (! $self->{limit}->{$limit}) {
    my $dbh = $self->dbh();
    my $user_category = $self->userCategory($self->usernum())->[0];
    my ($sth,$rtn);

    $sth = $dbh->prepare("select `Value` from `jobUserCategoryLimits` where `Category` = ? AND `Limit` = ?");
    $sth->bind_param(1,$user_category);
    $sth->bind_param(2,$limit);

    $rtn = $self->dbAction($dbh,$sth,2);

    if (ref $rtn eq 'ARRAY') {
      $self->userCategoryLimit( { Limit => $limit, Value => $rtn->[0]->[0] } ) if ($rtn->[0]->[0]);
    }
  }

  return $self->{limit}->{$limit};
}

sub newUserGroup {
  my $self = shift;
  my $groupName = shift;
  my $descr = shift;
  my $userID = shift;
  $groupName = 'New Group' if (!$groupName);
  my $dbh = $self->dbh();
  my $userName = $self->login();
  $descr = "created by $userName" unless ($descr);
  $userID = $self->usernum($userName) unless ($userID);
  my ($sth,$rtn);

  $self->_lockTable('jobUserGroupList');

  $sth = $dbh->prepare("insert into jobUserGroupList (NAME,DESCR,OWNER) values (?,?,?)");
  $sth->bind_param(1,$groupName);
  $sth->bind_param(2,$descr);
  $sth->bind_param(3,$userID);

  $rtn = $self->_dbAction($dbh,$sth,1);

  if (ref $rtn eq 'ARRAY') {
    $self->_unlockTable();
    return $rtn->[0]->[0];
  } else {

    $sth = $dbh->prepare("select max(ID) from jobUserGroupList");
    $rtn = $self->_dbAction($dbh,$sth,2);
    $self->unlockTable();

    if (ref $rtn eq 'ARRAY') {
      return $rtn->[0]->[0];
    } else {
      return 0;
    }
  }

}

sub getAllGroupID { # get a list of all current group ID's
  my $self = shift;
  my $dbh = $self->dbh();
  my ($sth,$rtn);

  $sth = $dbh->prepare("select ID from jobUserGroupList");

  $rtn = $self->_dbAction($dbh,$sth,2);

  if (ref $rtn eq 'ARRAY') {
    return $rtn;
  } else {
    return 0;
  }
}

sub userGroupMembers {
  my $self = shift;
  my $groupID = shift;
  my $dbh = $self->dbh();
  my ($sth,$rtn);

  $sth = $dbh->prepare("select UserID from jobUserGroup where GroupID = ?");
  $sth->bind_param(1,$groupID);

  $rtn = $self->_dbAction($dbh,$sth,2);

  if (ref $rtn eq 'ARRAY') {
    return $rtn;
  } else {
    return 0;
  }

}

sub groupName { # accessor for g/setting group Names
  my $self = shift;
  my $groupID = shift;
  my $groupName = shift;

  $groupName ? $self->_set_groupName($groupID,$groupName) : $self->_get_groupName($groupID);

}

sub _set_groupName { # only group owners should be able to do this
  my $self = shift;
  my $groupID = shift;
  my $groupName = shift;
  my $dbh = $self->dbh();
  my ($sth,$rtn);
#  print "<p>usernum = " . $self->usernum() . "</p>";
#  print "<p>login = " . $self->login() . "</p>";
#  if ($self->user_isGroupOwner($self->usernum($self->login()),$groupID)) {
    
    $sth = $dbh->prepare("update jobUserGroupList set NAME = ? where ID = ?");
    $sth->bind_param(1,$groupName);
    $sth->bind_param(2,$groupID);
    
    $rtn = $self->_dbAction($dbh,$sth,3);
    
#  }

  if (ref $rtn eq 'ARRAY') {
    return $rtn->[0]->[0];
  } else {
    return 0;
  }
}

sub _get_groupName {
  my $self = shift;
  my $groupID = shift;
  my $dbh = $self->dbh();
  my ($sth,$rtn);

  $sth = $dbh->prepare("select NAME from jobUserGroupList where ID = ?");
  $sth->bind_param(1,$groupID);

  $rtn = $self->_dbAction($dbh,$sth,2);

  if (ref $rtn eq 'ARRAY') {
    return $rtn->[0]->[0];
  } else {
    return 0;
  }
}

sub groupDescription { # accessor to g/set group descriptions
  my $self = shift;
  my $groupID = shift;
  my $descr = shift;

  $descr ? $self->_set_groupDescription($groupID,$descr) : $self->_get_groupDescription($groupID);

}

sub _set_groupDescription { # only group owners should be able to do this
  my $self = shift;
  my $groupID = shift;
  my $descr = shift;
  my $dbh = $self->dbh();
  my ($sth,$rtn);

#  if ($self->user_isGroupOwner($self->usernum(),$groupID)) {

    $sth = $dbh->prepare("update jobUserGroupList set DESCR = ? where ID = ?");
    $sth->bind_param(1,$descr);
    $sth->bind_param(2,$groupID);

    $rtn = $self->_dbAction($dbh,$sth,3);
#  }

  if (ref $rtn eq 'ARRAY') {
    return $rtn->[0]->[0];
  } else {
    return 0;
  }
}

sub _get_groupDescription {
  my $self = shift;
  my $groupID = shift;
  my $dbh = $self->dbh();
  my ($sth,$rtn);

  $sth = $dbh->prepare("select DESCR from jobUserGroupList where ID = ?");
  $sth->bind_param(1,$groupID);

  $rtn = $self->_dbAction($dbh,$sth,2);

  if (ref $rtn eq 'ARRAY') {
    return $rtn->[0]->[0];
  } else {
    return 0;
  }
}

sub groupOwner { ## accessor to g/set group Owner
  my $self = shift;
  my $groupID = shift;
  my $userID = shift;

  $userID ? $self->_set_groupOwner($groupID,$userID) : $self->_get_groupOwner($groupID);
}

sub _set_groupOwner { ## only users with appropriate privileges can do this
  my $self = shift;
  my $groupID = shift;
  my $userID = shift;
  my $dbh = $self->dbh();
  my ($sth,$rtn);

  $sth = $dbh->prepare("update `jobUserGroupList` set `OWNER` = ? where `ID` = ?");
  $sth->bind_param(1,$userID);
  $sth->bind_param(2,$groupID);

  $rtn = $self->_dbAction($dbh,$sth,3);

  if (ref $rtn eq 'ARRAY') {
    return $rtn->[0]->[0];
  } else {
    return 0;
  }
}

sub _get_groupOwner {
  my $self = shift;
  my $groupID = shift;
  my $dbh = $self->dbh();
  my ($sth,$rtn);

  $sth = $dbh->prepare("select `OWNER` from `jobUserGroupList` where `ID` = ?");
  $sth->bind_param(1,$groupID);

  $rtn = $self->_dbAction($dbh,$sth,2);

  if (ref $rtn eq 'ARRAY') {
    return $rtn->[0]->[0];
  } else {
    return 0;
  }
}

sub groupPublish {
  my $self = shift;
  my $groupID = shift;
  my $publish = shift;

  $publish ? $self->_set_groupPublish($groupID,$publish) : $self->_get_groupPublish($groupID);
}

sub _set_groupPublish {
  my $self = shift;
  my $groupID = shift;
  my $publish = shift;
  my $dbh = $self->dbh();
  my ($sth,$rtn);

  $publish = -1 unless ($publish == 1);

  $sth = $dbh->prepare("update `jobUserGroupList` set `PUBLISH` = ? where `ID` = ?");
  $sth->bind_param(1,$publish);
  $sth->bind_param(2,$groupID);

  $rtn = $self->_dbAction($dbh,$sth,3);

  if (ref $rtn eq 'ARRAY') {
    return $rtn->[0]->[0];
  } else {
    return undef;
  }
}

sub _get_groupPublish {
  my $self = shift;
  my $groupID = shift;
  my $dbh = $self->dbh();
  my ($sth,$rtn);

  $sth = $dbh->prepare("select `PUBLISH` from `jobUserGroupList` where `ID` = ?");
  $sth->bind_param(1,$groupID);

  $rtn = $self->_dbAction($dbh,$sth,2);

  if (ref $rtn eq 'ARRAY') {
    return $rtn->[0]->[0];
  } else {
    return undef;
  }
}

sub groupLongDescription {
  my $self = shift;
  my $groupID = shift;
  my $descr = shift;

  $descr ? $self->_set_groupLongDescription($groupID,$descr) : $self->_get_groupLongDescription($groupID);
}

sub _set_groupLongDescription {
  my $self = shift;
  my $groupID = shift;
  my $descr = shift;
  my ($dbh,$sth,$rtn) = ($self->dbh());

  $descr = '' if ($descr eq 'DELETE');

  $sth = $dbh->prepare("update `jobUserGroupList` set `LONG_DESCR` = ? where `ID` = ?");
  $sth->bind_param(1,$descr);
  $sth->bind_param(2,$groupID);

  $rtn = $self->_dbAction($dbh,$sth,3);

  if (ref $rtn eq 'ARRAY') {
    return $rtn->[0]->[0];
  } else {
    return undef;
  }
}

sub _get_groupLongDescription {
  my $self = shift;
  my $groupID = shift;
  my $dbh = $self->dbh();
  my ($sth,$rtn);

  $sth = $dbh->prepare("select `LONG_DESCR` from `jobUserGroupList` where `ID` = ?");
  $sth->bind_param(1,$groupID);

  $rtn = $self->_dbAction($dbh,$sth,2);

  if (ref $rtn eq 'ARRAY') {
    return $rtn->[0]->[0];
  } else {
    return undef;
  }
}

sub groupParentName {
  my $self = shift;
  my $groupID = shift;
  my $parentName = shift;

  $parentName ? $self->_set_groupParentName($groupID,$parentName) : $self->_get_groupParentName($groupID);
}

sub _set_groupParentName {
  my $self = shift;
  my $groupID = shift;
  my $groupParentName = shift;
  my ($dbh,$sth,$rtn) = ($self->dbh());

  $groupParentName = '' if ($groupParentName eq 'DELETE');

  $sth = $dbh->prepare("update `jobUserGroupList` set `PARENT_NAME` = ? where `ID` = ?");
  $sth->bind_param(1,$groupParentName);
  $sth->bind_param(2,$groupID);

  $rtn = $self->dbAction($dbh,$sth,3);

  if (ref $rtn eq 'ARRAY') {
    return $rtn->[0]->[0];
  } else {
    return undef;
  }
}

sub _get_groupParentName {
  my $self = shift;
  my $groupID = shift;
  my ($dbh,$sth,$rtn) = ($self->dbh());

  $sth = $dbh->prepare("select `PARENT_NAME` from `jobUserGroupList` where `ID` = ?");
  $sth->bind_param(1,$groupID);

  $rtn = $self->dbAction($dbh,$sth,2);

  if (ref $rtn eq 'ARRAY') {
    return $rtn->[0]->[0];
  } else {
    return undef;
  }
}

sub groupParentLink {
  my $self = shift;
  my $groupID = shift;
  my $groupParentLink = shift;

  $groupParentLink ? $self->_set_groupParentLink($groupID,$groupParentLink) : $self->_get_groupParentLink($groupID);
}

sub _set_groupParentLink {
  my $self = shift;
  my $groupID = shift;
  my $groupParentLink = shift;
  my ($dbh,$sth,$rtn) = ($self->dbh());

  $groupParentLink = '' if ($groupParentLink eq 'DELETE');

  $sth = $dbh->prepare("update `jobUserGroupList` set `PARENT_LINK` = ? where `ID` = ?");
  $sth->bind_param(1,$groupParentLink);
  $sth->bind_param(2,$groupID);

  $rtn = $self->dbAction($dbh,$sth,3);

  if (ref $rtn eq 'ARRAY') {
    return $rtn->[0]->[0];
  } else {
    return undef;
  }
}

sub _get_groupParentLink {
  my $self = shift;
  my $groupID = shift;
  my ($dbh,$sth,$rtn) = ($self->dbh());

  $sth = $dbh->prepare("select `PARENT_LINK` from `jobUserGroupList` where `ID` = ?");
  $sth->bind_param(1,$groupID);

  $rtn = $self->dbAction($dbh,$sth,2);

  if (ref $rtn eq 'ARRAY') {
    return $rtn->[0]->[0];
  } else {
    return undef;
  }
}

sub groupBlastPrefs {
  my $self = shift;
  my $groupID = shift;
  my $groupBlastPrefs = shift;
  my $groupOtherPrefs = shift;

  $groupBlastPrefs ? $self->_set_groupBlastPrefs($groupID,$groupBlastPrefs,$groupOtherPrefs) : $self->_get_groupBlastPrefs($groupID);
}

sub _set_groupBlastPrefs {
  my $self = shift;
  my $groupID = shift;
  my $groupBlastPrefs = shift;
  my $groupOtherPrefs = shift;
  my ($dbh,$sth,$rtn) = ($self->dbh());
#  my $saved_groupBlastPrefs = $self->_get_groupBlastPrefs($groupID);

  $groupBlastPrefs = '' if ($groupBlastPrefs eq 'DELETE');
	my $blastprefstring = "blastall=\"$groupBlastPrefs\"";
	my $otherprefstring = "other=\"$groupOtherPrefs\"";

  $sth = $dbh->prepare("update `jobUserGroupList` set `BLAST_PREFS` = ? where `ID` = ?");
#  $sth->bind_param(1,$groupBlastPrefs);
#  $sth->bind_param(1,$blastprefstring);
  $sth->bind_param(1,"$blastprefstring $otherprefstring");
  $sth->bind_param(2,$groupID);

  $rtn = $self->dbAction($dbh,$sth,3);

  if (ref $rtn eq 'ARRAY') {
    return $rtn->[0]->[0];
  } else {
    return undef;
  }
}

sub _get_groupBlastPrefs {
  my $self = shift;
  my $groupID = shift;
  my ($dbh,$sth,$rtn) = ($self->dbh());

  $sth = $dbh->prepare("select `BLAST_PREFS` from `jobUserGroupList` where `ID` = ?");
  $sth->bind_param(1,$groupID);

  $rtn = $self->dbAction($dbh,$sth,2);

  if (ref $rtn eq 'ARRAY') {
    
    my $prefstring = $rtn->[0]->[0];
    my $blastprefstring = '';
    if ($prefstring) {
        if ($prefstring =~ /blastall\=\"(.+?)\"/) {
                $blastprefstring = $1;
        }
        if ($prefstring =~ /other\=\"(.+?)\"/) {
            $blastprefstring .= " $1";
        }
    }

    if ($blastprefstring =~ /\w+/) {
        return $blastprefstring;
    }

  }
  return undef;
}

sub getGroups { # get all group memberships for a user
  my $self = shift;
  my $userID = shift;
  my $dbh = $self->dbh();
  my ($sth,$rtn);

  $sth = $dbh->prepare("select `GroupID` from `jobUserGroup` where `UserID` = ?");
  $sth->bind_param(1,$userID);

  $rtn = $self->_dbAction($dbh,$sth,2);

  if (ref $rtn eq 'ARRAY') {
    return $rtn;
  } else {
    return undef;
  }
}

sub userGroup { # accessor method for g/setting userGroup
  my $self = shift;
  my $userID = shift;
  my $groupID = shift;

  $groupID ? $self->_set_userGroup($userID,$groupID) : $self->_get_userGroup($userID);
}

sub _set_userGroup {
  my $self = shift;
  my $userID = shift;
  my $groupID = shift;
  my $dbh = $self->dbh();
  my ($sth,$rtn);

  unless ($self->user_isGroupMember($userID,$groupID)) {

    $sth = $dbh->prepare("insert into jobUserGroup (UserID, GroupID) values (?,?)");
    $sth->bind_param(1,$userID);
    $sth->bind_param(2,$groupID);

    $rtn = $self->_dbAction($dbh,$sth,1);

    if (ref $rtn eq 'ARRAY') {
      return ->[0]->[0];
    }

  } else {
    return 0;
  }
}

sub _get_userGroup {
  my $self = shift;
  my $userID = shift;

  $self->getGroups($userID);

}

sub remove_userGroup { # Removes a user from a User Group
  my $self = shift;
  my $userID = shift;
  my $groupID = shift;
  my $dbh = $self->dbh();
  my ($sth,$rtn);

  $sth = $dbh->prepare("delete from jobUserGroup where UserID = ? AND GroupID = ?");
  $sth->bind_param(1,$userID);
  $sth->bind_param(2,$groupID);

  $rtn = $self->_dbAction($dbh,$sth,4);

  if (ref $rtn eq 'ARRAY') {
    return $rtn->[0]->[0];
  } else {
    return 0;
  }
}

sub del_userGroup {## deletes a User Group
  my $self = shift;
  my $groupID = shift;
  my $dbh = $self->dbh();
  my ($sth,$rtn);

  if ($self->user_isGroupOwner($self->usernum(),$groupID)) {
    
    $sth = $dbh->prepare("delete from jobUserGroupList where ID = ?");
    $sth->bind_param(1,$groupID);
    
    $rtn = $self->_dbAction($dbh,$sth,4);
  }
  
  if (ref $rtn eq 'ARRAY') {
    return $rtn->[0]->[0];
  } else {
    
    my $members = $self->userGroupMembers($groupID);
    if ($members) {
      $members = [ $members ] unless (ref $members eq 'ARRAY');
      foreach my $member (@$members) {
        $member = $member->[0] if (ref $member eq 'ARRAY');
        $self->remove_userGroup($member,$groupID);
      }
    }
    
    return 0;
  }
}

sub user_isGroupMember { # determine whether user is a member of a specific group
  my $self = shift;
  my $userID = shift;
  my $groupID = shift;
  my $dbh = $self->dbh();
  my ($sth,$rtn);

  $sth = $dbh->prepare("select ID from jobUserGroup where UserID = ? AND GroupID = ?");
  $sth->bind_param(1,$userID);
  $sth->bind_param(2,$groupID);

  $rtn = $self->_dbAction($dbh,$sth,2);

  if (ref $rtn eq 'ARRAY') {
    return $rtn->[0]->[0];
  } else {
    return 0;
  }

}

sub groupAdmin { ## accessor to g/set group admin status
  my $self = shift;
  my $userID = shift;
  my $groupID = shift;
  my $set = shift;

  $set ? $self->_set_groupAdmin($userID,$groupID,$set) : $self->_get_groupAdmin($userID,$groupID);
}

sub _set_groupAdmin {
  my $self = shift;
  my $userID = shift;
  my $groupID = shift;
  my $set = shift;
  my $dbh = $self->dbh();
  my $assoc = $self->user_isGroupMember($userID,$groupID); # ID of the userID -  groupID association
  my ($sth,$rtn);

  if ($assoc) {
    $sth = $dbh->prepare("update jobUserGroup set ADMIN = ? where ID = ?");
    $sth->bind_param(1,$set,13);
    $sth->bind_param(2,$assoc);
  } else {
    return '-1';
  }

  $rtn = $self->_dbAction($dbh,$sth,3);

  if (ref $rtn eq 'ARRAY') {
    return $rtn->[0]->[0];
  } else {
    return 0;
  }
}

sub _get_groupAdmin {
  my $self = shift;
  my $userID = shift;
  my $groupID = shift;
  my $dbh = $self->dbh();
  my ($sth,$rtn);

  $sth = $dbh->prepare("select ADMIN from jobUserGroup where UserID = ? AND GroupID = ?");
  $sth->bind_param(1,$userID);
  $sth->bind_param(2,$groupID);

  $rtn = $self->_dbAction($dbh,$sth,2);

  if (ref $rtn eq 'ARRAY') {
    return $rtn->[0]->[0];
  } else {
    return 0;
  }
}

sub user_isGroupAdmin {
  my $self = shift;
  my $userID = shift;
  my $groupID = shift;
  my $privs = $self->groupAdmin($userID,$groupID);
  my $rtn = 0;

  if ($privs && $privs eq 'Y') {
    $rtn = 1;
  }

  return $rtn;

}

sub user_isGroupOwner {
  my $self = shift;
  my $userID = shift;
  my $groupID = shift;
  my $groupOwner = $self->groupOwner($groupID);

  if ($groupOwner && $groupOwner == $userID) {
    return 1;
  } else {
    return 0;
  }

}

sub getLabs {
  my $obj = shift;
  my $dbh = $obj->{_dbh};

  my $sth = $dbh->prepare("select * from jobUserLab order by Name");
  my $rslt = $obj->_dbAction($dbh,$sth,2);

  if (ref $rslt eq 'ARRAY') {
    return $rslt;
  } else {
    return 0;
  }

}

sub addLab {
  my $obj = shift;
  my $dbh = $obj->{_dbh};
  my $newLab = shift;
  my ($sth,$rslt,$labs,$newID);

  if (! $obj->labExists($newLab) ) {
    $sth = $dbh->prepare("insert into jobUserLab (Name) values (?)");
    $sth->bind_param(1,$newLab);
    $rslt = $obj->_dbAction($dbh,$sth,1);

    return $rslt->[0]->[0] if (ref $rslt eq 'ARRAY');
  }

  return $obj->labExists($newLab);

}

sub username_list {
  my $obj = shift;
  my $sort = shift;
	my $direction = shift;
	$direction = 'asc' unless ($direction && $direction eq 'desc');
  my $dbh = $obj->{_dbh};
  my ($sth,$rtn,$cmd);
  $cmd = "select login from $usertable";
  if ($sort) {
    $cmd .= " order by $sort $direction";
  }
    
  $sth = $dbh->prepare($cmd);

  $rtn = $obj->_dbAction($dbh,$sth,2);
  if (ref $rtn eq 'ARRAY') {
    return $rtn;
  } else {
    return 0;
  }

}

sub printlog {
  my $mssg = shift;

  select LOG;
  print "$mssg\n";
  $| = 1;
  print "";
  select STDOUT;

#  print LOG "$mssg\n";

}

sub _getConfig {
    my $config = Config::Tiny->new();
    $config = Config::Tiny->read('/usr/local/lib/perl5/site_perl/5.16.3/CGRB/config.txt');
    
    my $user = $config->{auth}->{user};
    my $password = $config->{auth}->{password};
    my $database = $config->{db}->{name};

    return ($database,$user,$password);
}

sub AUTOLOAD {
  if ($debug) {
    my ($p,$f,$l) = caller();
    print LOG "autoload called: $p, $f, $l\n";
  }

  print LOG "AUTOLOAD:  '$AUTOLOAD'\n" if ($debug);

  $AUTOLOAD =~ /.+::(\w+)/;
  my $method = $1;
#  CGRBDB::$method;

}


=head1 NAME

 CGRBuser - Perl package to access CGRB user methods

=head1 SYNOPSIS

 use CGRB::CGRBuser;

 my $user = CGRBuser->new();

 if ($user->authenticate($r, $username, $password)) { 
    # $r is an Apache::Request object
    OK, let user proceed ...
 } else {
    Send user to login page again ...
 }

 if ($user->logged_in($r)) { 
    # $r is an Apache::Request object
    OK, do something ...
 } else {
    Reroute to login page ...
 }

 my $username = $user->login();
 my $firstname = $user->firstname($username);
 my $lastname = $user->lastname($username);
 my $email = $user->useremail($username);

 Each of these methods can also set their value:

 if ($user->useremail($username,'new@yahoo.com')) {
    OK
 } else {
    Can't change email address for some reason ...
 }



 $user->logout($r);


=head1 DESCRIPTION

 This package contains all the methods necessary to administer and access user accounts on the CGRB in-house website.  As such, it is specialized for use in a web environment where some of the methods can interact with web browsers; specifically, the authentication system is cookie-based.  The common tasks of authenticating users, checking if a user is logged-in, and logging-out users are encapsulated and simple to use.

=head1 METHODS

=head2 Constructor

B<new()>

 The constructor requires no arguments.  An object blessed into the CGRBuser class is returned.

=head2 OBJECT METHODS

B<authenticate(>
C<$r>, C<$USERNAME>, C<$PASSWORD>
B<)>

 The first argument to this method is an Apache::Request object.  The CGRB in-house website uses Mason
 ( http://masonhq.com ) as a perl-based website development and delivery engine.  Under Mason, an 
 Apache::Request object is always available as the $r variable.  The second and third arguments are 
 the username and password entered by the user.  The username and password are matched to those stored 
 for the particular user determined by the username.  If the user exists and the passwords match 
 the method returns 1, if they don't match the method returns 0.  Additionally, if the authentication
 succeeds, a cookie is set signifying that the user has logged in.


B<logged_in(
C<$r>
)>

 This method determines whether a user has logged in.  If a user has successfully logged in, this
 method returns 1.  If a user hasn't logged in yet, this method returns 0.  This method must be called
 before any other methods, except for authenticate().  On the CGRB in-house website the Mason 
 autohandler calls this method for every webpage delivered.


B<login()>

 This method returns the username of a logged-in user.  logged_in() must be called before this method.
 The username is required as an argument to many other methods in this package.

B<firstname(>
C<$USERNAME>, [ 'new first name' ]
B<)>

 The first argument is the user's username as returned by login().  You can get and set a user's first
 name.  Called with only the username, this method returns the user's first name.  Called with a
 second argument, this method will set the user's first name to the second argument.  If successful
 this method will return 0.  If something failed, the error message will be returned.

B<lastname(>
C<$USERNAME>, [ 'new last name' ]
B<)>

 As firstname() above, this method can be used to get/set the user's last name.

B<useremail(>
C<$USERNAME>, [ 'new email address' ]
B<)>

 As firstname() above, this method can be used to get/set the user's email address.

B<password(>
C<$USERNAME>, [ 'new password' ]
B<)>

 As firsname() above, this method can be used to get/set the user's password.  The password
 retrieved will be MD5 encrypted.

B<logout(>
C<$r>
B<)>

 The only argument passed to this method is an Apache::Request object.  If successful, 1 is
 returned.  If the method fails or if a user wasn't actually logged in, 0 is returned.


=head1 OBJECT METHODS NOT YET DOCUMENTED

B<usernum()>

B<labid()>

B<labname()>

B<userCategory()>

B<addLab()>

B<addUser()>

B<chkPassword()>

B<getLabs()>

B<getUsernames()>

B<localchk()>

B<userinfo()>

B<userExists()>

B<username_list()>

=cut
