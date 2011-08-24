package CGRBseq;
use DBI;
#$Id: CGRBseq_w.pm,v 1.4 2003/08/20 22:28:20 givans Exp $


use lib '/home/cgrb/cgrb/givans/lib/';
use CGRBDB;
@ISA = ("CGRBDB");
my $debug = 'N';

BEGIN {
  if ($debug eq 'Y') {
    open(LOG, ">>/home/cgrb/cgrb/givans/lib/CGRBseq.log") || die "can't open CGRBseq.log: $!";
  }
}

END {
  if ($debug eq 'Y') {
    print LOG "\n\nclosing CGRBseq.log\n";
    close(LOG);
  }
}

1;

sub new {
    my ($pkg,$username) =  @_;

    my $dbase = 'blast_seqs';
    my $user = 'blast';
    my $pass = 'CGRBlast';
    print LOG "Establishing connection to '$dbase' database\npkg: '$pkg'\n" if ($debug eq 'Y');

    my $cgrb = $pkg->SUPER::new($dbase,$user,$pass);

    print LOG "Connection established\n" if ($debug eq 'Y');

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
    print LOG "creating userinfo hash for '$username'\n" if ($debug eq 'Y');

    my $sth = $dbh->prepare("select u.num usernum, u.first firstname, u.last lastname, l.name labname, u.lab labnum, u.login login, u.phone phone, u.email email from user u, lab l where login = '$username'");
    return "can't prepare userinfo query: $dbh->errstr" if (!$sth);
    return "can't execute userinfo query: $dbh->errstr" if (!$sth->execute);

    my $userinfo = $sth->fetchrow_hashref;
    $obj->{_usernum} = $userinfo->{'usernum'};# unless ($obj->{_usernum});
    $obj->{_firstname} = $userinfo->{'firstname'};# unless ($obj->{_firstname});
    $obj->{_lastname} = $userinfo->{'lastname'};# unless ($obj->{_lastname});
    $obj->{_labname} = $userinfo->{'labname'};# unless ($obj->{_labname});
    $obj->{_labnum} = $userinfo->{'labnum'};# unless ($obj->{_labnum});
    $obj->{_login} = $userinfo->{'login'};# unless ($obj->{_login});
    $obj->{_phone} = $userinfo->{'phone'};# unless ($obj->{_phone});
    $obj->{_email} = $userinfo->{'email'};# unless ($obj->{_email});
    $sth->finish;

    return $userinfo;

}


sub firstname {  ### Accessor
    my $obj = shift;
    my $user = shift;

    @_ ? $obj->{'_firstname'} = shift : $obj->{'_firstname'};#($obj,$user);
}


sub lastname {  ### Accessor
    my $obj = shift;
    my $user = shift;

    @_ ? $obj->{'_lastname'} = shift : $obj->{'_lastname'};
}

sub useremail { ### Accessor
    my $obj = shift;
    my $username = shift;
    my $dbh = $obj->{_dbh};
    print LOG "accessing email address of user: '$username'\n" if ($debug eq 'Y');

#    @_ ? $obj->{'_email'} = shift : $obj->{'_email'};
    @_ ? $obj->{'_email'} = shift : $obj->_useremail($username);

}

sub _useremail {
    my $obj = shift;
    my $username = shift;
#    my $dbh = $obj->{_dbh};
    print LOG "retrieving email address for '$username'\n" if ($debug eq 'Y');

    $obj->userinfo($username);

    print LOG "returning email address: ",$obj->{_email},"\n" if ($debug eq 'Y');
    return $obj->{'_email'};
}

sub usernum { ### Accessor
    my $obj = shift;
    my $user = shift;
    $user = $obj->{_login} unless ($user);
    print LOG "accessing usernum for '$user'\n" if ($debug eq 'Y');
 
#    @_ ? $obj->{_usernum} = shift : $obj->{'_usernum'};
    @_ ? $obj->{_usernum} = shift : $obj->_usernum($user);

}

sub _usernum {
    my $obj = shift;
    my $username = shift;
    print LOG "retrieving usernum for '$username'\n" if ($debug eq 'Y');
    
    $obj->userinfo($username);

    print LOG "returning ",$obj->{'_usernum'},"\n" if ($debug eq 'Y');
    return $obj->{'_usernum'};
}

sub seqtype {
    my $obj = shift;
    my $seqnum = shift;
    my $dbh = $obj->{_dbh};
    
    my $sth = $dbh->prepare("select type from subjct where num = $seqnum");
    return "can't prepare seqtype query: " . $dbh->errstr if (!$sth);
    return "can't execute seqtype query: " . $dbh->errstr if (!$sth->execute);
    my @type = $sth->fetchrow_array;
    $sth->finish;

    return $type[0];
    
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

    if (!$sth) { die "can't prepare select in sequence fetch: $!"; }

    if (!$sth->execute) { die "can't execute select in sequence fetch: $!"; }

    my $row = $sth->fetchrow_arrayref;
    $sth->finish;


    $obj->{_sequence} = $row->[0];
    
    return $obj->{_sequence};

}

