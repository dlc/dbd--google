use strict;

use DBI;
use DBI::DBD;
use ExtUtils::MakeMaker;

my %PREREQ_PM = (
    'Class::Struct'  => 0,
    'DBI'            => 0,
    'HTML::Entities' => 0,
    'Net::Google'    => 0,
    'Symbol'         => 0,
    'URI::Escape'    => 0,
);

my %clean = (
    FILES => '$(DISTVNAME).tar$(SUFFIX) *.xsi',
);

WriteMakefile(
    NAME        => "DBD::google",
    VERSION     => "0.06",
    PREREQ_PM   => \%PREREQ_PM,
    clean       => \%clean,
);

sub MY::postamble {
    return DBI::DBD::dbd_postamble(@_);
}
