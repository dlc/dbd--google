#!/usr/bin/perl
# vim: set ft=perl:

use DBI;
use Test::More;

plan tests => 5;

use_ok("DBD::google");
use_ok("DBD::google::db");
use_ok("DBD::google::dr");
use_ok("DBD::google::parser");
use_ok("DBD::google::st");
