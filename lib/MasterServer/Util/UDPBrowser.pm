package MasterServer::Util::UDPBrowser;

use strict;
use warnings;
use AnyEvent::Handle::UDP;
use Socket qw(sockaddr_in inet_ntoa);
use Exporter 'import';
our @EXPORT = qw| udpbrowser_host |;

################################################################################
## Wait for incoming UDP messages from game clients and other masterservers.
## In contrary to the compliant TCP browser host, this function handles the
## request in a single query and responds with a single udp list.
## This read-only method is slightly unsafe as it bypasses the secure/validate 
## challenge; however, this list is freely available over the JSON api, so not 
## worth protecting against exploits.
## Request format: \echo\request\gamename\postal2\list\\final\
################################################################################
sub udpbrowser_host {
  # self, handle, packed address, buffer
  my ($self, $udp, $paddress, $buffer) = @_; 
  my $rx = $self->data2hashref($buffer);
  my $response = "";
  
  # unpack ip from packed client address
  my ($port, $iaddr) = sockaddr_in($paddress);
  my $addr = inet_ntoa($iaddr);
  
  # list request with valid gamename and list request
  if ($rx->{gamename} && exists $rx->{list}) {
    # get list and log
    $response = $self->generate_list($rx->{gamename}, $rx->{list});
    $self->log("list","$addr:$port retrieved the list for $rx->{gamename} over UDP");
  }
  else {
    # log error
    $response = "\\echo\\incorrect request format";
    $self->log("warning","$addr:$port failed to retrieve the list over UDP for ". 
      ($rx->{gamename} || "empty_gamename"));
  }

  # close query with final tag
  $response .= "\\final\\";
  
  # split the response in chunks of 512 bytes and send (for large lists)
  while (length $response > 512) {
    my $chunk = substr $response, 0, 512, '';
    $udp->push_send($chunk, $paddress);
  }
  # last <512 chunk
  $udp->push_send($response, $paddress);
}

1;
