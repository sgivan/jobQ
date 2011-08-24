package CGRBseq;
# $Id: CGRBseq.pm,v 3.23 2005/04/24 11:04:58 givans Exp $
# checked for gacweb

use strict;
use Carp;
use Compress::LZF;
#use lib '/home/cgrb/givans/dev/lib/perl5';
use CGRB::CGRBDB;
use CGRB::CGRBuser;
use vars qw/@ISA/;

@ISA = ("CGRBDB");
my $debug = 'N';


if ($debug eq 'Y') {
  open(LOG, ">/home/cgrb/givans/dev/bin/logs/CGRBseq.log") or die "can't open CGRBseq.log:  $!";

  printlog("\n\n+++++++++++++++++++++++++++++++++++++++++++++++++++++");
}

END {
  close(LOG) if ($debug eq 'Y');
}

1;

sub new {
  my $pkg = shift;
  my $username = shift;
  my $dbase = 'blast_seqs';
  my $user = 'blast';
  my $pass = 'CGRBlast';
  printlog("Establishing connection to '$dbase' database\npkg: '$pkg'\n") if ($debug eq 'Y');

#  my $cgrb = $pkg->SUPER::new($dbase,$user,$pass);
  my $cgrb = $pkg->SUPER::generate($dbase,$user,$pass,@_);

  printlog("Connection established") if ($debug eq 'Y');

  if ($username) {
    if ( $username =~ /\w+/ ) {
      $cgrb->user($username);
    }
  }

  return $cgrb;
}

sub user {## Accessor 
  my $self = shift;
  my $username = shift;
  my $dbh = shift;

  $self->userDBH($dbh) if ($dbh);

  $username ? $self->_set_user($username) : $self->_get_user();

}

sub _set_user {
  my $self = shift;
  my $username = shift;
  my $user = CGRBuser->new($username,$self->userDBH());
#  my $user = CGRBuser->new($username);
  my $ref = ref $user;
  printlog("\$user is a $ref") if ($debug eq 'Y');
  printlog("setting userinfo with '$username'") if ($debug eq 'Y');
  $user->userinfo($username);
  $self->{_CGRBuser} = $user;
  printlog("from CGRBuser: '" . $user->login() ."'") if ($debug eq 'Y');
}

sub _get_user {
  my $self = shift;

  return $self->{_CGRBuser};

}

sub userDBH {
  my $self = shift;
  my $dbh = shift;

  ($dbh && ref $dbh eq 'DBI::db') ? $self->_set_userDBH($dbh) : $self->_get_userDBH();
}

sub _set_userDBH {
  my $self = shift;
  my $dbh = shift;

    $self->{_userDBH} = $dbh;
}

sub _get_userDBH {
  my $self = shift;

  return $self->{_userDBH} if ($self->{_userDBH});
  return undef;
}

sub seqtype {
  my $obj = shift;
  my $seqnum = shift;
  my $dbh = $obj->dbh();
  my ($sth,$rtn);

  printlog("CGRBseq::seqtype: retrieving seqtype") if ($debug eq 'Y');
    
  $sth = $dbh->prepare("select type from subjct where num = $seqnum");

  $rtn = $obj->_dbAction($dbh,$sth,2);

  if (ref $rtn eq 'ARRAY') {
    return $rtn->[0]->[0];
  } else {
    return undef;
  }
}

sub seqOwner {# accessor to g/set sequence ownership
  my $self = shift;
  my $subjct = shift;
  my $userID = shift;

  $userID ? $self->_set_seqOwner($subjct,$userID) : $self->_get_seqOwner($subjct);
}

sub _set_seqOwner {#  this doesn't change lab association yet
  my $self = shift;
  my $subjct = shift;
  my $userID = shift;
  my $dbh = $self->dbh();
  my ($sth,$rtn);

  $sth = $dbh->prepare("update subjct set owner = ? where num = ?");
  $sth->bind_param(1,$userID);
  $sth->bind_param(2,$subjct);

  $rtn = $self->_dbAction($dbh,$sth,3);

  if (ref $rtn eq 'ARRAY') {
    return $rtn->[0]->[0];
  } else {
    return undef;
  }
}

sub _get_seqOwner {
  my $self = shift;
  my $subjct = shift;
  my $dbh = $self->dbh();
  my ($sth,$rtn);

  $sth = $dbh->prepare("select user from subjct where num = ?");
  $sth->bind_param(1,$subjct);

  $rtn = $self->_dbAction($dbh,$sth,2);

  if (ref $rtn eq 'ARRAY') {
    return $rtn->[0]->[0];
  } else {
    return undef;
  }
}

sub userGroup {#  accessor to s/get userGroup for a sequence
  my $self = shift;
  my $seqID = shift;
  my $groupID = shift;

  $groupID ? $self->_set_userGroup($seqID,$groupID) : $self->_get_userGroup($seqID);
}

sub _set_userGroup {
  my $self = shift;
  my $seqID = shift;
  my $groupID = shift;
  my $dbh = $self->dbh();
  my ($sth,$rtn);

  $sth = $dbh->prepare("update subjct set userGroup = ? where num = ?");
  $sth->bind_param(1,$groupID);
  $sth->bind_param(2,$seqID);

  $rtn = $self->_dbAction($dbh,$sth,3);

  if (ref $rtn eq 'ARRAY') {
    return $rtn->[0]->[0];
  } else {
    return undef;
  }
}

sub _get_userGroup {
  my $self = shift;
  my $seqID = shift;
  my $dbh = $self->dbh();
  my ($sth,$rtn);

  $sth = $dbh->prepare("select userGroup from subjct where num = ?");
  $sth->bind_param(1,$seqID);

  $rtn = $self->_dbAction($dbh,$sth,2);

  if (ref $rtn eq 'ARRAY') {
    return $rtn->[0]->[0];
  } else {
    return undef;
  }
}

sub dbtype {
  my $obj = shift;
  my $subjct = shift;
  my $dbh = $obj->dbh();
  my ($sth,$rtn);
  my @dbtype;

  printlog("retrieving dbtype") if ($debug eq 'Y');

  $sth = $dbh->prepare("select b.dbtype from blast_map b, subjct s where s.num = $subjct AND s.blasttype = b.id");

  $rtn = $obj->_dbAction($dbh,$sth,2);

  if (ref $rtn eq 'ARRAY') {
    return $rtn->[0]->[0];
  } else {
    return undef;
  }
}

sub seqname {
  my $obj = shift;
  my $seqnum = shift;
  my $dbh = $obj->dbh();
  my ($sth,$rtn);
    
  $sth = $dbh->prepare("select name from subjct where num = $seqnum");

  $rtn = $obj->_dbAction($dbh,$sth,2);

  if (ref $rtn eq 'ARRAY') {
    return $rtn->[0];
  } else {
    return undef;
  }
}   

