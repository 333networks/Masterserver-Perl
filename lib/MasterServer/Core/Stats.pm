
package MasterServer::Core::Stats;

use strict;
use warnings;
use AnyEvent::IO;
use Exporter 'import';

our @EXPORT = qw| update_stats |;

################################################################################
# Update statistics on servers and update the games table with those values
################################################################################
sub update_stats {
  my $self = shift;

  # get all gamenames where there is one or more servers online and update the 
  # stats per gamename.
  my $games = $self->get_gamelist_stats();

  # iterate through available stats
  for my $e (@{$games}) {
    
    # extract gamename, number of direct uplinks and total servers
    my %opt = ();
       $opt{gamename}   = $e->[0];
       $opt{num_uplink} = $e->[1];
       $opt{num_total}  = $e->[2];

    # write to DB
    $self->write_stat(%opt);
  }

  #done
  $self->log("stat", "Updated all game statistics.");
  
}

1;
