package DBD::google::parser;

# ----------------------------------------------------------------------
# $Id: parser.pm,v 1.2 2003/02/20 12:50:09 dlc Exp $
# ----------------------------------------------------------------------

use strict;
use vars qw($VERSION $FIELD_RE $FUNC_RE);

use Carp qw(carp);
use File::Spec::Functions qw(catfile);
use HTML::Entities qw(encode_entities);
use URI::Escape qw(uri_escape);

$VERSION = sprintf "%d.%02d", q$Revision: 1.2 $ =~ /(\d+)\.(\d+)/;

# XXX $FUNC_RE needs to catch methods as well as functions.  Currently
# catches things like Digest::MD5::md5_hex(title) but will miss methods
# like URI->new(URL).

$FIELD_RE = '[a-zA-Z][a-zA-Z0-9_]';
$FUNC_RE = qr/$FIELD_RE*(?:::$FIELD_RE*)*/;
#my $FUNC_RE = qr/$FIELD_RE*(?:::$FIELD_RE*)*(?:[-]>$FIELD_RE*)?/; # methods?
   $FIELD_RE = qr/$FIELD_RE*/;
my @default_columns = sort qw( title URL snippet summary
                               cachedSize directoryTitle
                               hostName directoryCategory
                             );
my %allowed_columns = map { lc($_) => 1 } @default_columns;

my %functions = (
    'default'       => sub { shift                  },
    'uri_escape'    => sub { uri_escape(shift)      },
    'html_escape'   => sub { encode_entities(shift) },
    'html_strip'    => \&striphtml,
);
$functions{''} = $functions{'default'};

# ----------------------------------------------------------------------
# parse($sql)
#
# Parses $sql into a data structure:
#   {
#       'columns' => [ qw( column names ) ],
#       'tables' => [ qw( table names  ) ],
#       'where' => "search terms",
#       'limit' => [ qw( offset limit ) ],
#   }
#
# ----------------------------------------------------------------------
sub parse {
    my ($class, $sql) = @_;
    my ($columns, $limit, @columns, @limit, $where, $parsed);

    $sql =~ /^\s*  select
              \s+  (.*?)
              \s+  from
              \s+  google
              (?:
                \s+  where
                \s+  q \s* = \s*
                    (['"]) (.*?) \2
              )?
              \s* 
              (?:
                limit
                \s+(.*?)
              )?
              \s*$
            /xism;

    $columns = $1 || "*";
    $where = $3 || "";
    $limit = $4 || "";

    # columns
    while ($columns =~ /\G

                        # Field name, including possible function
                        (?:
                          ($FUNC_RE\s*\([^)]+\))   # $1 => function
                        |
                          ($FIELD_RE)               # $2 => field name
                        | (\*)                      # $3 => '*' 
                        )

                        # possible alias
                        (?:
                            \s+
                            [aA][sS]
                            \s+
                            (['"]?)                   # $4 => possibly quoted
                              \s*
                              ($FIELD_RE)             # $5 => alias (no spaces allowed!)
                              \s*
                            \4?
                        )?
                        \s*
                        ,?
                        \s*
                       /xismg) {
        my $alias = $5 || "";
        my $function = $1 || "";

        if (defined $3) {
            push @columns,
                map { 
                    Column(name     => lc($_),
                           alias    => ($alias || $_),
                           original => $_
                    )
                } @default_columns;
        }
        elsif ($function) {
            my $original = $function;
            $original =~ /($FUNC_RE)\s*\((.*?)\)/;

            my ($f, $n) = ($1, $2);
            $n =~ s/(^\s*|\s*$)//g;

            unless ($allowed_columns{$n}) {
                carp "Unknown column name '$n'\n";
                next;
            }

            if (defined $functions{$f}) {
                # Common case:
                #
                #   SELECT html_strip(title) FROM google ...
                #
                # A pre-defined function.
                $f = $functions{$f};
            }
            elsif ($f =~ /::/) {
                # If a user specifies a function like:
                #
                #   SELECT Digest::MD5::md5_hex(title) FROM google ...
                #
                # This will pick that up.  $FUNC_RE only catches
                # things in the above format; there should be an
                # associated $METHOD_RE which will catch things
                # like:
                #
                #   SELECT URI->new(URL) FROM google ...
                #
                my ($package, $func) = $f =~ /(.*)::(.*)/;
                $package = catfile(split '::', $package);
                $package .= ".pm";
                print STDERR "\$package => '$package', \$func => '$func'";

                eval "use $package;";
                if ($@) {
                    carp "Can't require $package: $@";
                    $f = $functions{'default'}
                }
                else {
                    if (defined &{"$package\::$func"}) {
                        $f = \&{"$package\::$func"};
                    }
                    else {
                        $f = $functions{'default'};
                    }
                }
            }
            else {
                # No function:
                #
                #   SELECT title FROM google ...
                $f = $functions{'default'};
            }

            push @columns,
                Column(function => $f,
                       name     => lc($n),
                       alias    => ($alias || $original),
                       original => $original
                );
        }
        elsif (defined $2) {
            my $name = lc($2);
            if ($allowed_columns{$name}) {
                push @columns,
                    Column(name     => $name,
                           alias    => ($alias || $2),
                           original => $2
                    );
            } else {
                carp "Unknown column name '$2'\n";
                next;
            }
        }
    }
    

    # LIMIT is in the form "offset, limit", like mysql
    @limit = split /,\s*/, $limit, 2;
    if (@limit == 0) {
        @limit = (0, 10);
    }
    elsif (@limit == 1) {
        @limit = (0, $limit[0])
    }

    $parsed = DBD::google::Parsed::SQL->new;
    $parsed->columns(\@columns);
    $parsed->limit(\@limit);
    $parsed->where($where);

    return $parsed;
}

# ----------------------------------------------------------------------
# Column(%args)
#
# Python-like Column() constructor.  Simpler than using the
# full class name all over the place.
# ----------------------------------------------------------------------
sub Column {
    return DBD::google::Parsed::Column->new->init(
        function => $functions{'default'},
        @_
    );
}

# ----------------------------------------------------------------------
# striphtml($text)
#
# A function for stripping HTML.  Very naive; it it becomes an
# issue, I'll include TCHRIST's striphtml.
# ----------------------------------------------------------------------
sub striphtml {
    my $text = shift;
    $text =~ s#</?[^>]*>##smg;
    return $text;
}

# ----------------------------------------------------------------------
# This internal package defines a cute little class to encapsulate
# a column.
# ----------------------------------------------------------------------
package DBD::google::Parsed::Column;

use Class::Struct;

struct qw( original $
           name     $
           alias    $
           function $
         );

sub init {
    my $self = shift;

    while (@_) {
        my ($n, $v) = splice @_, 0, 2;
        if (my $sub = $self->can($n)) {
            $self->$sub($v);
        }
    }

    return $self;
}

# ----------------------------------------------------------------------
# This internal package represents a parsed SQL statement.
# ----------------------------------------------------------------------
package DBD::google::Parsed::SQL;

use Class::Struct;

struct qw( columns $
           where   $
           limit   $
         );

sub end {
    my $self = shift;
    return $self->start + $self->limit->[1];
}

sub start {
    return shift->limit->[0];
}

1;