sub fetch_seq {
  my $obj = shift;
  my $id = shift;
  my $dbh = $obj->dbh();
  my ($sth,$rtn);

  $sth = $dbh->prepare("select sequence from subjct where num = $id");

  $rtn = $obj->_dbAction($dbh,$sth,2);

  if (ref $rtn eq 'ARRAY') {
    $obj->{_sequence} = $rtn->[0]->[0];
  } else {
    $obj->{_sequence} = 0;
  }

  return $obj->{_sequence};
}

sub fetchoneseq {
  #    my ($obj,$seqname) = @_;
  my ($obj,$subjct) = @_;
  my $dbh = $obj->dbh();
  my ($sth,$rtn);
  my ($package, $filename, $line) = caller() if ($debug eq 'Y');
  printlog("CGRBseq::fetchoneseq:  subjct = '$subjct'\npkg: $package, file: $filename, $line: $line\n") if ($debug eq 'Y');

  $sth = $dbh->prepare("select name, descr, sequence, type, blast, blasttype, E, species, num, user from subjct where num = $subjct");

  $rtn = $obj->_dbAction($dbh,$sth,2);

  if (ref $rtn eq 'ARRAY') {
    return $rtn->[0];
  } else {
    return undef;
  }

}

sub subjct_species {
  my ($obj,$subjct) = @_;

  my $species = $obj->fetchoneseq($subjct)->[7];

  return $species;
}

sub seqinfo {
  my $self = shift;
  my $subjct = shift;
  my $dbh = $self->dbh();
  my ($sth,$rtn);
  
  $rtn = $self->seqlist_adv({id => $subjct, column => 'num'});
  
#   $sth = $dbh->prepare("select num, name, descr, type, blast, blasttype, E, species from subjct where num = ?");
#   $sth->bind_param(1,$subjct);
  # 
#   $rtn = $self->dbAction($dbh,$sth,2);
   if (ref $rtn eq 'ARRAY') {
     return $rtn->[0];
   } else {
     return undef;
   }
}

sub seqlist {
  my $obj = shift;
#  my $userid = shift;
  my $params = shift;
  my ($userid,$start,$rows,$order,$direction);
  if ($params) {
    if (ref($params) eq 'HASH') {
      $userid = $params->{userid};
      $start = $params->{start};
      $rows = $params->{rows};
      $order = $params->{order};
      if ($order) {
	$direction = 'ASC' unless ($params->{direction});
      }
    } else {
      $userid = $params;
    }
  }

  my $dbh = $obj->dbh();
  $userid = $obj->{_CGRBuser}->usernum() unless($userid);
  my ($sth,$rtn,$query);
  $query = "select num, name, descr, type, blast, blasttype, E, species from subjct where user = $userid";
#  $query = "select s.num, s.name, s.descr, s.type, s.blast, s.blasttype, s.E, s.species, g.NAME from subjct s, CGRBjobs.jobUserGroupList g where s.user = $userid and s.userGroup = g.ID";
#   if ($order) {
#     $query .= " ORDER BY $order $direction";
#   }
#   if ($start && $rows) {
#     $query .= " LIMIT $start,$rows";
#   }

  $sth = $dbh->prepare($query);
#  $sth = $dbh->prepare("select num, name, descr, type, blast, blasttype, E, species from subjct where user = $userid");

  $rtn = $obj->_dbAction($dbh,$sth,2);
  if (ref $rtn eq 'ARRAY') {
#    main::printText(scalar(@$rtn));
#    exit(0);
    return $rtn;
  } else {
    return undef;
  }

}

sub seqlist_adv {
  my $obj = shift;
  my $params = shift;
  my ($userid,$start,$rows,$order,$direction,$column,$sth,$query,$rtn);
  if ($params) {
    if (ref($params) eq 'HASH') {
      $column = $params->{column};
      $userid = $column eq 'userGroup' ? $params->{groupID} : ($params->{userid} || $params->{id});
      $start = $params->{start};
      $rows = $params->{rows};
      $order = $params->{order};
      $sth = $params->{sth};
      if ($order) {
	$direction = 'ASC' unless ($params->{direction});
      }
    } else {
      $userid = $params;
    }
  }
  $column = 'user' unless ($column);
  my %groupName;
  my $userGroups = $obj->user()->getGroups($obj->user()->usernum());
  foreach my $group (@$userGroups) {
    $groupName{$group->[0]} = $obj->user()->groupName($group->[0]);
  }
  
  my %hitCounts;
  my $all_hitCounts = $obj->all_quickHitCounts();
  foreach my $row (@$all_hitCounts) {
    $hitCounts{$row->[0]} = [$row->[1], $row->[2]];
  }

  my $dbh = $obj->dbh();
  $userid = $obj->{_CGRBuser}->usernum() unless($userid);

  if (!$sth) {
    $query = "select num, name, descr, type, blast, blasttype, E, species, userGroup from subjct where $column = $userid";
    $sth = $dbh->prepare($query);
  }

  $rtn = $obj->_dbAction($dbh,$sth,2);
  if (ref $rtn eq 'ARRAY') {
    
    foreach my $row (@$rtn) {
	push(@$row,$groupName{$row->[8]} || 'All');
	push(@$row,$hitCounts{$row->[0]} || [0,0]);
    }
    
    return $rtn;
  } else {
    return undef;
  }

}


sub seqlist_byUserGroup_d {
	my $self = shift;
	my $groupID = shift;
	my $dbh = $self->dbh();
	my ($sth,$rtn);

	$sth = $dbh->prepare("select num, name, descr, type, blast, blasttype, E, species from subjct where userGroup = ?");
	$sth->bind_param(1,$groupID);
	
	$rtn = $self->_dbAction($dbh,$sth,2);
	
	if (ref $rtn eq 'ARRAY') {
		return $rtn;
	} else {
		return undef;
	}
	
}

sub seqlist_byUserGroup {
	my $self = shift;
	my $groupID = shift;
	my $dbh = $self->dbh();
	my ($sth,$rtn);

	$self->seqlist_adv({column => 'userGroup', groupID => $groupID});
}


sub seqnumlist {
  my $obj = shift;
  my $usernum = shift;
  my ($dbh,$sth,$rtn) = ($obj->dbh());
  my $usrnum = shift;

  $usrnum = $obj->{_CGRBuser}->usernum() unless ($usrnum);
  $usrnum = $obj->user()->usernum() unless ($usrnum);

  $sth = $dbh->prepare("select num from subjct where user = $usernum");

  $rtn = $obj->_dbAction($dbh,$sth,2);

  if (ref $rtn eq 'ARRAY') {
    return $rtn;
  } else {
    return undef;
  }

}

