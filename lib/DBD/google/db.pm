package DBD::google::db;

# ----------------------------------------------------------------------
# $Id: db.pm,v 1.1 2003/02/14 20:30:12 dlc Exp $
# ----------------------------------------------------------------------
# The database handle (dbh)
# ----------------------------------------------------------------------

use strict;
use base qw(DBD::_::db);
use vars qw($VERSION $imp_data_size);

use DBI;

$VERSION = sprintf "%d.%02d", q$Revision: 1.1 $ =~ /(\d+)\.(\d+)/;
$imp_data_size = 0;

sub prepare {
    my ($dbh, $statement, @attr) = @_;
    my ($sth, $parsed, $google, $search, $search_opts);

    # Parse the SQL statement
    $parsed = DBD::google::parser->parse($statement);

    # Get the google instance and %attr
    $google = $dbh->FETCH('driver_google');
    $search_opts = $dbh->FETCH('driver_google_opts');

    # Create the search object
    $search = $google->search(%$search_opts);
    $search->query($parsed->where);
    $search->starts_at($parsed->start);
    $search->max_results($parsed->end);

    $sth = DBI::_new_sth($dbh, {
        'Statement' => $statement,
        'Columns' => $parsed->columns,
        'GoogleSearch' => $search,
    });

    # ?
    $sth->STORE('driver_params', [ ]);

    return $sth;
}

# ----------------------------------------------------------------------
# These next four methods are taken directly from DBI::DBD
# ----------------------------------------------------------------------
sub STORE {
    my ($dbh, $attr, $val) = @_;
    if ($attr eq 'AutoCommit') {
        return 1;
    }

    if ($attr =~ m/^driver_/) {
        $dbh->{$attr} = $val;
        return 1;
    }

    $dbh->SUPER::STORE($attr, $val);
}

sub FETCH {
    my ($dbh, $attr) = @_;

    if ($attr eq 'AutoCommit') {
        return 1
    }
    elsif ($attr =~ m/^driver_/) {
        return $dbh->{$attr};
    }

    $dbh->SUPER::FETCH($attr);
}

sub commit {
    my $dbh = shift;

    warn "Commit ineffective while AutoCommit is on"
        if $dbh->FETCH('Warn');

    1;
}

sub rollback {
    my $dbh = shift;

    warn "Rollback ineffective while AutoCommit is on"
        if $dbh->FETCH('Warn');

    0;
}

1;
__END__
