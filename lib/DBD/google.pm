package DBD::google;

# ----------------------------------------------------------------------
# $Id: google.pm,v 1.1 2003/02/14 20:30:12 dlc Exp $
# ----------------------------------------------------------------------

use strict;
use vars qw($VERSION);
use vars qw($err $errstr $state $drh);

use DBI;
use DBD::google::dr;
use DBD::google::db;
use DBD::google::st;
use DBD::google::parser;
use Data::Dumper;

# ----------------------------------------------------------------------
# Standard DBI globals: $DBI::err, $DBI::errstr, etc
# ----------------------------------------------------------------------
$err     = 0;
$errstr  = "";
$state   = "";
$drh     = undef;
$VERSION = sprintf "%d.%02d", q$Revision: 1.1 $ =~ /(\d+)\.(\d+)/;

# ----------------------------------------------------------------------
# Creates a new driver handle, which will be a singleton.
# ----------------------------------------------------------------------
sub driver {
    unless ($drh) {
        my ($class, $attr) = @_;
        my %stuff = (
            'Name'          => 'google',
            'Version'       => $VERSION,
            'Err'           => \$err,
            'Errstr'        => \$errstr,
            'State'         => \$state,
            'Attribution'   => 'DBD::google - darren chamberlain <darren@cpan.org>',
            'AutoCommit'    => 1, # to avoid errors
        );

        $class = join "::", $class, "dr";

        $drh = DBI::_new_drh($class, \%stuff);
    }

    return $drh;
}


1;

__END__

Apparently, people like DBD::google:

    http://www.raelity.org/archives/2003/02/13#dbd_google
    http://blog.simon-cozens.org/blosxom.cgi/2003/Feb/13#6335

=head1 NAME

DBD::google - Treat Google as a datasource for DBI