sub addseq {
  my $obj = shift;
  my ($name,$descr,$type,$sequence,$blast) = @_;
  my $blasttype = 'NULL';
  my $blastE = '1e-6';
  my $species = 'NULL';
  if ($blast eq 'Y') {
    $blasttype = $_[5];
    $blastE = $_[6];
    $species = $_[7] if ($_[7] =~ /\w+/);
  }
  return "No valid sequence was passed to library" unless ($sequence =~ /\w+/);
  my $dbh = $obj->dbh();
  my ($rtn,$RTN);

  printlog("adding sequence $name to subjct table") if ($debug eq 'Y');

  my $sth = $dbh->prepare("lock tables subjct write");

  $rtn = $obj->_dbAction($dbh,$sth,5);

  printlog("subjct table is locked") if ($debug eq 'Y');
  my $login = $obj->{_CGRBuser}->login();
  my $usernumber = $obj->{_CGRBuser}->usernum();
  my $labid = $obj->{_CGRBuser}->labid($login);
#	my $labid = 1;
  printlog("this not belongs to user '$login', user number '$usernumber' of lab number '$labid'") if ($debug eq 'Y');

  $sth = $dbh->prepare("insert into subjct (name, descr, type, sequence, user, lab, blast, blasttype, E, species) values (?,?,?,?,?,?,?,?,?,?)");
  $sth->bind_param(1,$name);
  $sth->bind_param(2,$descr);
  $sth->bind_param(3,$type);
  $sth->bind_param(4,$sequence);
  printlog("up to sequence is bound") if ($debug eq 'Y');
  $sth->bind_param(5,$usernumber);
  $sth->bind_param( 6, $labid);
  printlog("labid bound") if ($debug eq 'Y');
  $sth->bind_param(7,$blast);
  $sth->bind_param(8,$blasttype);
  $sth->bind_param(9,$blastE);
  $sth->bind_param(10,$species);

  $rtn = $obj->_dbAction($dbh,$sth,1);

  printlog("$name has been inserted into subjct table") if ($debug eq 'Y');

  $sth = $dbh->prepare("select max(num) from subjct");

  $RTN = $obj->_dbAction($dbh,$sth,2);

  $sth = $dbh->prepare("unlock tables");

  $rtn = $obj->_dbAction($dbh,$sth,6);
  printlog("subjct table has been unlocked, returning max id") if ($debug eq 'Y');

  if (ref $RTN eq 'ARRAY') {
    printlog("max num returned as $RTN->[0]->[0] from subjct table") if ($debug eq 'Y');
    $obj->userGroup($RTN->[0]->[0],1);
    $obj->initialize_hitCounts($RTN->[0]->[0]);
    return $RTN->[0]->[0];
  } else {
    return undef;
  }

}

sub addhit {
  my $obj = shift;
  my $hit = shift;
  my $dbh = $obj->dbh();
  my ($sth,$rtn);
  printlog("adding hit '$hit->[1]' [from CGRB.pm]") if ($debug eq 'Y');

  $sth = $dbh->prepare("insert into hits (subjct,hit,E,descr,seqtype) values (?,?,?,?,?)");
  $sth->bind_param(1,$hit->[0]);
  $sth->bind_param(2,$hit->[1]);
  $sth->bind_param(3,$hit->[2]);
  $sth->bind_param(4,$hit->[3]);
  $sth->bind_param(5,$hit->[4]);

  $rtn = $obj->_dbAction($dbh,$sth,1);

  if (ref $rtn eq 'ARRAY') {
    return $rtn->[0];
  } else {
    return [];
  }

}

sub checkpair {
  my $obj = shift;
  my $sub_hit = shift;
  my $dbh = $obj->dbh();
  my ($sth, $hit_oldformat,$rtn);

  if ($sub_hit->[1] =~ /^([a-z]+?)\|(.+?)\|/) {
    $hit_oldformat = $2;
  }

  if ($hit_oldformat) {
    $sth = $dbh->prepare("select num from hits where subjct = ? AND ( hit = ? OR hit = ? )");
	$sth->bind_param(1,$sub_hit->[0]);
	$sth->bind_param(2,$sub_hit->[1]);
	$sth->bind_param(3,$hit_oldformat);
  } else {
    $sth = $dbh->prepare("select num from  hits where subjct = ? AND hit = ?");
	$sth->bind_param(1,$sub_hit->[0]);
	$sth->bind_param(2,$sub_hit->[1]);
  }

  $rtn = $obj->_dbAction($dbh,$sth,2);

  if (ref $rtn eq 'ARRAY') {
    return $rtn;
  } else {
    return undef;
  }

}

sub blastcheck {
  my $obj = shift;
  my $seqnum = shift;
  my $dbh = $obj->dbh();
  my ($sth,$rtn);

  $sth = $dbh->prepare("select blast from subjct where num = $seqnum");

  $rtn = $obj->_dbAction($dbh,$sth,2);

  if (ref $rtn eq 'ARRAY') {
    return $rtn->[0]->[0];
  } else {
    return undef;
  }
}


sub updateseq {
  my $obj = shift;
  my $array_r = shift;
  my ($sth,$rtn);

  my ($subjct,$name,$descr,$type,$sequence,$blast,$blasttype,$blastE,$species) = ($array_r->[0],$array_r->[1],$array_r->[2],$array_r->[3],$array_r->[4],$array_r->[5],$array_r->[6],$array_r->[7],$array_r->[8]);

  my $dbh = $obj->dbh();

  $sth = $dbh->prepare("update subjct set name = '$name', descr = '$descr', type = '$type', sequence = '$sequence', blast = '$blast', blasttype = '$blasttype', E = '$blastE', species = '$species' where num = $subjct");

  $rtn = $obj->_dbAction($dbh,$sth,3);

  if (ref $rtn eq 'ARRAY') {
    return $rtn->[0];
  } else {
    return [];
  }
    
}

sub deleteseq {
  my $obj = shift;
  my @seqnums = @_;
  my $dbh = $obj->dbh();
  my $rtn;

  foreach my $number (@seqnums) {
    my $sth = $dbh->prepare("delete from subjct where num = $number");

    $rtn = $obj->_dbAction($dbh,$sth,3);

  }

  return [];

}

sub seqnumber {
  my $obj = shift;
  my $name = shift;
  my $dbh = $obj->dbh();
  my ($sth,$rtn,$usr);
  $usr = $obj->{_CGRBuser}->usernum();
	

  $sth = $dbh->prepare("select num from subjct where user = $usr AND name = '$name'");

  $rtn = $obj->_dbAction($dbh,$sth,2);
	
  if (ref $rtn eq 'ARRAY') {
    return $rtn->[0]->[0];
  } else {
    return undef;
  }

}

