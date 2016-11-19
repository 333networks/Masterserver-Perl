#!/usr/bin/perl

################################################################################
## Manually query other masterservers/applets and save list into the pending
## 
## Use with care!
################################################################################

use strict;
use warnings;
use Encode;
use AnyEvent;
use AnyEvent::Handle;
use Data::Dumper 'Dumper';
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

my @data = (
 {ip => "dev.333networks.com", port => 28905, games => [qw|ut unreal deusex rune|]},
);

for my $ms (@data) {
  sleep 1;
  query_master($ms);
}

# close db
$dbh->disconnect();