=head1 SYNOPSIS

    use DBI;

    my $dbh = DBI->connect("dbi:google:", $KEY);
    my $sth = $dbh->prepare(qq[ SELECT title, URL FROM google WHERE q = "perl" ]);

    while (my $r = $sth->fetchrow_hashref) {
        ...

=head1 DESCRIPTION

DBD::google allows you to use Google as a datasource; google can be
queried using SQL I<SELECT> statements, and iterated over using
standard DBI conventions.

WARNING:  This is still alpha-quality software.  It works for me, but
that doesn't really mean anything.

=head1 WHY?

For general queries, what better source of information is there than
Google?

=head1 BASIC USAGE

For the most part, use C<DBD::google> like you use any other DBD,
except instead of going through the trouble of building and installing
(or buying!) database software, and employing a DBA to manage your
data, you can take advantage of Google's ability to do this for you.
Think of it as outsourcing your DBA, if you like.

=head2 Connection Information

The connection string should look like: C<dbi:google:>.  DBI requires
the trailing C<:>.

Your Google API key should be specified in the username portion (the
password is currently ignored; do whatever you want with it, but be
warned that I might put that field to use some day):

  my $dbh = DBI->connect("dbi:google:", "my key", undef, \%opts);

Alternatively, you can specify a filename in the user portion; the
first line of that file will be treated as the key:

  my $dbh =DBI->connect("dbi:google:", 
        File::Spec->catfile($ENV{HOME}, ".googlekey"))

In addition to the standard DBI options, the fourth argument to
connect can also include the following C<DBD::google> specific
options, the full details of each of which can be found in
L<Net::Google>:

=over 16

=item ie

Input Encoding.  String, e.g., "utf-8".

=item oe

Output Encoding.  String, e.g., "utf-8".

=item safe

Should safe mode be on.  Boolean.

=item filter

Should results be filtered.  Boolean.

=item lr

Something to do with language.  Arrayref.

=item debug

Should C<Net::Google> be put into debug mode or not.  Boolean.

=back

=head2 Supported SQL Syntax and Random Notes Thereon

The only supported SQL statement type is the I<SELECT> statement.
Since there is no real "table" involved, I've created a hypothetical
table, called I<google>; this table has one queryable field, I<q>
(just like the public web-based interface).  The available columns are
currently dictated by the data available from the underlying
transport, which is the Google SOAP API (see
L<http://www.google.com/apis|http://www.google.com/apis>), as
implemented by Aaron Straup Cope's C<Net::Google> module.

The basic SQL syntax supported looks like:

  SELECT @fields FROM google WHERE q = '$query'

There is also an optional LIMIT clause, the syntax of which is similar
to that of MySQL's LIMIT clause; it takes a pair: offset from 0,
number of results.  In practice, Google returns 10 results at a time
by default, so specifying a high LIMIT clause at the beginning might
make sense for many queries.

The list of available fields in the I<google> table includes:

=over 16

=item title

Returns the title of the result, as a string.

=item URL

Returns the URL of the result, as a (non-HTML encoded!) string.

=item snippet

Returns a snippet of the result.

=item cachedSize

Returns a string indicating the size of the cached version of the
document.

=item directoryTitle

Returns a string.

=item summary

Returns a summary of the result.

=item hostName

Returns the hostname of the result.

=item directoryCategory

Returns the directory category of the result.

=back

The column specifications can include aliases:

  SELECT directoryCategory as DC FROM google WHERE...

Finally, there are a few function that can be called on fields:

  SELECT title, html_encode(url) FROM google WHERE q = '$stuff'

The available functions include:

=over 16

=item uri_escape

This comes from the C<URI::Escape> module.

=item html_escape

This wraps around C<HTML::Entities::encode_entities>.

=item html_strip

This removes HTML from a field.  Some fields, such as title, summary,
and snippet, have the query terms highlighted with <b> tags by Google;
this function can be used to undo that damage.

=back

Functions an aliases can be combined:

  SELECT html_strip(snippet) as stripped_snippet FROM google...

Unsupported SQL includes ORDER BY clauses (Google does this, and
provides no interface to modify it), HAVING clauses, JOINs of
any type (there's only 1 "table" after all), sub-SELECTS (I can't even
imagine of what use they would be here), and, actually, anything not
explicitly mentioned above.

=head1 INSTALLATION

C<DBD::google> is pure perl, and has a few module requirements:

=over 16

=item Net::Google

This is the heart of the module; C<DBD::google> is basically a
DBI-compliant wrapper around C<Net::Google>.

=item HTML::Entities, URI::Escape

These two modules provide the uri_escape and html_escape functions.

=item DBI

Duh.

=back

To install:

  $ perl Makefile.PL
  $ make
  $ make test
  # make install
  $ echo 'I love your module!' | mail darren@cpan.org -s "DBD::google"

The last step is optional; the others are not.

=head1 EXAMPLES

Here is a complete script that takes a query from the command line and
formats the results nicely:

  #!/usr/bin/perl -w

  use strict;

  use DBI;
  use Text::TabularDisplay;

  my $query = "@ARGV" || "perl";

  # Set up SQL statement -- note the multiple lines
  my $sql = qq~
    SELECT
      title, URL, hostName
    FROM
      google
    WHERE
      q = "$query"
  ~;

  # DBI/DBD options:
  my %opts = ( RaiseError => 1,  # Standard DBI options
               PrintError => 0,
               lr => [ 'en' ],   # DBD::google options
               oe => "utf-8",
               ie => "utf-8",
             );

  # Get API key
  my $keyfile = glob "~/.googlekey";

  # Get database handle
  my $dbh = DBI->connect("dbi:google:", $keyfile, undef, \%opts);

  # Create Text::TabularDisplay instance, and set the columns
  my $table = Text::TabularDisplay->new;
  $table->columns("Title", "URL, "Hostname");

  # Do the query
  my $sth = $dbh->prepare($sql);
  $sth->execute;
  while (my @row = $sth->fetchrow_array) {
      $table->add(@row);
  }
  $sth->finish;

  print $table->render;

=head1 TODO

These are listed in the order in which I'd like to implement them.

=over 4

=item More tests!

I'm particularly unimpressed with the test suite for the SQL parser; I
think it is pretty pathetic.  It needs much better testing, with more
edge cases and more things I'm not expecting to find.

I've specifically avoided including tests that actually query Google,
because the free API keys have a daily limit to the number of requests
that will be answered.  My original test suite did a few dozen queries
each time it was run; if you run the test suite a few dozen times in a
day (easy to do if you are actively developing the software or
changing the feature set), your daily quota can be eaten up very
easily.

=item Integration of search metadata

There are several pieces of metadata that come back with searches;
access to the via the statement handle ($sth) would be nice:

  my $search_time = $sth->searchTime();
  my $total = $sth->estimatedTotalResultsNumber();

The metadata includes:

=over 4

=item o

documentFiltering

=item o

searchTime

=item o

estimatedTotalResultsNumber

=item o

estimateIsExact

=item o

searchTips

=item o

searchTime

=back

These are described in L<Net::Google::Response>.

=item Extensible functions

Unknown functions that look like Perl package::function names should
probably be treated as such, and AUTOLOADed:

  SELECT Foo::frob(title) FROM google WHERE q = "perl"

Would do, effectively:

  require Foo;
  $title = Foo::frob($title);

I'm slightly afraid of where this could lead, though:

  SELECT title, LWP::Simple::get(url) as WholeDamnThing
  FROM   google
  WHERE  q = "perl apache"
  LIMIT  0, 100

=item Elements return objects, instead of strings

It would be interesting for columns like URL and hostName to return
C<URI> and C<Net::hostent> objects, respectively.

On the other hand, this is definitely related to the previous item; the
parser could be extended to accept function names in method format:

  SELECT title, URI->new(URL), Net::hostent->new(hostName)
  FROM google WHERE q = "perl"

=item DESCRIBE statement on the C<google> table

It would be nice to provide a little introspection.

=back

=head1 CAVEATS, BUGS, IMPROVEMENTS, SUGGESTIONS, FOIBLES, ETC

I've only tested this using my free, 1000-uses-per-day API key, so I
don't know how well/if this software will work for those of you who
have purchased real licenses for unlimited usage.

Placeholders are currently unsupported.  They won't do any good, but
would be nice to have for consistency with other DBDs.  I'll get
around to it someday.

There are many Interesting Things that can be done with this module, I
think -- suggestions as to what those things might actually be are
very welcome.  Patches implementing said Interesting Things are also
welcome, of course.

More specifically, queries that the SQL parser chokes on would be very
useful, so I can refine the test suite (and the parser itself, of
course).

There are probably a few bugs, though I don't know of any.  Please
report them via the DBD::google queue at
E<lt>http://rt.cpan.org/E<gt>.

=head1 SEE ALSO 

L<DBI>, L<DBI::DBD>, L<Net::Google>, L<URI::Escape>, L<HTML::Entities>

=head1 AUTHOR

darren chamberlain E<lt>darren@cpan.orgE<gt>
