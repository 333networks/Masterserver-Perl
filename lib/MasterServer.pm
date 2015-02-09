
package MasterServer;

use strict;
use warnings;

our $OBJ = bless {}, 'MasterServer::Object';

# Load modules, recursively
# All submodules should be under the same directory in @INC
# Greets to Yorhel for this one.
sub load_recursive {
  my $rec;
  $rec = sub {
    my($d, $f, $m) = @_;
    for my $s (glob "$d/$f/*") {
      $OBJ->_load_module("${m}::$1") if -f $s && $s =~ /([^\/]+)\.pm$/;
      $rec->($d, "$f/$1", "${m}::$1") if -d $s && $s =~ /([^\/]+)$/;
    }
  };
  for my $m (@_) {
    (my $f = $m) =~ s/::/\//g;
    my $d = (grep +(-d "$_/$f" or -s "$_/$f.pm"), @INC)[0];
    $OBJ->_load_module($m) if -s "$d/$f.pm";
    $rec->($d, $f, $m) if -d "$d/$f";
  }
}

# Load modules
sub load {
  $OBJ->_load_module($_) for (@_);
}

# run our master server
sub run {
  $OBJ->main();
}

# The namespace which inherits all functions to be available in the global
# object.
package MasterServer::Object;

# load modules
sub _load_module {
  my($self, $module) = @_;
  die $@ if !eval "use $module; 1";
}


1;
