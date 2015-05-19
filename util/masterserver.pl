#!/usr/bin/perl

package MasterServer;

use strict;
use warnings;
use Cwd 'abs_path';

our $ROOT;
BEGIN { ($ROOT = abs_path $0) =~ s{/util/masterserver\.pl$}{}; }
use lib $ROOT.'/lib';

use MasterServer;

our %S;
require "$ROOT/data/masterserver-config.pl";

#add %C from config.pl to OBJ
$MasterServer::OBJ->{$_}   = $S{$_} for (keys %S);

# load MasterServer core libs
MasterServer::load_recursive('MasterServer::Core', 
                             'MasterServer::UDP',
                             'MasterServer::TCP');

# Run the MasterServer process
MasterServer::run();
