package SAR11;
# $Id: SAR11.pm,v 1.14 2004/02/06 20:11:07 givans Exp $

1;

BEGIN {
#  open(OUT, ">SAR11.txt") or die "can't open 'SAR11.txt': $!";
  open(ERR, ">SAR11.err") or die "can't open 'SAR11.err': $!";
}

END {
#  close(OUT);
  close(ERR);
}


sub new {
  my $ref = {};

  bless $ref, 'SAR11';
  return $ref;
}

sub template {
  my $obj = shift;
  my $id = shift;
  my ($template,$direction,$walk);

  if ($id =~ /^(S0[1-4]P\d{1,2}I*[A-H]\d{2})([FR])\.ab1/) {
    $template = $1;
    $direction = $2;
  } elsif ($id =~ /^(S0[1-4]P\d{1,2}I*[A-H]\d{2})\.ab1/) {
    $template = $1;
    $direction = 'walk';
  } elsif ($id =~ /^(S0[1-4]P\d{1,2}I*[A-H]\d{2})c?([FR])\.ab1/) {
    $template = $1;
    $template =~ s/c//;
    $direction = $2;
    $walk = 1;
  } else {
    return 0;
  }

return ($template,$direction,$walk);

}


sub nameParse {
  my $obj = shift;
  my $seqid = shift;
  my $newid = shift;
  my $dir = "";
  print STDOUT "nameparse:\t'$seqid'\n";
  #
  #	Induced or internal primer
  #
  #				     1      2       3              4
  if ($seqid =~ /^[A-H]\d{1,2}_PL(\d{1,2})(\w*?)_(0[1-2])_.+?_([A-H]\d{2})_\d{3}.*?\.ab1$/) {
    if ($2 eq 'I' || $2 eq 'i') {
      $newid .= "04P$1I$4";
    } elsif (! $2) {
      $newid .= "01P$1$4";
    } else {
      print ERR "can't parse '$seqid'\n";
    }
    if ($3 == 01) {
      $dir = "F";
    } elsif ($3 == 02) {
      $dir = "R";
    } else {
      print ERR "can't tell if $seqid is F or R\n";
      exit;
    }
    $newid .= $dir;
    #    $newid .= $2 if ($2);
    #
    #	Induced or internal primer
    #
    #			     1      2        3             4
  } elsif ($seqid =~ /^PL(\d{1,2})(\w*)([A-H]\d{1,2})\.(X0[1-5])_.+\.ab1/) {
    if ($2 eq 'I' || $2 eq 'i') {
      $newid .= "04P$1I$3";
    } elsif (! $2) {
      $newid .= "01P$1$3";
    } else {
      print ERR "can't tell if '$seqid' is induced: $!\n";
    }

    $newid .= 'c' if ($4);

    #	X01 or X02 doesn't imply direction of read (there are X03's and an X05)
    #	therefore, comment the following section
    #     if ($4 == 1) {
    #       $newid .= '_F';
    #     } elsif ($4 == 2) {
    #       $newid .= '_R';
    #     } else {
    #       print ERR "can't tell if '$seqid' is forward or reverse from internal primer: $!\n";
    #     }
    #
    #	PZRO + T7 library
    #
  } elsif ($seqid =~ /^P(\d{1,2})(\w{2,5})_([A-H]\d{2})_.+?\.ab1$/) {
    $newid .= "02P$1$3";
    if ($2 eq 'T7') {
      $newid .= 'F';
    } elsif ($2 eq 'PZR02' || $2 eq 'pzr02') {
      $newid .= 'R';
    } else {
      print ERR "can't tell if $seqid is F or R: '$2'\n";
    }
  } elsif ($seqid =~ /SAR11(P|Plate)(\d{1,2})([A-H][0-9]{1,2})\.(\w+?)_.+\.ab1/i) {
    $newid .= "02P$2$3";
    if ($4 eq 'T7') {
      $newid .= "F";
    } elsif ($4 eq 'PZR02' || $4 eq 'pzr02') {
      $newid .= "R";
    } else {
      print ERR "can't tell direction of '$seqid': '$4'\n";
    }
    #
    #	Non size-fractionated library
    #
  } elsif ($seqid =~ /^\d{5}_Sar11_(MF1)_(\d{2})_([A-H]\d{2})_.+?\.ab1$/) {
#    print ERR "1 = '$1', 2 = '$2'\n";
    my $tmp = $1;
    my $dir = $2;
    my $plt = $3;
    $tmp =~ s/MF/M/;
    $newid .= "03$tmp$plt";
    if ($dir == 01) {
      $newid .= 'F';
    } elsif ($dir == 02) {
      $newid .= 'R';
    } else {
      print ERR "can't tell if $seqid is F or R:  '$dir'\n";
    }
  } elsif ($seqid =~ /^((BM|MF)1)-([A-H]\d{1,2})\.(X0\d)_.+/) {
    my $well = $3;
    my $plate = $2;
    my $int = $4;
    $plate =~ s/MF/M/;
    if ($well =~ /^([A-H])(\d)$/) {
      my $number = "0" . "$2";
      $well = "$1$number";
    }
    #    $newid .= "03$2$3";
    $newid .= "03$plate$well";
    if ($int) {
      $newid .= 'c';
    } else {
      print ERR "should $seqid be an internal read?\n";
    }
  } elsif ($seqid =~ /^\d{5}_\d{5}_(\d{2}I?)_0([12])_([A-H]\d{2})_\d{3}\.ab1$/) {
    $newid .= "04P$1$3";
    if ($2 == 1) {
      $newid .= "F";
    } elsif ($2 == 2) {
      $newid .= "R";
    } else {
      print ERR "can't tell if $seqid is F or R:  '$2'\n";
    }
#
#
# Parsing SAG name from full Diversa name
#
  } elsif ($seqid =~ /(.+)_(f\d{3})_{0,2}.+/i) {
    $newid = lc($2) . "$1";
  } elsif ($seqid =~ /(f\d{3}).*(GC\d+)[\._]/i) {
    $newid = lc($1) . "" . uc($2);
  } elsif ($seqid =~ /^(S0\dP\d{1,2}I?[A-H]\d{2})\.(\d{1,3})([A-Z])/) {
    $newid = "$1C$2$3";
#    print "newid:\t\t'$newid'\n\n";
  } elsif ($seqid =~ /^(S0\dP\d{1,2}I?[A-H]\d{2})\.(M13\w+?|T7)_/) {
    $newid = "$1$2";

  } elsif ($seqid =~ /^(S0\dP\d{1,2}I?[A-H]\d{2})\.X0([A-Z]+?)_/) {
    $newid = "$1c$2";
#    print "newid:\t\t'$newid'\n\n";

  } elsif ($seqid =~ /^(S0\dP\d{1,2}I?[A-H]\d{2})[^A-Za-z]/) {
    $newid = $1;
#    print "newid:\t\t'$newid'\n\n";
  } elsif ($seqid =~ /^(S0\dP)L?(\d{1,2}I?[A-H]\d{2})_0(\d)_[^A-Za-z]/) {
    $newid = "$1$2";
#    print "newid:  '$newid'\n";
    if ($3 == 1) {
      $newid .= "F";
    } elsif ($3 == 2) {
      $newid .= "R";
    } else {
      print ERR "can't tell if $seqid is F or R:  '$3'\n";
    }
  } else {
    print ERR "doesn't fit any regex:  '$seqid'\n";
  }

  if ($newid =~ /([A-H])(\d)(?=\D)/) {
    my $pre = $`;
    my $post = $';
    my $letter = $1;
    my $number = "0" . $2;
    $newid = "$pre$letter$number$post";
  }

  #  print OUT "returning '$newid' for '$seqid'\n";
  return $newid;

}

sub _singledigits {
  my $newid = shift;
    if ($newid =~ /([A-H])(\d)(?=\D)/) {
    my $pre = $`;
    my $post = $';
    my $letter = $1;
    my $number = "0" . $2;
    $newid = "$pre$letter$number$post";
  }
  return $newid;
}

sub singledigits {
  my $obj = shift;
  my $id = shift;
  my $newid = &_singledigits($id);
  return $newid;
}

sub batch1parse {
  my $obj = shift;
  my $line = shift;
  my $newline;

  $line =~ s/Plate/P/;

  if ($line =~ /^SAR11(P\d+)/i) {
    $newline = "$1";
    if ($line =~ /(T7)/i || $line =~ /(PZR02)/i) {
      $newline = "$newline" . "$1";
    } else {
      print ERR "line: '$_' failed T7/PZR02 test\n";
      return;
    }
    if ($line =~ /((_\w\d{1,2}){2}\.ab1)/) {
      $newline = "$newline" . "$1";
    } else {
      print ERR "line: '$_' failed test\n";
      return;
    }

    return $newline;


  } else {
    print ERR "line: '$line' failed test\n";
    return;
  }
}
 sub expidparse {
   my $obj = shift;
   my $filename = shift;
#   print ERR "filename: '$filename'\n";

   if ($filename =~ /^(S0\w+?)_expid(\d+?)_/) {
#     print ERR "filename: '$filename', template = '$1'. expid = '$2'\n";
     return ($1, $2);
   } else {
     return 0;
   }
}