sub seqCount {
  my $self = shift;
  my $userID = shift;
  my $dbh = $self->dbh();
  my ($sth,$rtn);

  $sth = $dbh->prepare("select count(num) from subjct where user = ?");
  $sth->bind_param(1,$userID);

  $rtn = $self->dbAction($dbh,$sth,2);

  if ($rtn) {
    return $rtn->[0]->[0];
  } else {
    return undef;
  }

}

sub hitCount {
  my $passed = scalar(@_);
  my $obj = shift;
  my $subjct = shift;
  my $dbh = $obj->dbh();
  my $hitCount = shift;
  my ($sth,$rtn);

  if ($passed == 2) {
    printlog("CGRBseq::hitCount - getting hitcount for subjct = '$subjct'") if ($debug eq 'Y');

    $sth = $dbh->prepare("select count(num) from hits where subjct = $subjct");

    $rtn = $obj->_dbAction($dbh,$sth,2);
	

  } else {
    printlog("CGRBseq::hitCount - setting hitcount for subjct $subjct to $hitCount") if ($debug eq 'Y');

    $sth = $dbh->prepare("update hitCounts set totalHits = $hitCount where subjct = $subjct");

    $rtn = $obj->_dbAction($dbh,$sth,3);
  }
  
  if (ref $rtn eq 'ARRAY') {
    printlog("CGRBseq::hitCount - returning " . $rtn->[0]->[0]) if ($debug eq 'Y');
    return $rtn->[0]->[0];
  } else {
    return undef;
  }

}

sub newhitCount {
  my $passed = scalar(@_);
  my $obj = shift;
  my $subjct = shift;
  my $dbh = $obj->dbh();
  my $newhitCount = shift;
  my ($sth,$rtn);

  if ($passed == 2) {
    $sth = $dbh->prepare("select count(num) from hits where subjct = $subjct and new = 'Y'");
 
    $rtn = $obj->_dbAction($dbh,$sth,2);

  } else {
    printlog("CGRBseq::newhitCount - setting newHits for subjct $subjct to $newhitCount") if ($debug eq 'Y');

    $sth = $dbh->prepare("update hitCounts set newHits = $newhitCount where subjct = $subjct");
 
    $rtn = $obj->_dbAction($dbh,$sth,3);
  }
  
  if (ref $rtn eq 'ARRAY') {
	  return $rtn->[0]->[0];
  } else {
	  return undef;
  }
 
}

sub quickHitCounts {
  my $obj = shift;
  my ($dbh,$sth,$rtn) = ($obj->dbh());
  my $subjct = shift;

  $sth = $dbh->prepare("select totalHits, newHits from hitCounts where subjct = $subjct");

  $rtn = $obj->_dbAction($dbh,$sth,2);
	
  if (ref $rtn eq 'ARRAY') {
    return $rtn->[0];
  } else {
    return undef;
  }

}

sub all_quickHitCounts {
  my $self = shift;
  my ($dbh,$sth,$rtn) = $self->dbh();
  
  $sth = $dbh->prepare("select * from hitCounts");
  $rtn = $self->dbAction($dbh,$sth,2);
  
  if ($rtn && ref($rtn) eq 'ARRAY') {
    return $rtn;
  } else {
    return undef;
  }
  
}

sub initialize_hitCounts {
  my $obj = shift;
  my $subjct = shift;
  my $dbh = $obj->dbh();
  my ($sth,$rtn);

  if (! has_hitCounts($obj,$subjct)) {
    $sth = $dbh->prepare("insert into hitCounts (subjct) values ($subjct)");

    $rtn = $obj->_dbAction($dbh,$sth,1);
    if (ref $rtn eq 'ARRAY') {
      return $rtn->[0]->[0];
    } else {
      return undef;
    }

  }
}

sub has_hitCounts {
  my $obj = shift;
  my $subjct = shift;
  my $dbh = $obj->dbh();
  my ($sth,$rtn);

  $sth = $dbh->prepare("select * from hitCounts where subjct = ?");
  $sth->bind_param(1,$subjct);

  $rtn = $obj->_dbAction($dbh,$sth,2);
  if (ref $rtn eq 'ARRAY') {
    my $cnt = $rtn->[0]->[0];
	return $cnt if $cnt;
#    return scalar @$cnt;
  } else {
    return undef;
  }

}

sub seehits {
  warn("This is a deprecated method; use get_hits(subjct) instead");
  my $obj = shift;
  my $seqname = shift;

  my $seqnum = $obj->seqnumber($seqname);

  get_hits($obj,$seqnum);

}


#sub seehits {
sub get_hits {
  my $obj = shift;
  my $dbh = $obj->dbh();
  my $subjct = shift;
  my ($sth,$rtn);

  $sth = $dbh->prepare("select num, hit, E, descr, new from hits where subjct = $subjct order by E");

  $rtn = $obj->_dbAction($dbh,$sth,2);
  if (ref $rtn eq 'ARRAY') {
    return $rtn;
  } else {
    return undef;
  }

}

sub seehit {
  my $obj = shift;
  my $dbh = $obj->dbh();
  my $hitnum = shift;
  my ($sth,$rtn);

  $sth = $dbh->prepare("select * from hits where num = $hitnum");

  $rtn = $obj->_dbAction($dbh,$sth,2);
  if (ref $rtn eq 'ARRAY') {
    return $rtn;
  } else {
    return undef;
  }
}

sub hit_seqtype {
  my $obj = shift;
  my $hitnum = shift;
  my $rtn;
  
  $rtn = $obj->seehit($hitnum); 
  if (ref $rtn eq 'ARRAY') {
	  return $rtn->[0]->[7];
  } else {
	  return undef;
  }

}

sub check_new_hits {
  my $obj = shift;
  my $dbh = $obj->dbh();
  my $user = $obj->{_CGRBuser}->usernum();
  my ($sth,$rtn);

  $sth = $dbh->prepare("select distinct h.subjct from hits h, subjct s where s.user = $user AND h.subjct = s.num AND h.new = 'Y'");

  $rtn = $obj->_dbAction($dbh,$sth,2);
  if (ref $rtn eq 'ARRAY') {
    return $rtn;
  } else {
    return undef;
  }

}

sub get_new_hits {
  my $obj = shift;
  my $dbh = $obj->dbh();
  #  my $subjct = $obj->seqnumber(shift);
  my $subjct = shift;
  my ($sth,$rtn);
  
  printlog("select num, hit, E, descr, new from hits where subjct = '$subjct' AND new = 'Y' order by E") if ($debug eq 'Y');
  $sth = $dbh->prepare("select num, hit, E, descr, new from hits where subjct = '$subjct' AND new = 'Y' order by E");

  $rtn = $obj->_dbAction($dbh,$sth,2);
  if (ref $rtn eq 'ARRAY') {
    return $rtn;
  } else {
    return undef;
  }

}

