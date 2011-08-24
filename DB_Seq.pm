package PSD::DB_Seq;
use DBI;
# $Id: DB_Seq.pm,v 1.1 2004/03/08 21:45:54 givans Exp $
#
use strict;
use Carp;
use lib '/home/cgrb/givans/lib/perl5/devel';
use CGRBDB;
use vars qw/@ISA/;

@ISA = ("CGRBDB");
my $debug = 'N';


if ($debug eq 'Y') {
  printlog("\n\n+++++++++++++++++++++++++++++++++++++++++++++++++++++");
}

1;

sub new {
  my ($pkg,$username) =  @_;
  my $dbase = 'blast_seqs';
  my $user = 'blast';
  my $pass = 'CGRBlast';
  printlog("Establishing connection to '$dbase' database\npkg: '$pkg'\n") if ($debug eq 'Y');

  my $cgrb = $pkg->SUPER::new($dbase,$user,$pass);

  printlog("Connection established") if ($debug eq 'Y');

  if ($username) {
    if ( $username =~ /\w+/ ) {
      $cgrb->userinfo($username);
    }
  }

  return $cgrb;
}


sub userinfo {
  my ($obj,$username) = @_;
  my $dbh = $obj->{_dbh};
  $obj->{_username} = $username;
  printlog("creating userinfo hash for '$username'") if ($debug eq 'Y');

  my $sth = $dbh->prepare("select u.num usernum, u.first firstname, u.last lastname, l.name labname, u.lab labnum, u.login login, u.phone phone, u.email email from user u, lab l where login = '$username'");
  return "can't prepare userinfo query: $dbh->errstr" if (!$sth);
  return "can't execute userinfo query: $dbh->errstr" if (!$sth->execute);

  my $userinfo = $sth->fetchrow_hashref;
  $obj->{_usernum} = $userinfo->{'usernum'};
  $obj->{_firstname} = $userinfo->{'firstname'};
  $obj->{_lastname} = $userinfo->{'lastname'};
  $obj->{_labname} = $userinfo->{'labname'};
  $obj->{_labnum} = $userinfo->{'labnum'};
  $obj->{_login} = $userinfo->{'login'};
  $obj->{_phone} = $userinfo->{'phone'};
  $obj->{_email} = $userinfo->{'email'};
  $sth->finish;

  return $userinfo;

}


sub firstname {			### Accessor
  my $obj = shift;
  my $user = shift;

  @_ ? $obj->{'_firstname'} = shift : $obj->{'_firstname'};
}


sub lastname {			### Accessor
  my $obj = shift;
  my $user = shift;

  @_ ? $obj->{'_lastname'} = shift : $obj->{'_lastname'};
}

sub useremail {			### Accessor
  my $obj = shift;
  my $username = shift;
  my $dbh = $obj->{_dbh};
  printlog("accessing email address of user: '$username'") if ($debug eq 'Y');

  @_ ? $obj->{'_email'} = shift : $obj->_useremail($username);

}

sub _useremail {
  my $obj = shift;
  my $username = shift;

  printlog("retrieving email address for '$username'") if ($debug eq 'Y');

  $obj->userinfo($username);

  printlog("returning email address: " . $obj->{_email}) if ($debug eq 'Y');
  return $obj->{'_email'};
}

sub usernum {			### Accessor
  my $obj = shift;
  my $user = shift;
  $user = $obj->{_login} unless ($user);
  printlog("accessing usernum for '$user'") if ($debug eq 'Y');
 
  @_ ? $obj->{_usernum} = shift : $obj->_usernum($user);

}

sub _usernum {
  my $obj = shift;
  my $username = shift;
  printlog("retrieving usernum for '$username'") if ($debug eq 'Y');
    
  $obj->userinfo($username);

  printlog("_usernum:  returning " . $obj->{'_usernum'}) if ($debug eq 'Y');
  return $obj->{'_usernum'};
}

