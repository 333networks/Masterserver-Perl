
package MasterServer::Core::Logging;

use strict;
use warnings;
use POSIX qw/strftime/;
use Exporter 'import';

our @EXPORT = qw| log |;

################################################################################
## Log to file and print to screen.
## args: $self, message_type, message
################################################################################
sub log {
  my ($self, $type, $msg) = @_;
  
  # parse time of log entry and prep for rotating log
  my $time    = strftime('%Y-%m-%d %H:%M:%S',localtime);
  my $yearly  = strftime('-%Y',localtime);
  my $monthly = strftime('-%Y-%m',localtime);
  my $weekly  = strftime('-%Y-week%U',localtime);
  my $daily   = strftime('-%Y-%m-%d',localtime);
  
  # is the message suppressed in config?
  return if (defined $type && $self->{suppress} =~ m/$type/i);
  
  # determine filename
  my $f = "MasterServer-333networks";
  
  # rotate log filename according to config
  $f .= $daily    if ($self->{log_rotate} =~ /^daily$/i   );
  $f .= $weekly   if ($self->{log_rotate} =~ /^weekly$/i  );
  $f .= $monthly  if ($self->{log_rotate} =~ /^monthly$/i );
  $f .= $yearly   if ($self->{log_rotate} =~ /^yearly$/i  );
  $f .= ".log";
  
  # put log filename together
  my $logfile = $self->{log_dir}.((substr($self->{log_dir},-1) eq "/")?"":"/").$f;

  print "[$time] [$type] > $msg\n" if $self->{printlog};
  
  # temporarily disable the warnings-to-log, to avoid infinite recursion if
  # this function throws a warning.
  my $old = $SIG{__WARN__};
  $SIG{__WARN__} = undef;

  chomp $msg;
  $msg =~ s/\n/\n  | /g;
  if($logfile && open my $F, '>>:utf8', $logfile) {
    flock $F, 2;
    seek $F, 0, 2;
    print $F "[$time]\t[$type]\t$msg\n";
    flock $F, 4;
    close $F;
  }
  $SIG{__WARN__} = $old;
}


1;