sub set_hit_old {
  my $obj = shift;
  my $dbh = $obj->dbh();
  my $hit = shift;
  my ($sth,$rtn);

  $sth = $dbh->prepare("update hits set new = 'N' where num = $hit");

  $rtn = $obj->_dbAction($dbh,$sth,3);
  if (ref $rtn eq 'ARRAY') {
    return $rtn->[0]->[0];
  } else {
    return undef;
  }

}

sub set_hits_old {
  my $obj = shift;
  my $dbh = $obj->dbh();
  my $subjct = shift;
  my ($sth,$rtn);

  $sth = $dbh->prepare("update hits set new = 'N' where subjct = ?");
  $sth->bind_param(1, $subjct);
  $rtn = $obj->_dbAction($dbh,$sth,3);

  $obj->newhitCount($subjct,0);

  if (ref $rtn eq 'ARRAY') {
	  return $rtn->[0]->[0];
  } else {
	  return undef;
  }
}


sub end {
  my $obj = shift;
  my $dbh = $obj->dbh();

  $dbh->disconnect;

}

sub blast_init {
  my $obj = shift;
  my $subjct = shift;
  my $login = $obj->{_CGRBuser}->login();

  printlog("initiating BLAST job for '$subjct'") if ($debug eq 'Y');

  deletehit_bysubjct($obj,$subjct);

#  my $prog = '/home/cgrb/givans/bin/blastSQL.pl';
  my $prog = '/home/cgrb/givans/bin/blastSQLsubmitQ.pl';
#  printlog("passing to BLAST: '$prog initial $obj->{_username} $subjct'\n") if ($debug eq 'Y');
  printlog("passing to BLAST: '$prog initial $login $subjct'\n") if ($debug eq 'Y');

  system("$prog -t initial -u $login -S $subjct");

#   my $child = fork;

#   if (!$child) {
#     close(STDIN);
#     close(STDOUT);
#     open (BLAST, "| $prog initial $obj->{_CGRBuser}->{_username} $subjct") || die "can't start BLAST job: $!";

#     if (!close(BLAST)) { 
#       printlog("can't close BLAST pipe: $!") if ($debug eq 'Y');
#       #	die "can't end BLAST job: $!";
#       return "can't close BLAST job: $!";
#     }

#     printlog("BLAST pipe closed properly\n") if ($debug eq 'Y');

#   } else {
#     return $child;
#   }

}

sub blast_initQ {
  my $obj = shift;
#  my $subjct = shift;
#  my $blastType = shift;
  my $params = shift;
  my $subjct = $params->{subjct};
  my $blastType = $params->{blastType};

  my $login = $obj->{_CGRBuser}->login();

  if (! $blastType) {
    $blastType = 'initial';
    printlog("blast_initQ:  user '$login' initiating BLAST job for '$subjct'") if ($debug eq 'Y');

    deletehit_bysubjct($obj,$subjct);
  } elsif ($blastType eq 'update') {
    $obj->set_hits_old($subjct);
  }

  my $prog = '/home/cgrb/givans/bin/blastSQLsubmitQ.pl';
  printlog("blast_initQ:  passing to BLAST: '$prog -t $blastType -u $login -S $subjct'\n") if ($debug eq 'Y');
  my $invoke = "$prog -t $blastType -u $login -S $subjct";
  $invoke .= " -f" if ($params->{force});
  system($invoke);


}


sub deletehit {
  my $obj = shift;
  my $dbh = $obj->dbh();
  my $hitnum = shift;
  my ($sth,$rtn);
  #    print LOG "deletehit: deleting hit '$hitnum'\n";

  $sth = $dbh->prepare("delete from hits where num = $hitnum");

  $rtn = $obj->_dbAction($dbh,$sth,4);
  if (ref $rtn eq 'ARRAY') {
    return $rtn->[0]->[0];
  } else {
    return undef;
  }

}

sub deletehit_bysubjct {
  my $obj = shift;
  my $dbh = $obj->dbh();
  my $subjct = shift;
  my ($sth,$rtn);
  #    print LOG "deletehit_bysubjct subj: '$subjct'\n";

  $sth = $dbh->prepare("select num from hits where subjct = $subjct");

  $rtn = $obj->_dbAction($dbh,$sth,2);
  if (ref $rtn eq 'ARRAY') {

    foreach my $row (@$rtn) {
      #	print LOG "deleting '$row->[0]' from hits\n";
      $obj->deletehit($row->[0]);
    }
  } else {
    return [];
  }


}

sub blastjob {
  my $obj = shift;
  my $dbh = $obj->dbh();
  my $subjct = shift;
  my ($sth,$rtn);

  $sth = $dbh->prepare("select b.prog, b.db, s.E from blast_map b, subjct s where s.blasttype = b.id AND s.num = $subjct");

  $rtn = $obj->_dbAction($dbh,$sth,2);
  if (ref $rtn eq 'ARRAY') {
    return $rtn->[0];
  } else {
    return undef;
  }

}
	
sub printlog {
  my $mssg = shift;

  print LOG "$mssg\n";

  return 1;
}

sub storeNote { ### call with (subjct, 'note content', 'note type')
  my $obj = shift;
  my $dbh = $obj->dbh();
  my $subjct = shift;
  my $note = shift;
  my $type = shift;
  my $owner = shift;
  my ($sth,$rtn,$RTN,$row);
  $owner = $obj->{_CGRBuser}->usernum() unless ($owner);

  my $quoted_note = shrink($obj,\$note);
  my $compressed = 'LZF';

  printlog("storing note for '$subjct', type: '$type'") if ($debug eq 'Y');

  $sth = $dbh->prepare("lock tables notebook write");
  $rtn = $obj->_dbAction($dbh,$sth,5);

  printlog("notebook table is locked") if ($debug eq 'Y');

  $sth = $dbh->prepare("insert into notebook (subjct, note, type, date, compressed,owner) values (?, ?, ?, now(), ?,?)");
  $sth->bind_param(1,$subjct);
  $sth->bind_param(2,$quoted_note);
  $sth->bind_param(3,$type);
  $sth->bind_param(4,$compressed);
  $sth->bind_param(5,$owner);
  $rtn = $obj->_dbAction($dbh,$sth,1);

  printlog("note has been inserted") if ($debug eq 'Y');

  $sth = $dbh->prepare("select max(id) from notebook");

  $RTN = $obj->_dbAction($dbh,$sth,2);
  if (ref $RTN eq 'ARRAY') {
    $row = $RTN->[0];
  } else {
    $row = [0];
  }

  printlog("max id returneds as $row->[0]") if ($debug eq 'Y');

  $sth = $dbh->prepare("unlock tables");
  $rtn = $obj->_dbAction($dbh,$sth,6);

  printlog("notebook table has been unlocked, returning max id") if ($debug eq 'Y');

  return $row->[0];		## returns note id
}