sub login {			## Accessor
  my $obj = shift;
  my $user = shift;

  printlog("accessing login name for '$user'") if ($debug eq 'Y');

  @_ ? $obj->{_login} = shift : $obj->{_login};
}


sub seqtype {
  my $obj = shift;
  my $seqnum = shift;
  my $dbh = $obj->{_dbh};

  printlog("CGRBseq::seqtype: retrieving seqtype") if ($debug eq 'Y');
    
  my $sth = $dbh->prepare("select type from subjct where num = $seqnum");
  return "can't prepare seqtype query: " . $dbh->errstr if (!$sth);
  return "can't execute seqtype query: " . $dbh->errstr if (!$sth->execute);
  my @type = $sth->fetchrow_array;
  $sth->finish;

  return $type[0];
    
}

sub dbtype {
  my $obj = shift;
  my $subjct = shift;
  my $dbh = $obj->{_dbh};
  my @dbtype;

  printlog("retrieving dbtype") if ($debug eq 'Y');

  my $sth = $dbh->prepare("select b.dbtype from blast_map b, subjct s where s.num = $subjct AND s.blasttype = b.id");
  return "can't prepare dbtype query: " . $dbh->errstr if (!$sth);
  return "can't execute dbtype query: " . $dbh->errstr if (!$sth->execute);
  @dbtype = $sth->fetchrow_array;
  warn("can't close sth in dbtype: " . $dbh->errstr) if (!$sth->finish);

  return $dbtype[0];
}

sub seqname {
  my $obj = shift;
  my $seqnum = shift;
  my $dbh = $obj->{_dbh};
    
  my $sth = $dbh->prepare("select name from subjct where num = $seqnum");
  return "can't prepare seqname query: " . $dbh->errstr if (!$sth);
  return "can't execute seqname query: " . $dbh->errstr if (!$sth->execute);
  my $name = $sth->fetchrow_arrayref;
  $sth->finish;

  return $name;
    
}   

sub old_usernum {
  my ($obj,$array_r) = @_;
  my ($first,$last) = ();


  if ($array_r) {
    ($first,$last) = @$array_r;
  } else {
    return $obj->{_usernum};
  }

  my $sth = $obj->{_dbh}->prepare("select * from user where first = '$first' AND last = '$last'");

  if (!$sth) {
    die "can't prepare usernum statement: $!";
  }

  if (!$sth->execute) {
    die "can't execute usernum statement: $!";
  }
  my $row = $sth->fetchrow_arrayref;

  $sth->finish;



  $obj->{_usernum} = $row->[0];
  $obj->{_labid} = $row->[3];

  return $obj->{_usernum};

    

}

sub labid {
  my ($obj,$value) = @_;

  if ( $value ) {
    $obj->{'_labid'} = $value;
  } else {
    return $obj->{'_labid'};
  }

}

sub fetch_seq {
  my $obj = shift;
  my $id = shift;

  my $sth = $obj->{_dbh}->prepare("select sequence from subjct where num = $id");

  if (!$sth) {
    die "can't prepare select in sequence fetch: $!";
  }

  if (!$sth->execute) {
    die "can't execute select in sequence fetch: $!";
  }

  my $row = $sth->fetchrow_arrayref;
  $sth->finish;


  $obj->{_sequence} = $row->[0];
    
  return $obj->{_sequence};

}

sub fetchoneseq {
  #    my ($obj,$seqname) = @_;
  my ($obj,$subjct) = @_;
  my $dbh = $obj->{_dbh};
  my ($package, $filename, $line) = caller() if ($debug eq 'Y');
  printlog("CGRBseq::fetchoneseq:  subjct = '$subjct'\npkg: $package, file: $filename, $line: $line\n") if ($debug eq 'Y');

  #    my $sth = $dbh->prepare("select name, descr, sequence, type, blast, blasttype, E, species from subjct where name = '$seqname' AND user = $obj->{_usernum}");
#  my $sth = $dbh->prepare("select name, descr, sequence, type, blast, blasttype, E, species, num from subjct where num = $subjct AND user = $obj->{_usernum}");
  my $sth = $dbh->prepare("select name, descr, sequence, type, blast, blasttype, E, species, num from subjct where num = $subjct");
  return ["can't prepare fetchoneseq query: " . $dbh->errstr] if (!$sth);
  return ["can't execute fetchoneseq query:  ". $dbh->errstr] if (!$sth->execute);
  my $seqarray_r = $sth->fetchrow_arrayref;
  $sth->finish;

  return $seqarray_r;

}

