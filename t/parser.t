#!/usr/bin/perl
# vim: set ft=perl:

# The format of all of these tests is highly dependant on the internals
# of SQL::Parser, and are therefore subject to change.  If these tests
# suddenly stop passing, then blame Jeff Zucker.

use DBD::google::parser;
use Test::More;

plan tests => 34;

# This creates a new parser for each invocation; can parsers be reused?
sub p {
    my $parser = DBD::google::parser->new;
    $parser->parse($_[0]);
    return $parser->structure;
}

my $parsed;

# ++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
# Basic test
# ++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
ok($parsed = p('SELECT * FROM google'),
    "Parsed statement");
is(ref($parsed->{'table_names'}),
    'ARRAY',
    "\$parsed->table_names is an array");
is(scalar @{ $parsed->{'table_names'} },
    1,
    "scalar \@\$parsed->table_names == 1");
ok(!$parsed->{'where_clause'},
    "\$parsed->where is not defined");
is(scalar @{ $parsed->{'column_names'} },
    8,
    "Correct number of columns");

# ++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
# Basic test with limit
# ++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
ok($parsed = p('SELECT * FROM google LIMIT 0, 10'),
    "Parsed statement");

is(scalar @{ $parsed->{'column_names'} },
    8,
    "Correct number of columns");
is($parsed->{'limit_clause'}->{'limit'},
    10,
    "\$parsed->limit_clause->limit => 10");
is($parsed->{'limit_clause'}->{'offset'},
    0,
    "\$parsed->limit_clause->offset => 0");

# ++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
# More extensive, multiline statement.  (The multiline aspect was more
# important in the pre-SQL::Parser days; now it's a historical
# artifact.)
# ++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
ok($parsed = p('
    SELECT
      title
    FROM
      google
    WHERE
      q = "perl"
    LIMIT
      40, 80'), "Parsed statement");

is(ref($parsed->{'column_names'}),
    "ARRAY",
    "\$parsed->column_names => array");
is(scalar(@{ $parsed->{'column_names'} }),
    1,
    "scalar \@\$parsed->column_names == 1");
is($parsed->{'column_names'}->[0],
    "TITLE",
    "\$parsed->column_names = ('title')");
is($parsed->{'column_aliases'}->{'TITLE'},
    "title",
    "\$parsed->column_aliases->title OK");
is(ref($parsed->{'column_functions'}->{'TITLE'}),
    "CODE",
    "\$parsed->column_functions->title OK");
is($parsed->{'where_clause'}->{'arg2'}->{'value'},
    '"perl"',   # Note quotes!
    "Multi-line SQL statement parses correctly");
is($parsed->{'limit_clause'}->{'offset'},
    40,
    "\$parsed->limit_clause->offset => 40");
is($parsed->{'limit_clause'}->{'limit'},
    80,
    "\$parsed->limit_clause->limit => 80");

# ++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
ok($parsed = p('SELECT title, url, summary FROM google WHERE q = "foo"'),
    "Parsed statement");
is(scalar @{ $parsed->{'column_names'} },
    3,
    "Correct number of columns");
is($parsed->{'column_aliases'}->{'TITLE'},
    'title',
    'No alias correctly defined');
is($parsed->{'where_clause'}->{'arg1'}->{'value'},
    'Q',
    "WHERE q = 'foo'");
is($parsed->{'where_clause'}->{'arg2'}->{'value'},
    '"foo"',
    "WHERE q = 'foo'");

# ++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
ok($parsed = p("SELECT url, snippet FROM google WHERE q = 'bar'"),
    "Parsed statement");
is(scalar @{ $parsed->{'column_names'} },
    2,
    "Correct number of columns");

# ++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
ok($parsed = p("select * from google limit 5"),
    "Parsed statement");
is($parsed->{'limit_clause'}->{'offset'},
    undef,
    "\$parsed->limit_clause->offset => undef");
is($parsed->{'limit_clause'}->{'limit'},
    5,
    "\$parsed->limit_clause->limit => 5");

# ++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
# Function tests
#
# Builtin and random functions
# ++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
ok($parsed = p("select html_strip(summary) from google where q = 'perl'"),
    "Parsed statement");
my $c = $parsed->{'column_functions'}->{'SUMMARY'};
is(ref($c),
    'CODE',
    "striphtml => CODE ref");
is($c->("<b>hello</b>"),
    "hello",
    "striphtml works ok");

SKIP: {
    skip "Can't load Digest::MD5" => 3
        unless eval { require Digest::MD5 };

    my $md5 = "c822c1b63853ed273b89687ac505f9fa";
    ok($parsed = p('select Digest::MD5::md5_hex(title) from google'),
        "Parsed statement");
    is(ref($parsed->{'column_functions'}->{'TITLE'}),
        'CODE',
        "Random function (Digest::MD5::md5_hex) OK");
    is($parsed->{'column_functions'}->{'TITLE'}->("google"),
        $md5,
        "md5('google') -> '$md5'");
}

#TODO: {
#    local $todo = "Methods not yet functional";
#    ok(eval { $parsed = p('SELECT URI->new(URL) from google where q = "apache"') },
#        "Parsed statement");
#    is(ref($parsed->{'column_functions'}->{'URL'}),
#        "CODE",
#        "Random method (URI->new) OK");
#    my $u;
#    eval { $u = $parsed->{'column_functions'}->{'URL'}->('//www.google.com/search', 'http') };
#    isa_ok($u, "URI::http");
#}
