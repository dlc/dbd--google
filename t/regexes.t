#!/usr/bin/perl
# vim: set ft=perl:

# This test is specifically for $FUNC_RE defined in DBD::google::parser.

use DBD::google::parser;
use Test::More;

my @tests = ("Foo::Bar",
            "Foo->Bar",
            "Foo::Bar::quux",
            "Foo::Bar->quux",
            "URI->new(URL)",
            "URI::new(URL)",
            "crap");
my $func_re = $DBD::google::parser::FUNC_RE;

plan tests => scalar @tests;

for my $re (@tests) {
    my @matches = $re =~ /($func_re)/;
    ok(scalar @matches, "$re =~ $func_re => '@matches'");
}
