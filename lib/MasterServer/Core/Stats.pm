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

  # find all gamenames with 1 server or more
  my $in_slist = $self->get_gamenames();
  my $in_glist = $self->get_listedstats();

  # list of unique gamenames
  my %games; $games{$_->[0]} = 1 for (@{$in_slist}, @{$in_glist});
  
  # update stats per gamename
  for my $gamename (sort keys %games) {
  
    # get statistics per game
    my $num = $self->get_gamestats($gamename)->[0];
    
    # update in db
    my $u = $self->write_stat(
      gamename    => $gamename,
      num_uplink  => $num->{num_uplink} || 0,
      num_total   => $num->{num_total}  || 0,
    );
    
    # log stats too
    if ( int($u) > 0) {
      # log the statistics
      $self->log("update", "updated stats ($num->{num_uplink}/$num->{num_total}) for $gamename");
    } else {
      # report unable to update stats
      $self->log("error", "can not update stats for $gamename");
    }
  }
  
  # notify
  $self->log("stat", "updated all game statistics");
}

1;
