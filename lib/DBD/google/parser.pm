package DBD::google::parser;

# ----------------------------------------------------------------------
# $Id: parser.pm,v 1.4 2003/03/18 15:42:29 dlc Exp $
# ----------------------------------------------------------------------

# This package needs to subclass SQL::Parser, in order that the
# functions defined can be used.  WIth SQL::Parser 1.005, the
# SELECT_CLAUSE method needs to be overridden.
#
# Jeff Zucker tells me that SQL::Parser 1.006 is coming out
# soon, and that it will support more functions and such.  There
# might need to be some logic in here to ensure that an incompatible
# version of SQL::Parser is not being used.

use strict;
use base qw(SQL::Parser);
use vars qw($VERSION $FIELD_RE $FUNC_RE);

use Carp qw(carp);
use File::Spec::Functions qw(catfile);
use HTML::Entities qw(encode_entities);
use SQL::Parser;
use URI::Escape qw(uri_escape);

$VERSION = sprintf "%d.%02d", q$Revision: 1.4 $ =~ /(\d+)\.(\d+)/;

# XXX $FUNC_RE needs to catch methods as well as functions.  Currently
# catches things like Digest::MD5::md5_hex(title) but will miss methods
# like URI->new(URL).

$FIELD_RE = '[a-zA-Z][a-zA-Z0-9_]';
#$FUNC_RE = qr/$FIELD_RE*(?:::$FIELD_RE*)*/;
$FUNC_RE = qr/$FIELD_RE*(?:::$FIELD_RE*)*(?:[-]>$FIELD_RE*)?/; # methods?
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
    'count'         => sub { },
    'html_strip'    => \&striphtml,
);
$functions{''} = $functions{'default'};

# ----------------------------------------------------------------------
# new(@stuff)
# 
# Override SQL::Parser's new method, but only so that default values
# can be used.
# ----------------------------------------------------------------------
sub new { return shift->SUPER::new("Google", @_) }

# ----------------------------------------------------------------------
# SELECT_CLAUSE($sql)
#
# Parses the SELECT portion of $sql, which contains only the pieces 
# between SELECT and WHERE.  Understands the following syntax:
#
#   field
#
#   field AS alias
#
#   field AS "alias"
#
#   function(field)
#
#   function(field) AS alias
#
#   function(field) AS "alias"
#
#   package::function(field)
#
#   package::function(field) AS alias
#
#   package::function(field) AS "alias"
#
# Will (heopfully) soon understand:
#
#   package->method(field)
#
#   package->method(field) AS alias
#
#   package->method(field) AS "alias"
#
# Currently fails on:
#
#   function(field, args)
#
# ----------------------------------------------------------------------
sub SELECT_CLAUSE {
    my ($self, $sql) = @_;
    #warn "Got: \$sql => '$sql'\n";
    my ($columns, $limit, @columns, @limit, $where, $parsed);

    # Internal data structures, given shorter names
    my $column_names =  $self->{'struct'}->{'column_names'}     = [ ];
    my $ORG_NAME     =  $self->{'struct'}->{'ORG_NAME'}         = { };
    my $functions    =  $self->{'struct'}->{'column_functions'} = { };
    my $aliases      =  $self->{'struct'}->{'column_aliases'}   = { };
    my $errstr       = \$self->{'struct'}->{'errstr'};

    # columns
    while ($sql =~ /\G

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

        #warn "\$function => '$function'\n\$alias => '$alias'\n";

        if (defined $3) {
            # SELECT * -> expanded to all column names
            my $df = $functions{'default'};
            push  @$column_names,                    @default_columns;
            %$ORG_NAME     = map { (uc($_) => $_) }  @default_columns;
            %$functions    = map { (uc($_) => $df) } @default_columns;
            %$aliases      = map { (uc($_) => $_) }  @default_columns;
        }
        elsif ($function) {
            # SELECT foo(bar)
            my $original = $function;
            $original =~ /($FUNC_RE)\s*\((.*?)\)/;

            # XXX $n here might contains arguments; needs to be
            # passed to String::Shellquote to extract tokens
            my ($f, $n) = ($1, $2);
            $n =~ s/(^\s*|\s*$)//g;
            $f = "" unless defined $f;

            unless ($allowed_columns{$n}) {
                $$errstr = "Unknown column name '$n'";
                return;
            }

            # Possible cases include:
            #   1. No function defined
            #   2. Function defined that we know about
            #   3. Function defined we don't know about
            #       3a. Function/method to be loaded
            #       3b. Error
            if ($f) {
                if (defined $functions{$f}) {
                    # Common case:
                    #
                    #   SELECT html_strip(title) FROM google ...
                    #
                    # A pre-defined function.
                    $f = $functions{$f};
                }
                else {
                    # If a user specifies a function like:
                    #
                    #   SELECT Digest::MD5::md5_hex(title) FROM google ...
                    #
                    # or:
                    #
                    #   SELECT URI->new(URL) FROM google ...
                    #
                    if (my ($package, $type, $func) = $f =~ /(.*)(::|[-]>)(.*)/) {

                        eval "use $package;";
                        if ($@) {
                            $$errstr = $@;
                            return;
                        }
                        else {
                            if ($type eq '::') {
                                if (defined &{"$package\::$func"}) {
                                    $f = \&{"$package\::$func"};
                                } else {
                                    $$errstr = "Can't load $package\::$func";
                                }
                            }
                            elsif ($type eq '->') {
                                $f = sub { $package->$func(@_) };
                            }
                            else {
                                $f = $functions{'default'};
                            }
                        }
                    }
                    else {
                        # Function that matches $FUNC_RE but doesn't contain
                        # :: or ->; might be a built-in, such as uc or lc.
                        # This won't work; what will?
                        #
                        # $f = sub { $f(@_) };
                    }
                }
            }
            else {
                # No function:
                #
                #   SELECT title FROM google ...
                $f = $functions{'default'};
            }

            push @$column_names, $n;
            $ORG_NAME->{  uc($n) } = $n;
            $functions->{ uc($n) } = $f;
            $aliases->{   uc($n) } = $alias ? $alias : $n;
        }
        elsif (defined $2) {
            my $n = lc($2);
            if ($allowed_columns{$n}) {
                push @$column_names, $n;
                $ORG_NAME->{  uc($n) } = $n;
                $functions->{ uc($n) } = $functions{'default'};
                $aliases->{   uc($n) } = $alias ? $alias : $n;
            } else {
                $$errstr = "Unknown column name '$2'";
                return;
            }
        }
    }

    1;
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

1;

__END__

NOTES

Tim Buunce suggested count(*) as a way to get the total number of search results.

Data structure of SQL::Parser instance after parsing looks like:

                 'struct' => {
                               'org_table_names' => [
                                                      'google'
                                                    ],
                               'column_names' => [
                                                   '*'
                                                 ],
                               'table_alias' => {},
                               'command' => 'SELECT',
                               'table_names' => [
                                                  'GOOGLE'
                                                ],
                               'org_col_names' => [
                                                    '*'
                                                  ]
                             },

