
package MasterServer::Core::Version;

use strict;
use warnings;
use Exporter 'import';

our @EXPORT = qw| version |;


################################################################################
##
## Version information
##
################################################################################
sub version {
  my $self = shift;
  
  # version and author information
  #
  # You are not allowed to modify these variables without making (significant)
  # alterations to the source code of this master server program. Only changing
  # these fields does not count as a significant alteration.
  #
  # -- addition to the LICENCE, you are only allowed to modify these lines
  # if you send Darkelarious a postcard or email with your compliments.
  #

  # master type
  $self->{build_type}     = "333networks Masterserver-Perl (Pg-SQLite-MySQL) 20151108209";
  
  # version
  $self->{build_version}  = "2.0.9";
  
  # date yyyy-mm-dd
  $self->{build_date}     = "2015-11-08";
  
  #author, email
  $self->{build_author}   = "Darkelarious, darkelarious\@333networks.com";
}

1;