sub saveNote { ## modify this to update note content as well
  my $obj = shift;
  my $noteId = shift;
  my $title = shift;
  my $noteContent = shift;
  my $dbh = $obj->dbh();
  my ($sth,$rtn);
#  $title = quotemeta($title);


  $title = 'untitled' unless ($title);

  printlog("saving note '$noteId', title: '$title'") if ($debug eq 'Y');

  if ($noteContent) {
    $noteContent = shrink($obj,\$noteContent);
    $sth = $dbh->prepare("update notebook set title = ?, saved = 'Y', note = ? where id = ?");
    $sth->bind_param(1,$title);
    $sth->bind_param(2,$noteContent);
    $sth->bind_param(3,$noteId);
  } else {
    $sth = $dbh->prepare("update notebook set title = ?, saved = 'Y' where id = ?");
    $sth->bind_param(1,$title);
    $sth->bind_param(2,$noteId);
  }
  $rtn = $obj->_dbAction($dbh,$sth,3);
  if (ref $rtn eq 'ARRAY') {
	  return $rtn->[0]->[0];
  } else {
	  return undef;
  }

}

sub deleteNotes {
  my $obj = shift;
  my $ids = shift;
  my $dbh = $obj->dbh();
  my ($sth,$rtn);
  $ids = [ $ids ] unless (ref $ids eq 'ARRAY');
  
  foreach my $id (@$ids) {
	  my $noteFile = $obj->noteFile($id);
	  foreach my $file (@$noteFile) {
		  $obj->deleteNoteFileEntry($file->[0]);
	  }

    $sth = $dbh->prepare("delete from notebook where id = $id");

    $rtn = $obj->_dbAction($dbh,$sth,4);
	
    if (ref $rtn eq 'ARRAY') {
      return $rtn->[0]->[0];
    }
  }

  return undef;

}

sub getNote {
  my $obj = shift;
  my $noteId = shift;
  my $dbh = $obj->dbh();
  my ($sth,$rtn,$row);

  $sth = $dbh->prepare("select title, note, subjct from notebook where id = $noteId");

  $rtn = $obj->_dbAction($dbh,$sth,2);
  if (ref $rtn eq 'ARRAY') {
    $row = $rtn->[0];
  } else {
    $row = 0;
  }

  if ($row) {
    my $compression = is_compressed($obj,$noteId);
    if ($compression) {
      if ($compression =~ /CGRBseq.+/) {
	$row->[1] = $compression;
      } else {
	$row->[1] = expand($obj,\$row->[1]);
      }
    }
  }

  return $row;

}

sub getNotes {
  my $obj = shift;
  my $subjct = shift; # PSD sequence number
  my $order = shift; # sort by this column
  my $desc = shift; # sort order (ascending/descending)
  my $dbh = $obj->dbh();
  my $orderBy;
  my ($sth,$rtn);

  $desc = 'desc' if $desc;

  if ($order) {
    if ($order == 1) {
      $orderBy = 'id';
    } elsif ($order == 2) {
      $orderBy = 'title';
    } elsif ($order == 3) {
      $orderBy = 'type';
    } elsif ($order == 4) {
      $orderBy = 'date';
    } else {
      $orderBy = 'date';
    }
  } else {
    $orderBy = 'date';
  }


  if ($desc) {
    $sth = $dbh->prepare("select id, title, type, date, owner from notebook where subjct = '$subjct' AND saved = 'Y' order by $orderBy $desc");
  } else {
    $sth = $dbh->prepare("select id, title, type, date, owner from notebook where subjct = '$subjct' AND saved = 'Y' order by $orderBy");
  }


  $rtn = $obj->_dbAction($dbh,$sth,2);
  if (ref $rtn eq 'ARRAY') {
    return $rtn;
  } else {
    return undef;
  }

}

sub changeNoteTitle {
  my $obj = shift;
  my $id = shift;
  my $title = shift;
  my $dbh = $obj->dbh();
  $title = 'untitled' unless ($title =~ /\w/);
  my ($sth,$rtn);

  $sth = $dbh->prepare("update notebook set title = '$title' where id = $id");

  $rtn = $obj->_dbAction($dbh,$sth,3);
  if (ref $rtn eq 'ARRAY') {
    return $rtn->[0]->[0];
  } else {
    return undef;
  }

}

sub noteOwner {# accessor to g/set note owner
  my $self = shift;
  my $noteID = shift;
  my $userID = shift;

  $userID ? $self->_set_noteOwner($noteID,$userID) : $self->_get_noteOwner($noteID);
}

sub _set_noteOwner {
  my $self = shift;
  my $noteID = shift;
  my $userID = shift;
  my $dbh = $self->dbh();
  my ($sth,$rtn);

  $sth = $dbh->prepare("update notebook set owner = ? where id = ?");
  $sth->bind_param(1,$userID);
  $sth->bind_param(2,$noteID);

  $rtn = $self->_dbAction($dbh,$sth,3);

  if (ref $rtn eq 'ARRAY') {
    return $rtn->[0]->[0];
  } else {
    return undef;
  }
}

sub _get_noteOwner {
  my $self = shift;
  my $noteID = shift;
  my $dbh = $self->dbh();
  my ($sth,$rtn);

  $sth = $dbh->prepare("select owner from notebook where id = ?");
  $sth->bind_param(1,$noteID);

  $rtn = $self->_dbAction($dbh,$sth,2);

  if (ref $rtn eq 'ARRAY') {
    return $rtn->[0]->[0];
  } else {
    return undef;
  }
}

sub noteFile {
  my $self = shift;
  my $noteID = shift;
  my $fileName = shift;
  my $fileType = shift;
  my $fileDesc = shift;
  my $fileOwner = shift;

  ($fileName && $fileType) ? $self->_set_noteFile($noteID,$fileName,$fileType,$fileDesc,$fileOwner) : $self->_get_noteFile($noteID);
}

sub _set_noteFile {
  my $self = shift;
  my $noteID = shift;
  my $fileName = shift;
  my $fileType = shift;
  my $fileDesc = shift;
  my $fileOwner = shift;
  my $dbh = $self->dbh();
  my ($sth,$rtn);

  $self->_lockTable('notebookFiles');

  $sth = $dbh->prepare("insert into notebookFiles (noteID,FILE,TYPE,DESCRIPTION,OWNER) values (?,?,?,?,?)");
  $sth->bind_param(1,$noteID);
  $sth->bind_param(2,$fileName);
  $sth->bind_param(3,$fileType);
  $sth->bind_param(4,$fileDesc);
  $sth->bind_param(5,$fileOwner);

  $rtn = $self->_dbAction($dbh,$sth,1);

  if (ref $rtn eq 'ARRAY') {
    $self->_unlockTable();
    return $rtn->[0]->[0];
  } else {

    $sth = $dbh->prepare("select max(ID) from notebookFiles");
    $rtn = $self->_dbAction($dbh,$sth,2);

    $self->_unlockTable();

    if (ref $rtn eq 'ARRAY') {
      return $rtn->[0]->[0];
    } else {
      return undef;
    }
  }
}

