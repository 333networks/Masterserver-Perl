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
  {ip => "master.hypercoop.tk",     port => 28900, games => [qw|ut unreal|]},
  {ip => "utmaster.epicgames.com",  port => 28900, games => [qw|ut unreal|]},
  {ip => "master.deusexnetwork.com",port => 28900, games => [qw|deusex|]},
);

for my $ms (@data) {
  sleep 1;
  
  print "\n\n$ms->{ip}, $ms->{port}\n";
  query_master($ms);
}

# close db
$dbh->disconnect();
