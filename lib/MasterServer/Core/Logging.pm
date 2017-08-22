package MasterServer::Core::Logging;

use strict;
use warnings;
use Switch;
use POSIX qw/strftime/;
use Exporter 'import';
our @EXPORT = qw| log error |;
$|++;

################################################################################
## Split up errors in multiple log types for suppressing
## args: $self, message
################################################################################
sub error {
  my ($self, $error, $instigator) = @_;
  
  # which one?
  switch ($error) {
    # connection timed out
    case m/Connection timed out/i {$self->log("timeout", "on $instigator.");}
    # connection reset by peer
    case m/Connection reset by peer/i {$self->log("reset", "on $instigator.");}
    # connection refused
    case m/Connection refused/i {$self->log("refused", "on $instigator.");}
    # no such device or address
    case m/No such device or address/i {$self->log("nodevice", "on $instigator.");}
    # if all else fails
    else {$self->log("error", "$error on $instigator.");}
  }
}

################################################################################
## Log to file and print to screen.
## args: $self, message_type, message
################################################################################
sub log {
  my ($self, $type, $msg) = @_;

  # is the message suppressed in config?
  return if ($self->{suppress} =~ m/$type/i);
  $type = "unknown" unless $type;

  # parse time of log entry and prep for rotating log
  my $time    = strftime('%Y-%m-%d %H:%M:%S',localtime);
  
  # determine filename
  my $f = "MasterServer";
  
  # rotate log filename according to config
  $f .= strftime('-%Y-%m-%d',localtime)  if ($self->{log_rotate} =~ /^daily$/i  );
  $f .= strftime('-%Y-week%U',localtime) if ($self->{log_rotate} =~ /^weekly$/i );
  $f .= strftime('-%Y-%m',localtime)     if ($self->{log_rotate} =~ /^monthly$/i);
  $f .= strftime('-%Y',localtime)        if ($self->{log_rotate} =~ /^yearly$/i );
  $f .= ".log";
  
  # put log filename together
  my $logfile = $self->{log_dir}.((substr($self->{log_dir},-1) eq "/")?"":"/").$f;
  
  # temporarily disable the warnings-to-log, to avoid recursion if 
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
  
  # color codes for fancy terminal output (not to file)
  $type = "\e[1m\e[91m$type\e[0m" if ($type =~ m/(fatal|fail|error|stop)/i);# bold red
  $type = "\e[91m$type\e[0m" if ($type =~ m/(refused|nodevice|timeout)/i);  # red
  $type = "\e[93m$type\e[0m" if ($type =~ m/(reset|warning|secure|unset)/i);# yellow
  $type = "\e[95m$type\e[0m" if ($type =~ m/(add|update|delete)/i);         # magenta
  $type = "\e[96m$type\e[0m" if ($type =~ m/(list|uplink)/i);               # cyan
  $type = "\e[94m$type\e[0m" if ($type =~ m/(beacon|syncer)/i);             # blue
  $type = "\e[92m$type\e[0m" if ($type =~ m/(stat|kfnew)/i);                # green
  $type = "\e[1m\e[92m$type\e[0m" if ($type =~ m/(info|debug)/i);           # bold green

  # print to stdout if enabled
  print "[$time]\t[$type]\t$msg\n" if $self->{printlog};
}

1;
