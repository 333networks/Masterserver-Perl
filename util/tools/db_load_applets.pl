#!/usr/bin/perl

################################################################################
## Load configuration variables to the database
##
## Normally the masterserver loads a number of masterserver applets via the 
## configuration file. This tool allows to load a number of masterserver applets
## directly into the database without restarting the masterserver.
##
## It is generally not necessary to run this script at all. Normally, the 
## masterserver performs the same action on startup.
## 
## Use with care!
##
## Note: set database name / user / password manually in the r_database.pl file!
################################################################################

use strict;
use warnings;
use DBI;

require "r_database.pl";
require "r_functions.pl";

# open db
our $dbh;

my @data = (
    {address => "utmaster.epicgames.com",   port => 28900, games => [qw|ut unreal|]},
    {address => "master.hypercoop.tk",      port => 28900, games => [qw|unreal|]},
    {address => "sof1master.megalag.org",   port => 28900, games => [qw|sofretail|]},
    {address => "master.deusexnetwork.com", port => 28900, games => [qw|deusex|]},
);

# iterate through all entries
for my $ms (@data) {
  
  # iterate through all games per entry
  for my $g (@{$ms->{games}}) {
    
    # resolve domain names
    my $applet_ip = host2ip($ms->{address});

    # check if all credentials are valid
    if ($applet_ip && 
        $ms->{port} && 
        $g) 
    {
      # add to database
      add_master_applet(
          ip        => $applet_ip,
          port      => $ms->{port},
          gamename  => $g,
        );
    } # else: insufficient info available
    else {
      print "fail: could not add master applet: ".
          ($applet_ip  || "ip")  .", ".
          ($ms->{port} || "0")   .", ".
          ($g          || "game").".";
    }
  }
}

# close db
$dbh->disconnect();
