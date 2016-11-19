#!/usr/bin/perl

################################################################################
## Manual use to insert one or a batch of IP-addresses/ports into the pending
## list, rather than manually adding them with psql.
## 
## Use with care!
################################################################################

use strict;
use warnings;
use Encode;
use DBI;
$|++;

our %S;
require "../../data/supportedgames.pl";
require "r_secure.pl";
require "r_database.pl";
require "r_functions.pl";
require "r_lists.pl";

# open db
our $dbh;

# import list of ip:ports
my @ips = qw(


);

$dbh->begin_work;
foreach my $l (@ips) {

  # break ip:port into $a (ip) and $q (query port)
  if ($l =~ /:/) {
    my ($a,$p) = valid_address($l);
    db_add_server(ip => $a, port => $p);
  }
}
$dbh->commit;

# close db
$dbh->disconnect();