sub subjct_species {
  my ($obj,$subjct) = @_;

  my $species = $obj->fetchoneseq($subjct)->[7];

  return $species;
}
    


sub seqlist {
  my $obj = shift;
  my $dbh = $obj->{_dbh};

  my $sth = $dbh->prepare("select num, name, descr, type, blast, blasttype, E, species from subjct where user = " . $obj->{'_usernum'});
  return "can't prepare seqlist query: $dbh->errstr"  if (!$sth);
  return "can't execute seqlist query: $dbh->errstr" if (!$sth->execute);
  my $seqarray_r = $sth->fetchall_arrayref;
  $sth->finish;

  return $seqarray_r;

}

sub seqnumlist {
  my $obj = shift;
  my $dbh = $obj->{_dbh};

  my $sth = $dbh->prepare("select num from subjct where user = " . $obj->{'_usernum'});
  return "can't prepare seqlist query: $dbh->errstr"  if (!$sth);
  return "can't execute seqlist query: $dbh->errstr" if (!$sth->execute);
  my $seqarray_r = $sth->fetchall_arrayref;
  $sth->finish;

  return $seqarray_r;

}

sub addseq {
  my $obj = shift;
  my ($name,$descr,$type,$sequence,$blast) = @_;
  my $blasttype = 'NULL';
  my $blastE = '10';
  my $species = 'NULL';
  if ($blast eq 'Y') {
    $blasttype = $_[5];
    $blastE = $_[6];
    $species = $_[7] if ($_[7] =~ /\w+/);
  }
  return "No valid sequence was passed to library" unless ($sequence =~ /\w+/);
  my $dbh = $obj->{_dbh};

  printlog("adding sequence $name to subjct table") if ($debug eq 'Y');

  my $sth = $dbh->prepare("lock tables subjct write");
  return "can't prepare subjct lock: " . $dbh->errstr if (!$sth);
  return "can't execute subjct lock: " . $dbh->errstr if (!$sth->execute);

  printlog("subjct table is locked") if ($debug eq 'Y');

  $sth = $dbh->prepare("insert into subjct (name, descr, type, sequence, user, lab, blast, blasttype, E, species) values ('$name', '$descr', '$type', '$sequence', '$obj->{_usernum}', '$obj->{_labnum}', '$blast', $blasttype, $blastE, '$species')");
  return "can't prepare addseq query: " . $dbh->errstr if (!$sth);
  return "can't execute addseq query: " . $dbh->errstr if (!$sth->execute);

  printlog("$name has been inserted into subjct table") if ($debug eq 'Y');

  $sth = $dbh->prepare("select max(num) from subjct");
  return "can't prepare max(num) select from subjct: " . $dbh->errstr if (!$sth);
  return "can't execute max(num) select from subjct: " . $dbh->errstr if (!$sth->execute);
  my $row = $sth->fetchrow_arrayref;

  printlog("max num returned as $row->[0] from subjct table") if ($debug eq 'Y');

  $sth = $dbh->prepare("unlock tables");
  return "can't prepare unlock subjct table: " . $dbh->errstr if (!$sth);
  return "can't execute unlock subjct table: " . $dbh->errstr if (!$sth->execute);
  $sth->finish;

  printlog("subjct table has been unlocked, returning max id") if ($debug eq 'Y');

  $sth->finish;
 # my $answer = ['dummy','array'];

  return $row->[0]; ### returns subjct id of this sequence

}

