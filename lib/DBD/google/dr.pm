package DBD::google::dr;

# ----------------------------------------------------------------------
# $Id: dr.pm,v 1.3 2003/03/11 13:59:24 dlc Exp $
# ----------------------------------------------------------------------
# This is the driver implementation.
# DBI->connect defers to this class.
# ----------------------------------------------------------------------

use strict;
use base qw(DBD::_::dr);
use vars qw($VERSION $imp_data_size);

use Carp qw(carp croak);
use DBI;
use Net::Google;
use Symbol qw(gensym);

$VERSION = sprintf "%d.%02d", q$Revision: 1.3 $ =~ /(\d+)\.(\d+)/;
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

    croak "No Google API key specified\n" unless defined $user;
    if (-e $user) {
        my $fh = gensym;
        open $fh, $user or die "Can't open $user for reading: $!";
        chomp($user = <$fh>);
        close $fh or die "Can't close $user: $!";
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
    $google = Net::Google->new(key   => $user,
                               debug => $google_opts{'debug'} || 0);

    $dbh->STORE('driver_google' => $google);
    $dbh->STORE('driver_google_opts' => \%google_opts);

    return $dbh;
}

sub disconnect_all { 1 }

sub data_sources { return "google" }

1;

__END__
