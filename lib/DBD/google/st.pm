package DBD::google::st;

# ----------------------------------------------------------------------
# $Id: st.pm,v 1.1 2003/02/14 20:30:12 dlc Exp $
# ----------------------------------------------------------------------
# DBD::google::st - Statement handle
# ----------------------------------------------------------------------

use strict;
use base qw(DBD::_::st);
use vars qw($VERSION $imp_data_size);

use DBI;
use DBD::google::parser;

$VERSION = sprintf "%d.%02d", q$Revision: 1.1 $ =~ /(\d+)\.(\d+)/;
$imp_data_size = 0;

# ----------------------------------------------------------------------
# execute()
#
# I have no intention of supporting bind_params, BTW.
# ----------------------------------------------------------------------
sub execute {
    my $sth = shift;
    my (@data, @columns);
    my ($google, $search, $results, $result);

    # The Net::Google::Search instance
    $search = $sth->{'GoogleSearch'};

    # The names of the columns in which we are interested
    @columns = @{ $sth->{'Columns'} };

    # This is where fetchrow_hashref etc get their names from
    $sth->{'NAME'} = [ map { $_->alias } @columns ];

    # This executes the search
    $results = $search->results;
    for $result (@$results) {
        my (@this, $column);

        for $column (@columns) {
            my ($name, $method, $value, $function);
            $name = lc $column->name;

            # These are in the same order as described
            # in Net::Google::Response
            if ($name eq 'title') {
                $method = "title";
            } elsif ($name eq 'url') {
                $method = "URL";
            } elsif ($name eq 'snippet') {
                $method = "snippet";
            } elsif ($name eq 'cachedsize') {
                $method = 'cachedSize';
            } elsif ($name eq 'directorytitle') {
                $method = 'directoryTitle';
            } elsif ($name eq 'summary') {
                $method = 'summary';
            } elsif ($name eq 'hostname') {
                $method = 'hostName';
            } elsif ($name eq 'directorycategory') {
                $method = 'directoryCategory';
            }

            $value = $method ? $result->$method() : "";

            $function = $column->function;
            eval { $value = &$function($value); };
            push @this, ($@ or $value);
        }

        push @data, \@this;
    }
    # Need to do stuff with total rows, search time, and such,
    # all from $search

    $sth->{'driver_data'} = \@data;
    $sth->{'driver_rows'} =  @data;
    $sth->STORE('NUM_OF_FIELDS', scalar @columns);

    return scalar @data || 'E0E';
}

sub fetchrow_arrayref {
    my $sth = shift;
    my ($data, $row);

    $data = $sth->FETCH('driver_data');

    $row = shift @$data
        or return;

    return $sth->_set_fbav($row);
}
*fetch = *fetch = \&fetchrow_arrayref;

sub rows {
    my $sth = shift;
    return $sth->FETCH('driver_rows');
}

# Alas! This currently doesn't work.
sub totalrows {
    my $sth = shift;
    return $sth->FETCH('driver_totalrows');
}

# Returns available tables
sub table_info { return "google" }

1;

__END__