sub addhit {
  my $obj = shift;
  my $hit = shift;
  my $dbh = $obj->{_dbh};
  printlog("adding hit '$hit->[1]' [from CGRB.pm]") if ($debug eq 'Y');

  $hit->[3] =~ s/'/\\'/g;
  #    print LOG "subj: '" . $hit->[0] . "', descr: '" . $hit->[3] . "'\n";


 
  my $sth = $dbh->prepare("insert into hits (subjct,hit,E,descr,seqtype) values ('$hit->[0]','$hit->[1]',$hit->[2],'$hit->[3]','$hit->[4]')");
  return "can't prepare addhit query: " . $dbh->errstr if (!$sth);
  return "can't execute addhit query: " . $dbh->errstr if (!$sth->execute);
  $sth->finish;

  return [];

}

sub checkpair {
  my $obj = shift;
  my $sub_hit = shift;
  my $dbh = $obj->{_dbh};

  my $sth = $dbh->prepare("select num from  hits where subjct = '$sub_hit->[0]' AND hit = '$sub_hit->[1]'");
  return "can't prepare gethitnum query: " . $dbh->errstr if (!$sth);
  return "can't execute gethitnum query: " . $dbh->errstr if (!$sth->execute);
  my $result = $sth->fetchall_arrayref;
  $sth->finish;

  return $result;

}

sub blastcheck {
  my $obj = shift;
  my $seqnum = shift;
  my $dbh = $obj->{_dbh};

  my $sth = $dbh->prepare("select blast from subjct where num = $seqnum");
  return "can't prepare blastcheck query: " . $dbh->errstr if (!$sth);
  return "can't execute blastcheck query: " . $dbh->errstr if (!$sth->execute);
  my @blast = $sth->fetchrow_array;
  $sth->finish;

  return $blast[0];

}


sub updateseq {
  my $obj = shift;
  my $array_r = shift;

  my ($subjct,$name,$descr,$type,$sequence,$blast,$blasttype,$blastE,$species) = ($array_r->[0],$array_r->[1],$array_r->[2],$array_r->[3],$array_r->[4],$array_r->[5],$array_r->[6],$array_r->[7]);

  my $dbh = $obj->{_dbh};

  my $sth = $dbh->prepare("update subjct set name = '$name', descr = '$descr', type = '$type', sequence = '$sequence', blast = '$blast', blasttype = '$blasttype', E = '$blastE', species = '$species' where num = $subjct");
  #    print LOG "name: '$name', descr: '$descr', type: '$type', sequence: '$sequence', blast: '$blast', num: '$number'\n";
  return "can't prepare updateseq query: " . $dbh->errstr if (!$sth);
  return "can't execute updateseq query: " . $dbh->errstr if (!$sth->execute);
  $sth->finish;


  return [];
    
}

sub deleteseq {
  my $obj = shift;
  my @seqnums = @_;
  my $dbh = $obj->{_dbh};

  foreach my $number (@seqnums) {
    my $sth = $dbh->prepare("delete from subjct where num = $number");
    return "can't prepare deleteseq query: " . $dbh->errstr if (!$sth);
    return "can't execute deleteseq query: " . $dbh->errstr if (!$sth->execute);
    $sth->finish;
  }

  return [];

}

sub seqnumber {
  my $obj = shift;
  my $name = shift;
  my $dbh = $obj->{_dbh};

  my $sth = $dbh->prepare("select num from subjct where user = $obj->{_usernum} AND name = '$name'");
  return "can't prepare seqnumber query: " . $dbh->errstr if (!$sth);
  return "can't execute seqnumber query: " . $dbh->errstr if (!$sth->execute);
  my @row = $sth->fetchrow_array;
  $sth->finish;

  return $row[0];

}