sub _get_noteFile {
  my $self = shift;
  my $noteID = shift;
  my $dbh = $self->dbh();
  my ($sth,$rtn);

  $sth = $dbh->prepare("select ID,FILE,TYPE,DESCRIPTION,OWNER from notebookFiles where noteID = ?");
  $sth->bind_param(1,$noteID);

  $rtn = $self->_dbAction($dbh,$sth,2);

  if (ref $rtn eq 'ARRAY') {
    return $rtn;
  } else {
    return undef;
  }
}

sub noteFileType {
  my $self = shift;
  my $fileID = shift;
  my $fileType = shift;

  $fileType ? $self->_set_noteFileType($fileID,$fileType) : $self->_get_noteFileType($fileID);
}

sub _set_noteFileType {
  my $self = shift;
  my $fileID = shift;
  my $fileType = shift;
  my $dbh = $self->dbh();
  my ($sth,$rtn);

  $sth = $dbh->prepare("update notebookFiles set TYPE = ? where ID = ?");
  $sth->bind_param(1,$fileType);
  $sth->bind_param(2,$fileID);

  $rtn = $self->_dbAction($dbh,$sth,3);

  if (ref $rtn eq 'ARRAY') {
    return $rtn->[0]->[0];
  } else {
    return undef;
  }
}

sub _get_noteFileType {
  my $self = shift;
  my $fileID = shift;
  my $dbh = $self->dbh();
  my ($sth,$rtn);

  $sth = $dbh->prepare("select TYPE from notebookFiles where ID = ?");
  $sth->bind_param(1,$fileID);

  $rtn = $self->_dbAction($dbh,$sth,2);

  if (ref $rtn eq 'ARRAY') {
    return $rtn->[0]->[0];
  } else {
    return undef;
  }
}

sub noteFileMIME {
  my $self = shift;
  my $typeID = shift;
  my $MIME = shift;

  $MIME ? $self->_set_noteFileMIME($typeID,$MIME) : $self->_get_noteFileMIME($typeID);

}

sub _set_noteFileMIME {
  my $self = shift;
  my $typeID = shift;
  my $MIME = shift;
  my $dbh = $self->dbh();
  my ($sth,$rtn);

  $sth = $dbh->prepare("update notebookFileType set MIME = ? where ID = ?");
  $sth->bind_param(1,$MIME);
  $sth->bind_param(2,$typeID);

  $rtn = $self->_dbAction($dbh,$sth,3);

  if (ref $rtn eq 'ARRAY') {
    return $rtn->[0]->[0];
  } else {
    return undef;
  }
}

sub _get_noteFileMIME {
  my $self = shift;
  my $typeID = shift;
  my $dbh = $self->dbh();
  my ($sth,$rtn);

  $sth = $dbh->prepare("select MIME from notebookFileType where ID = ?");
  $sth->bind_param(1,$typeID);

  $rtn = $self->_dbAction($dbh,$sth,2);

  if (ref $rtn eq 'ARRAY') {
    return $rtn->[0]->[0];
  } else {
    return undef;
  }
}

sub getFileTypeInfo {
  my $self = shift;
  my $typeID = shift;
  my $dbh = $self->dbh();
  my ($sth,$rtn);

  if ($typeID) {
    $sth = $dbh->prepare("select * from notebookFileType where ID = ?");
    $sth->bind_param(1,$typeID);
  } else {
    $sth = $dbh->prepare("select * from notebookFileType");
  }

  $rtn = $self->_dbAction($dbh,$sth,2);

  if (ref $rtn eq 'ARRAY') {
    return $rtn;
  } else {
    return undef;
  }
}

sub noteFileName {
  my $self = shift;
  my $fileID = shift;
  my $fileName = shift;

  $fileName ? $self->_set_noteFileName($fileID,$fileName) : $self->_get_noteFileName($fileID);
}

sub _set_noteFileName {
  my $self = shift;
  my $fileID = shift;
  my $fileName = shift;
  my $dbh = $self->dbh();
  my ($sth,$rtn);

  $sth = $dbh->prepare("update notebookFiles set FILE = ? where ID = ?");
  $sth->bind_param(1,$fileName);
  $sth->bind_param(2,$fileID);

  $rtn = $self->_dbAction($dbh,$sth,3);

  if (ref $rtn eq 'ARRAY') {
    return $rtn->[0]->[0];
  } else {
    return undef;
  }
}

sub _get_noteFileName {
  my $self = shift;
  my $fileID = shift;
  my $dbh = $self->dbh();
  my ($sth,$rtn);

  $sth = $dbh->prepare("select FILE from notebookFiles where ID = ?");
  $sth->bind_param(1,$fileID);

  $rtn = $self->_dbAction($dbh,$sth,2);

  if (ref $rtn eq 'ARRAY') {
    return $rtn->[0]->[0];
  } else {
    return undef;
  }
}

sub noteFileOwner {
	my $self = shift;
	my $fileID = shift;
	my $noteFileOwner = shift;
	
	$noteFileOwner ? $self->_set_noteFileOwner($fileID,$noteFileOwner) : $self->_get_noteFileOwner($fileID);
}

sub _set_noteFileOwner {
	my $self = shift;
	my $fileID = shift;
	my $noteFileOwner = shift;
	my $dbh = $self->dbh();
	my ($sth,$rtn);

	$sth = $dbh->prepare("update notebookFiles set OWNER = ? where ID = ?");
	$sth->bind_param(1,$noteFileOwner);
	$sth->bind_param(2,$fileID);
	
	$rtn = $self->_dbAction($dbh,$sth,3);
	
	if (ref $rtn eq 'ARRAY') {
		return $rtn->[0]->[0];
	} else {
		return undef;
	}
}

sub _get_noteFileOwner {
	my $self = shift;
	my $fileID = shift;
	my $dbh = $self->dbh();
	my ($sth,$rtn);
	
	$sth = $dbh->prepare("select OWNER from notebookFiles where ID = ?");
	$sth->bind_param(1,$fileID);
	
	$rtn = $self->_dbAction($dbh,$sth,2);
	
	if (ref $rtn eq 'ARRAY') {
		return $rtn->[0]->[0];
	} else {
		return undef;
	}
}

