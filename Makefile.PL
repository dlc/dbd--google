use strict;

use DBI;
use DBI::DBD;
use ExtUtils::MakeMaker;

my %PREREQ_PM = (
    'Class::Struct'  => undef,
    'DBI'            => undef,
    'HTML::Entities' => undef,
    'Net::Google'    => undef,
    'Symbol'         => undef,
    'URI::Escape'    => undef,
);

my %clean = (
    FILES => '$(DISTVNAME).tar$(SUFFIX) *.xsi',
);

WriteMakefile(
    NAME        => "DBD::google",
    VERSION     => "0.05",
    PREREQ_PM   => \%PREREQ_PM,
    clean       => \%clean,
);

sub MY::postamble {
    return DBI::DBD::dbd_postamble(@_);
}
