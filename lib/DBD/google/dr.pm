package DBD::google::dr;

# ----------------------------------------------------------------------
# $Id: dr.pm,v 1.1 2003/02/14 20:30:12 dlc Exp $
# ----------------------------------------------------------------------
# This is the driver implementation.
# DBI->connect defers to this class.
# ----------------------------------------------------------------------

use strict;
use base qw(DBD::_::dr);
use vars qw($VERSION $imp_data_size);

use DBI;
use Net::Google;
use Symbol ();

$VERSION = sprintf "%d.%02d", q$Revision: 1.1 $ =~ /(\d+)\.(\d+)/;
$imp_data_size = 0;

# ----------------------------------------------------------------------
# connect($dsn, $user, $pass, \%attrs);
# 
# Method called when an external process does:
# 
#   my %opts = ("filter" => 0, "debug" => 1);
#   my $dbh = DBI->connect("dbi:google:", $KEY, undef, \%opts);
#
# Username must be the google API key, password is ignored, and can be
# anything, and the options hash is passed to Net::Google.
# ----------------------------------------------------------------------
sub connect {
    my ($drh, $dbname, $user, $pass, $attr) = @_;
    my ($dbh, $google, %google_opts);

    die "No Google API key specified\n" unless defined $user;
    if (-e $user) {
        my $fh = Symbol::gensym;
        open $fh, $user or die "Can't open $user for reading: $!";
        chomp($user = <$fh>);
        close $fh or die "Can't close $user: $!";
    }

    if (length $user != 32) {
        warn "'$user' doesn't look like a Google key to me; using it anyway...";
    }

    $dbh = DBI::_new_dbh($drh, {
        'Name'          => $dbname,
        'USER'          => $user,
        'CURRENT_USER'  => $user,
        'Password'      => $pass,
    });

    # Get options from %attr.  These will be passed 
    # to $google->search.
    for my $google_opt (qw(ie oe safe filter lr debug)) {
        if (defined $attr->{ $google_opt }) {
            $google_opts{ $google_opt } =
                delete $attr->{ $google_opt };
        }
    }

    # Create a Net::Google instance
    $google = Net::Google->new(key => $user,
                               debug => delete $attr->{'debug'});

    $dbh->STORE('driver_google' => $google);
    $dbh->STORE('driver_google_opts' => \%google_opts);

    return $dbh;
}

sub disconnect_all {
    return 1;   # Nothing to do
}

sub data_sources { return "google" }

1;

__END__
