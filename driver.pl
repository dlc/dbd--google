#!/usr/bin/perl

use strict;
use File::Slurp qw(read_file);
use File::Spec::Functions qw(catfile);

my $KEY = read_file(catfile($ENV{HOME}, ".googlerc"));
chomp $KEY;

use DBI;
use Data::Dumper;

my $dbh = DBI->connect("dbi:google:", $KEY)
    or die $DBI::err;

my $sql = "
    SELECT
      title, url
    FROM
      google
    WHERE
      q = 'perl'";

my $sth  = $dbh->prepare($sql);
my $rc = $sth->execute;
while (my $r = $sth->fetchrow_hashref) {
    print Dumper($r);
}
$sth->finish;

$dbh->disconnect;
