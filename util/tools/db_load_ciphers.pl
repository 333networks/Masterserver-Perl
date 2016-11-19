#!/usr/bin/perl

################################################################################
## Supported Games list ciphers
## Clear the Supported Games table and insert the list of supported games AND
## their ciphers / default ports / descriptions included from the 
## data/supportedgames.pl file.
## 
## Only config files after 5 October 2015 work with this script.
##
## It is generally not necessary to run this script at all. Normally, the 
## masterserver performs the same action on startup. With this script it is 
## possible to add new game/cipher pairs or reload the game descriptions
## without having to restart the masterserver.
## Doing so while the masterserver is running MAY lead to missed queries or
## failed secure/validate queries in your logs/output. This is undesirable,
## but always better than being offline while restarting the masterserver.
## 
## Use with care!
##
##
## Note: set database name / user / password manually in the code below.
################################################################################

use strict;
use warnings;
use DBI;
use Data::Dumper 'Dumper';

use Cwd 'abs_path';

our $ROOT;
BEGIN { ($ROOT = abs_path $0) =~ s{/util/ciphers\.pl$}{}; }
use lib $ROOT.'/lib';

use MasterServer;

our %S;
require "$ROOT/data/supportedgames.pl";


# open db connection
my $dbh = DBI->connect('dbi:Pg:dbname=masterserver', 'user', 'password')
        or die "Cannot connect: $DBI::errstr\n";

# intro
print "Deleting old entries... ";

# check existing entries
my $m = $dbh->do('DELETE FROM games');
print "Deleted $m lines.\n";

# announce
print "Inserting new entries ... (this may take a while) ... ";
my $g = $S{game};

$dbh->begin_work;
for (keys %{$g}) {
  
  $dbh->do("INSERT INTO games (gamename, cipher, description, default_qport) VALUES(?, ?, ?, ?)", undef, 
    lc $_, $g->{$_}->{key}, $g->{$_}->{label}, $g->{$_}->{port} || 0) ;
}
$dbh->commit;

# verify
print "Done! ";
my $n = $dbh->selectall_arrayref('SELECT COUNT(*) FROM games as count');
print "$m game entries found and added. \n";



# EOF