sub user_isNoteFileOwner {
	my $self = shift;
	my $userID = shift;
	my $fileID = shift;
	
	if ($userID == $self->noteFileOwner($fileID)) {
		return 1;
	} else {
		return undef;
	}
}

sub deleteNoteFileEntry {
	my $self = shift;
	my $fileID = shift;
	my $dbh = $self->dbh();
	my ($sth,$rtn);

	$sth = $dbh->prepare("delete from notebookFiles where ID = ?");
	$sth->bind_param(1,$fileID);
	
	$rtn = $self->_dbAction($dbh,$sth,4);
	
	if (ref $rtn eq 'ARRAY') {
		return $rtn->[0]->[0];
	} else {
		return undef;
	}
}

sub shrink {
	my $obj = shift;
	my $string = shift;
	my $compressed;
#	printlog("shrinking string '$$string'");

	$compressed = compress($$string);

#	printlog("returning string '$compressed'");
	return $compressed;

}

sub expand {
	my $obj = shift;
	my $string = shift;
	my $decompressed;

	$decompressed = decompress($$string);
	return $decompressed;
}

sub is_compressed {
  my $obj = shift;
  my $noteID = shift;
  my $dbh = $obj->dbh();
  my $compressed;
  my ($sth,$rtn);

  printlog("checking if note $noteID is compressed") if ($debug eq 'Y');

  $sth = $dbh->prepare("select compressed from notebook where id = ?");
  $sth->bind_param(1,$noteID);

  $rtn = $obj->_dbAction($dbh,$sth,2);
  if (ref $rtn eq 'ARRAY') {
    if ($rtn->[0]->[0]) {
      $compressed = $rtn->[0]->[0];
    } else {
      $compressed = 0;
    }
  } else {
    $compressed = 0;
  }

  printlog("CGRBseq::is_compressed returning " . $compressed) if ($debug eq 'Y');

  return $compressed;
}

sub search {
  my $self = shift;
  my $params = shift;
  my $userid = $params->{user_id};
  $userid = $self->{_CGRBuser}->usernum() unless($userid);
  my $column = $params->{search_column};
  my $term = $params->{search_term};
  my $group_id = $params->{group_id};
  my $table = $params->{table};
  $table = 'subjct' unless ($table && $table eq 'subjct');
  $column = 'name' unless ($column && ($column eq 'name' || $column eq 'descr'));
  return undef unless ($term && $term =~ /\w+/);
#
# 	wildcards?
  $term =~ s/\*/%/g;
#
  my ($dbh,$sth,$rtn) = $self->dbh();
#  my $query = "select num from $table where $column like ? AND (user = ?";
  my $query = "select num, name, descr, type, blast, blasttype, E, species, userGroup from $table where $column like ? AND (user = ?";

  if ($group_id && $group_id != 1) {
    if ($self->{_CGRBuser}->user_isGroupOwner($userid,$group_id)) {
      $query .= " AND userGroup = ?)";
    } else {
      $query .= " OR userGroup = ?)";
    }
  } else {
    $query .= ")";
  }
  
#  $sth = $dbh->prepare("select num from $table where $column like ? AND user = ? AND userGroup = ?");
  $sth = $dbh->prepare($query);
  $sth->bind_param(1,$term);
  $sth->bind_param(2,$userid);
  $sth->bind_param(3,$group_id);
#  $rtn = $self->dbAction($dbh,$sth,2);
  $rtn = $self->seqlist_adv({sth =>$sth});

  if (ref($rtn) eq 'ARRAY') {
    return { rtn => $rtn, term => $term};
  } else {
    return undef;
  }

}

sub protein_domain {
  my $self = shift;
  my $params = shift;
  return unless ($params->{subjct});

  ($params->{image} && $params->{report}) ? $self->_set_protein_domain($params->{subjct},$params->{image},$params->{report}) : $self->_get_protein_domain($params->{subjct});

}

sub _set_protein_domain {
  my $self = shift;
  my $subjct = shift;
  my $image = shift;
  my $report = shift;
  my $dbh = $self->dbh();
  my ($sth,$rtn);

  $self->delete_protein_domain($subjct);

  $sth = $dbh->prepare("insert into protein_domain (subjct,image,report) values(?,?,?)");
  $sth->bind_param(1,$subjct);
  $sth->bind_param(2,$image);
  $sth->bind_param(3,$report);

  $rtn = $self->dbAction($dbh,$sth,1);

  if (ref($rtn) eq 'ARRAY') {
    return $rtn->[0]->[0];
  } else {
    return undef;
  }
}

sub _get_protein_domain {
  my $self = shift;
}

sub protein_domain_image {
  my $self = shift;
  my $params = shift;
  return unless ($params->{subjct});

  $params->{image} ? $self->_set_protein_domain_image($params->{subjct},$params->{image}) : $self->_get_protein_domain_image($params->{subjct});
}

sub _set_protein_domain_image {
  return 'method unavailable';
}

sub _get_protein_domain_image {
  my $self = shift;
  my $subjct = shift;
  my $dbh = $self->dbh();
  my ($sth,$rtn);

  $sth = $dbh->prepare("select image from protein_domain where subjct = ?");
  $sth->bind_param(1,$subjct);

  $rtn = $self->dbAction($dbh,$sth,2);

  if (ref($rtn) eq 'ARRAY') {
    return $rtn->[0]->[0];
  } else {
    return undef;
  }
}

sub protein_domain_report {
  my $self = shift;
  my $params = shift;
  return unless ($params->{subjct});

  $params->{image} ? $self->_set_protein_domain_report($params->{subjct},$params->{image}) : $self->_get_protein_domain_report($params->{subjct});

}

sub _set_protein_domain_report {
  return 'method unavailable';
}

sub _get_protein_domain_report {
  my $self = shift;
  my $subjct = shift;
  my $dbh = $self->dbh();
  my ($sth,$rtn);

  $sth = $dbh->prepare("select report from protein_domain where subjct = ?");
  $sth->bind_param(1,$subjct);

  $rtn = $self->dbAction($dbh,$sth,2);

  if (ref($rtn) eq 'ARRAY') {
    return $rtn->[0]->[0];
  } else {
    return undef;
  }

}

sub delete_protein_domain {
  my $self = shift;
  my $subjct = shift;
  return undef unless ($subjct);
  my $dbh = $self->dbh();
  my ($sth,$rtn);

  $sth = $dbh->prepare("delete from protein_domain where subjct = ?");
  $sth->bind_param(1,$subjct);

  $rtn = $self->dbAction($dbh,$sth,3);

  if (ref($rtn) eq 'ARRAY') {
    return $rtn->[0]->[0];
  } else {
    return undef;
  }
}