sub fetchoneseq {
    my ($obj,$seqname) = @_;
    my $dbh = $obj->{_dbh};

    my $sth = $dbh->prepare("select name, descr, sequence, type, blast, blasttype, E, species from subjct where name = '$seqname' AND user = $obj->{_usernum}");
    return "can't prepare fetchoneseq query: " . $dbh->errstr if (!$sth);
    return "can't execute fetchoneseq query:  ". $dbh->errstr if (!$sth->execute);
    my $seqarray_r = $sth->fetchrow_arrayref;
    $sth->finish;

    return $seqarray_r;

}

sub subjct_species {
    my ($obj,$seqname) = @_;

    my $species = $obj->fetchoneseq($seqname)->[7];

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

    my $sth = $dbh->prepare("insert into subjct (name, descr, type, sequence, user, lab, blast, blasttype, E, species) values ('$name', '$descr', '$type', '$sequence', '$obj->{_usernum}', '$obj->{_labnum}', '$blast', $blasttype, $blastE, '$species')");
    return "can't prepare addseq query: " . $dbh->errstr if (!$sth);
    return "can't execute addseq query: " . $dbh->errstr if (!$sth->execute);
    $sth->finish;
    my $answer = ['dummy','array'];

    return $answer;

}

sub addhit {
    my $obj = shift;
    my $hit = shift;
    my $dbh = $obj->{_dbh};
    print LOG "adding hit '$hit->[0]' [from CGRB.pm]\n" if ($debug eq 'Y');

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
#    open(LOG, ">/home/cgrb/cgrb/givans/lib/CGRBseq.log") || die "can't open log file: $!";
    my $obj = shift;
    my $array_r = shift;
#    my $blastE = '10';
#    my $blasttype = 'N';
    my ($name,$descr,$type,$sequence,$blast,$blasttype,$blastE,$species) = ($array_r->[0],$array_r->[1],$array_r->[2],$array_r->[3],$array_r->[4],$array_r->[5],$array_r->[6],$array_r->[7]);
#    $blasttype = $array_r->[5] if ($array_r->[5]);
#    $blastE = $array_r->[6] if ($array_r->[6]);
    my $dbh = $obj->{_dbh};
    my $number = &seqnumber($obj,$name);
 

    my $sth = $dbh->prepare("update subjct set name = '$name', descr = '$descr', type = '$type', sequence = '$sequence', blast = '$blast', blasttype = '$blasttype', E = '$blastE', species = '$species' where num = $number");
#    print LOG "name: '$name', descr: '$descr', type: '$type', sequence: '$sequence', blast: '$blast', num: '$number'\n";
    return "can't prepare updateseq query: " . $dbh->errstr if (!$sth);
    return "can't execute updateseq query: " . $dbh->errstr if (!$sth->execute);
    $sth->finish;


    return [];
    
}

sub deleteseq {
    my $obj = shift;
    my $name = shift;
    my $dbh = $obj->{_dbh};
    my $number = &seqnumber($obj,$name);

    my $sth = $dbh->prepare("delete from subjct where num = $number");
    return "can't prepare deleteseq query: " . $dbh->errstr if (!$sth);
    return "can't execute deleteseq query: " . $dbh->errstr if (!$sth->execute);
    $sth->finish;

    return [];

}

sub seqnumber {
    my $obj = shift;
    my $name = shift;
    my $dbh = $obj->{_dbh};
#    print LOG "I'm inside of seqnumber, usernum = '" . $obj->{_usernum}. "', name = '$name'\n";

    my $sth = $dbh->prepare("select num from subjct where user = $obj->{_usernum} AND name = '$name'");
    return "can't prepare seqnumber query: " . $dbh->errstr if (!$sth);
    return "can't execute seqnumber query: " . $dbh->errstr if (!$sth->execute);
    
    my @row = $sth->fetchrow_array;
    $sth->finish;

#    print LOG "returning number '$row[0]'\n";

    return $row[0];

}

sub seehits {
    my $obj = shift;
    my $dbh = $obj->{_dbh};
    my $subjct = $obj->seqnumber(shift);
#    print "$subjct\n";

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
    my $subjct = shift;

    my $sth = $dbh->prepare("select num from hits where subjct = $subjct and new = 'Y'");
    return "can't prepare check_new_hits query: " . $dbh->errstr if (!$sth);
    return "can't execute check_new_hits query: " . $dbh->errstr if (!$sth->execute);
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

    print LOG "initiating BLAST job for '$subjct'\n" if ($debug eq 'Y');

    my $prog = '/home/cgrb/cgrb/givans/bin/blastSQL.pl';
    print LOG "passing to BLAST: '$prog initial $obj->{_username} $subjct'\n" if ($debug eq 'Y');

    open (BLAST, "| $prog initial $obj->{_username} $subjct") || die "can't start BLAST job: $!";

    if (!close(BLAST)) { 
	print LOG "can't close BLAST pipe: $!" if ($debug eq 'Y');
	die "can't end BLAST job: $!";
    }

    print LOG "BLAST pipe closed properly\n" if ($debug eq 'Y');

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
	
    
    
    