sub hitCount {
  my $obj = shift;
  my $subjct = shift;
  my $dbh = $obj->{_dbh};
  my $hitCount;
  printlog("CGRBseq::hitCount - getting hitcount for subjct = '$subjct'") if ($debug eq 'Y');

  my $sth = $dbh->prepare("select count(num) from hits where subjct = $subjct");
  return "can't prepare query in hitCount: " . $dbh->errstr if (!$sth);
  return "can't execute query in hitCount: " . $dbh->errstr if (!$sth->execute);
  $hitCount = $sth->fetchrow_arrayref;
  $sth->finish;
  printlog("CGRBseq::hitCount - returning " . $hitCount->[0]) if ($debug eq 'Y');
  return $hitCount->[0];
}

sub newhitCount {
  my $obj = shift;
  my $subjct = shift;
  my $dbh = $obj->{_dbh};
  my $newhitCount;

  my $sth = $dbh->prepare("select count(num) from hits where subjct = $subjct and new = 'Y'");
  return "can't prepare query in hitCount: " . $dbh->errstr if (!$sth);
  return "can't execute query in hitCount: " . $dbh->errstr if (!$sth->execute);
  $newhitCount = $sth->fetchrow_arrayref;
  $sth->finish;

  return $newhitCount->[0];
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
  my $dbh = $obj->{_dbh};
  my $subjct = shift;

  my $sth = $dbh->prepare("select num, hit, E, descr, new from hits where subjct = $subjct order by E");
  return "can't prepare seeblast query: " . $dbh->errstr if (!$sth);
  return "can't execute seeblast query: " . $dbh->errstr if (!$sth->execute);
  my $result = $sth->fetchall_arrayref;
  $sth->finish;

  return $result;

}

sub seehit {
  my $obj = shift;
  my $dbh = $obj->{_dbh};
  my $hitnum = shift;

  my $sth = $dbh->prepare("select * from hits where num = $hitnum");
  return "can't prepare seehit query: " . $dbh->errstr if (!$sth);
  return "can't execute seehit query: " . $dbh->errstr if (!$sth->execute);
  my $result = $sth->fetchall_arrayref;
  $sth->finish;

  return $result;

}

sub hit_seqtype {
  my $obj = shift;
  my $hitnum = shift;

  return $obj->seehit($hitnum)->[0][7];

}

sub check_new_hits {
  my $obj = shift;
  my $dbh = $obj->{_dbh};
  my $user = $obj->{_usernum};

  my $sth = $dbh->prepare("select distinct h.subjct from hits h, subjct s where s.user = $user AND h.subjct = s.num AND h.new = 'Y'");
  return "can't prepare check_new_hits query: " . $dbh->errstr if (!$sth);
  return "can't execute check_new_hits query: " . $dbh->errstr if (!$sth->execute);
  my $result = $sth->fetchall_arrayref;
  $sth->finish;

  return $result;

}

sub get_new_hits {
  my $obj = shift;
  my $dbh = $obj->{_dbh};
  #  my $subjct = $obj->seqnumber(shift);
  my $subjct = shift;
  printlog("select num, hit, E, descr, new from hits where subjct = '$subjct' AND new = 'Y' order by E") if ($debug eq 'Y');
  my $sth = $dbh->prepare("select num, hit, E, descr, new from hits where subjct = '$subjct' AND new = 'Y' order by E");
  return "can't prepare query in CGRBseq::get_new_hits: " . $dbh->errstr if (!$sth);
  return "can't execute query in CGRBseq::get_new_hits: " . $dbh->errstr if (!$sth->execute);
  my $result = $sth->fetchall_arrayref;
  $sth->finish;

  return $result;
}

sub set_hit_old {
  my $obj = shift;
  my $dbh = $obj->{_dbh};
  my $hit = shift;

  my $sth = $dbh->prepare("update hits set new = 'N' where num = $hit");
  return "can't prepare set_hit_old query: " . $dbh->errstr if (!$sth);
  return "can't execute set_hit_old query: " . $dbh->errstr if (!$sth->execute);
  $sth->finish;

  return [];

}


