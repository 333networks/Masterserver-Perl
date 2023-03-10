package MasterServer::Util::KFStatsWatcher;

use strict;
use warnings;
use AnyEvent::IO;
use Exporter 'import';
our @EXPORT = qw| read_kfstats |;

################################################################################
## Read Killing Floor Statistics from the file.
################################################################################
sub read_kfstats {
  my $self = shift;

  # open file and read content
  return aio_load($self->{kfstats_file}, 
    sub {
      my $f = shift;
      my $block = "";
              
      # read player stats
      for my $l (split /^/, $f) {
        # add data to "player" block
        $block .= $l;
        
        # if block contains last item GamesLost, process block
        if ($l =~ m/^(GamesLost=)/i){
          my @s = split "\n", $block;

          # process items
          my %h;
          for my $m (@s) {
            if ($m =~ m/(KFPlayerStats\])$/i) {
              $h{UTkey} = substr $m, 1, index($m, " ")-1;}
            if ($m =~ m/=/) {
              $h{substr $m, 0, index($m, "=")} = substr $m, index($m, "=")+1;}
          }
          $self->write_kfstats(\%h);
          $block = "";
        }
      }
      $self->log("kfstat", "Updated Killing Floor player stats.");
    }
  );
}

1;
