#!/usr/bin/perl
# vim: set ft=perl:

use Data::Dumper;
use DBD::google::parser;
use Test::More;

sub p { DBD::google::parser->parse(@_) }

plan tests => 28;
my $parsed;

ok($parsed = p("SELECT * FROM google"), "Parsed statement");
is(ref($parsed->columns), 'ARRAY', "\$parsed->columns is an array");

is(ref($parsed->limit), 'ARRAY', "\$parsed->limit is an array");
is($parsed->limit->[0], 0, "\$limit[0] => 0");
is($parsed->limit->[1], 10, "\$limit[1] => 10");

ok(!$parsed->where, "\$parsed->where is not defined");
is(scalar @{ $parsed->columns }, 8, "Correct number of columns");

ok($parsed = p('
    SELECT
      title
    FROM
      google
    WHERE
      q = "perl"
    LIMIT
      40, 80'), "Parsed statement");

is($parsed->columns->[0]->name, "title", "Column->name OK");
is($parsed->columns->[0]->alias, "title", "Column->alias OK");
is($parsed->columns->[0]->original, "title", "Column->original OK");
is(ref($parsed->columns->[0]->function), "CODE", "Column->function OK");
is($parsed->where, "perl", "Multi-line SQL statement parses correctly");
is($parsed->limit->[0], 40, "\$limit[0] => 40");
is($parsed->limit->[1], 80, "\$limit[1] => 80");

ok($parsed = p("SELECT title, url, summary FROM google WHERE q = 'foo'"),
    "Parsed statement");
is(scalar @{ $parsed->columns }, 3, "Correct number of columns");
is($parsed->columns->[0]->alias, 'title', 'No alias correctly defined');
is($parsed->columns->[0]->name, 'title', 'Title parsed correctly');
is($parsed->where, 'foo', "Where => 'foo'");

ok($parsed = p("SELECT url, snippet FROM google WHERE q = 'bar'"),
    "Parsed statement");
is(scalar @{ $parsed->columns }, 2, "Correct number of columns");

ok($parsed = p("select html_strip(summary) from google where q = 'perl'"),
    "Parsed statement");
is(ref($parsed->columns->[0]->function), 'CODE', "striphtml => CODE ref");
is($parsed->columns->[0]->function->("<b>hello</b>"), "hello", "striphtml works ok");

ok($parsed = p("select * from google limit 5"), "Parsed statement");
is($parsed->limit->[0], 0, "\$limit[0] => 0");
is($parsed->limit->[1], 5, "\$limit[1] => 5");
