#!/usr/bin/perl

use strict;
use File::Spec::Functions qw(catfile);

use DBI;
use Data::Dumper;

my $dbh = DBI->connect("dbi:google:", catfile($ENV{HOME}, ".googlerc"))
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