sub end {
  my $obj = shift;
  my $dbh = $obj->{_dbh};

  $dbh->disconnect;

}

sub blast_init {
  my $obj = shift;
 
  my $subjct = shift;

  printlog("initiating BLAST job for '$subjct'") if ($debug eq 'Y');

  my $prog = '/home/cgrb/givans/bin/blastSQL.pl';
  printlog("passing to BLAST: '$prog initial $obj->{_username} $subjct'\n") if ($debug eq 'Y');

  open (BLAST, "| $prog initial $obj->{_username} $subjct") || die "can't start BLAST job: $!";

  if (!close(BLAST)) { 
    printlog("can't close BLAST pipe: $!") if ($debug eq 'Y');
    #	die "can't end BLAST job: $!";
    return "can't close BLAST job: $!";
  }

  printlog("BLAST pipe closed properly\n") if ($debug eq 'Y');

  return [];

}

sub username_list {
  my $obj = shift;
  my $dbh = $obj->{_dbh};
    
  my $sth = $dbh->prepare("select login from user");
  return "can't prepare username_list query: " . $dbh->errstr if (!$sth);
  return "can't execute username_list query: " . $dbh->errstr if (!$sth->execute);
  my $result = $sth->fetchall_arrayref;
  $sth->finish;

  return $result;

}

sub deletehit {
  my $obj = shift;
  my $dbh = $obj->{_dbh};
  my $hitnum = shift;
  #    print LOG "deletehit: deleting hit '$hitnum'\n";

  my $sth = $dbh->prepare("delete from hits where num = $hitnum");
  return "can't prepare deletehit query: " . $dbh->errstr if (!$sth);
  return "can't execute deletehit query: " . $dbh->errstr if (!$sth->execute);
  $sth->finish;

  return [];

}

sub deletehit_bysubjct {
  my $obj = shift;
  my $dbh = $obj->{_dbh};
  my $subjct = shift;
  #    print LOG "deletehit_bysubjct subj: '$subjct'\n";

  my $sth = $dbh->prepare("select num from hits where subjct = $subjct");
  return "can't prepare deletehit_bysubjct: " . $dbh->errstr if (!$sth);
  return "can't execute deletehit_bysubjct: " . $dbh->errstr if (!$sth->execute);

  while (my $row = $sth->fetchrow_arrayref) {
    #	print LOG "deleting '$row->[0]' from hits\n";
    $obj->deletehit($row->[0]);
  }
  $sth->finish;

  return [];

}

sub blastjob {
  my $obj = shift;
  my $dbh = $obj->{_dbh};
  my $subjct = shift;

  my $sth = $dbh->prepare("select b.prog, b.db, s.E from blast_map b, subjct s where s.blasttype = b.id AND s.num = $subjct");
  return "can't prepare blastjob query: " . $dbh->errstr if (!$sth);
  return "can't execute blastjob query: " . $dbh->errstr if (!$sth->execute);

  my $row = $sth->fetchrow_arrayref;
  $sth->finish;

  return $row;

}
	
sub printlog {
  my $mssg = shift;
  open(LOG, ">>/home/cgrb/givans/lib/perl5/devel/DB_Seq.log") or die "can't open CGRBseq.log:  $!";
  print LOG "$mssg\n";
  close(LOG);
  return 1;
}

