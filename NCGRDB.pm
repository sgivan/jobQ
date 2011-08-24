package NCGRDB;
# $Id: NCGRDB.pm,v 1.3 2003/12/16 00:08:43 givans Exp $

use lib '/home/cgrb/givans/lib';
use CGRBDB;

@ISA = qw(CGRBDB);

1;

BEGIN {
    open(LOG,">/home/cgrb/givans/lib/ncgrdb.log") or die "can't open 'ncgrdb.log': $!";
}

END {
    close(LOG);
}

sub new {
    my ($pkg) = shift;
    print LOG "Initializing '$pkg' object\n";

    my $dbase = 'nahla';
    my $user = 'ncgr';
    my $pass = '!ncgr?03';

    my $dbh = $pkg->SUPER::new($dbase,$user,$pass);

    return $dbh;
}

sub gi_insert {}

sub gi_fetch {}

sub gi_cnt {}

sub gi_add {
    my $obj = shift;
    my $gi = shift;
    my $genus = shift;
    my $genus_id = $obj->genus_chk($genus)->[0];
    my $dbh = $obj->{_dbh};
    print LOG "gi_add: '$gi' for '$genus' (genus id: '$genus_id')\n";

    my $sth = $dbh->prepare("insert into GI (GI,genus) values ($gi,$genus_id)");
    return "can't prepare insert statement in gi_add: $dbh->errstr" if (!$sth);
    return "can't execute insert statement in gi_add: $dbh->errstr" if (!$sth->execute);

    return 1;
}
    
sub gi_del {}

sub gi_chk {
    my $obj = shift;
    my $gi = shift;
    my $dbh = $obj->{_dbh};
    print LOG "gi_chk for '$gi'\n";
    
    my $sth = $dbh->prepare("select * from GI where GI = $gi");
    return "can't prepare select in gi_chk: $dbh->errstr" if (!$sth);
    return "can't execute select in gi_chk: $dbh->errstr" if (!$sth->execute);

    my $array_ref = $sth->fetchrow_arrayref();

    return $array_ref;

}

sub genus_cnt {}

sub genus_add {}

sub genus_del {}

sub genus_chk {
    my $obj = shift;
    my $genus = shift;
    my $dbh = $obj->{_dbh};
    print LOG "genus check for '$genus'\n";

    my $sth = $dbh->prepare("select * from genus where genus = '$genus'");
    return "can't prepare select statement in genus_chk: $dbh->errstr" if (!$sth);
    return "can't execute select statement in genus_chk: $dbh->errstr" if (!$sth->execute);

    my $array_ref = $sth->fetchrow_arrayref();
    return $array_ref;

}

sub genus_gi_cnt {
    my $obj = shift;
    my $genus = shift;
    print LOG "genus_gi_cnt check for '$genus'\n";

    my $array_ref = $obj->genus_chk($genus);

    return $array_ref->[2];
}

sub genus_list {
    my $obj = shift;
    my $dbh = $obj->{_dbh};
    print LOG "fetching genus_list\n";

    my $sth = $dbh->prepare("select genus from genus");
    return "can't prepare select statement in genus_list: $dbh->errstr" if (!$sth);
    return "can't execute select statement in genus_list: $dbh->errstr" if (!$sth->execute);

#    $sth->dump_results();
    my $array_ref = $sth->fetchall_arrayref();

    return $array_ref;
}
