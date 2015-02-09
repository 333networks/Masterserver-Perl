
package MasterServer::Core::Version;

use strict;
use warnings;
use Exporter 'import';

our @EXPORT = qw| version |;


################################################################################
#
# Version information
#
################################################################################
sub version {
  my $self = shift;
  
  # version and author information
  # -- addition to the LICENCE, you are only allowed to modify these lines
  # if you send Darkelarious a postcard or email with your compliments or,
  # in case of a company editing, a letter of commendation.
  #
  # You are not allowed to modify these variables without making (significant)
  # alterations to the source code of this master server program. Only changing
  # these fields does not count as a significant alteration.

  # master type
  $self->{build_type}     = "333networks Masterserver-Perl";
  
  # version
  $self->{build_version}  = "0.2";
  
  # date yyyy-mm-dd
  $self->{build_date}     = "2015-01-31";
  
  #author, email
  $self->{build_author}   = "Darkelarious, darkelarious\@333networks.com";
}

1;