sub storeNote { ### call with (subjct, 'note content', 'note type')
  my $obj = shift;
  my $dbh = $obj->{_dbh};
  my $subjct = shift;
  my $note = shift;
  my $type = shift;
  my $quoted_note = quotemeta($note);

  printlog("storing note for '$subjct', type: '$type'") if ($debug eq 'Y');

  my $sth = $dbh->prepare("lock tables notebook write");
  return "can't prepare notebook lock: " . $dbh->errstr if (!$sth);
  return "can't execute notebook lock: " . $dbh->errstr if (!$sth->execute);

  printlog("notebook table is locked") if ($debug eq 'Y');

  $sth = $dbh->prepare("insert into notebook (subjct, note, type, date) values ($subjct, \"$quoted_note\", '$type', now())");
  return "can't prepare notebook insert: " . $dbh->errstr if (!$sth);
  return "can't execute notebook insert: " . $dbh->errstr if (!$sth->execute);

  printlog("note has been inserted") if ($debug eq 'Y');

  $sth = $dbh->prepare("select max(id) from notebook");
  return "can't prepare max(id) select from notebook: " . $dbh->errstr if (!$sth);
  return "can't execute max(id) select from notebook: " . $dbh->errstr if (!$sth->execute);
  my $row = $sth->fetchrow_arrayref;

  printlog("max id returneds as $row->[0]") if ($debug eq 'Y');

  $sth = $dbh->prepare("unlock tables");
  return "can't prepare unlock notebook table: " . $dbh->errstr if (!$sth);
  return "can't execute unlock notebook table: " . $dbh->errstr if (!$sth->execute);
  $sth->finish;

  printlog("notebook table has been unlocked, returning max id") if ($debug eq 'Y');

  return $row->[0];		## returns note id
}

sub saveNote {
  my $obj = shift;
  my $noteId = shift;
  my $title = shift;
  my $dbh = $obj->{_dbh};

  $title = 'untitled' unless ($title);

  printlog("saving note '$noteId', title: '$title'") if ($debug eq 'Y');

  my $sth = $dbh->prepare("update notebook set title = '$title', saved = 'Y' where id = $noteId");
  return "can't prepare saveNote statement: " . $dbh->errstr if (!$sth);
  return "can't execute saveNote statement: " . $dbh->errstr if (!$sth->execute);

  return 0;

}

sub deleteNotes {
  my $obj = shift;
  my $ids = shift;
  my $dbh = $obj->{_dbh};

  foreach my $id (@$ids) {

    my $sth = $dbh->prepare("delete from notebook where id = $id");
    return "can't prepare deleteNote statement: " . $dbh->errstr if (!$sth);
    return "can't execute deleteNote statement: " . $dbh->errstr if (!$sth->execute);
    $sth->finish;
  }

  return 0;

}

sub getNote {
  my $obj = shift;
  my $noteId = shift;
  my $dbh = $obj->{_dbh};

  my $sth = $dbh->prepare("select title, note, subjct from notebook where id = $noteId");
  return "can't prepare getNote statement: " . $dbh->errstr if (!$sth);
  return "can't execute getNote statement: " . $dbh->errstr if (!$sth->execute);
  my $row = $sth->fetchrow_arrayref;

  return $row;

}

sub getNotes {
  my $obj = shift;
  my $subjct = shift; # PSD sequence number
  my $order = shift; # sort by this column
  my $desc = shift; # sort order (ascending/descending)
  my $dbh = $obj->{_dbh};
  my $orderBy;

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

  my $sth;

  if ($desc) {
    $sth = $dbh->prepare("select id, title, type, date from notebook where subjct = '$subjct' AND saved = 'Y' order by $orderBy $desc");
  } else {
    $sth = $dbh->prepare("select id, title, type, date from notebook where subjct = '$subjct' AND saved = 'Y' order by $orderBy");
  }

  return "can't prepare getNotes statement: " . $dbh->errstr if (!$sth);
  return "can't execute getNotes statement: " . $dbh->errstr if (!$sth->execute);
  my $row = $sth->fetchall_arrayref;
  $sth->finish;

  return $row;
}

sub changeNoteTitle {
  my $obj = shift;
  my $id = shift;
  my $title = shift;
  my $dbh = $obj->{_dbh};
  $title = 'untitled' unless ($title =~ /\w/);

  my $sth = $dbh->prepare("update notebook set title = '$title' where id = $id");
  return "can't prepare changeNoteTitle statement: " . $dbh->errstr if (!$sth);
  return "can't execute changeNoteTitle statement: " . $dbh->errstr if (!$sth->execute);
  $sth->finish;

  return 0;
}
