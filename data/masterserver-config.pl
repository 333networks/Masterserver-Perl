package MasterServer;
our (%S, $ROOT);
################################################################################
# Masterserver configuration                                                   #
#                                                                              #
# Review the following settings and edit the values to fit your situation.     #
#                                                                              #
# Please fill in your contact details correctly, as this is shown publicly and #
# on other masterservers. See README for more details.                         #
#                                                                              #
# Values may not contain backslashes and quotes: no \ or \\, nor ' and ",      #
# unless you know exactly what you're doing!                                   #
#                                                                              #
# Supported Games.                                                             #
# The masterserver requires ciphers and gamenames configured in the database   #
# to function.                                                                 #
require "$ROOT/data/supportedgames.pl";                                        #
# Note that adding a game does not necessarily mean that suddenly the protocol #
# will be supported. The above file only provides the necessary parameters.    #
#                                                                              #
# Last configuration update: 25 Sep 2017                                       #
#                                                                              #
################################################################################

our %S = (
  %S, root => $ROOT,

# Masterserver HOST information
# Please fill in your contact details correctly, as this is shown publicly 
# and on other masterservers.

  # masterserver address (optional: nickname or clan)
  masterserver_hostname => "master.example.com (My MasterServer Name)",
  
  # contact details
  masterserver_name     => 'Your Name Here',
  masterserver_contact  => 'info@example.com',
  
  
# Database Login Configuration
# Login credentials for the database that was created manually before.
# Supported types: Postgresql, SQLite

  # Postgresql
  dblogin => ['dbi:Pg:dbname=masterserver', 'user', 'password'],
 
  # SQLite
  #dblogin => ["dbi:SQLite:dbname=$ROOT/data/masterserver.db",'',''], 

  # Backup interval
  # new backup for every period of time? options: daily, weekly, monthly, yearly, none
  dump_db => "daily",
  
  
# Logging
# All messages are printed to the log (and screen) by default. The following
# settings determine the file location and which messages are suppressed.
  
  # log file location (folder name)
  log_dir => "$ROOT/log/",
  
  # new log for every period of time? options: daily, weekly, monthly, yearly, none
  log_rotate => "weekly",
  
  # print both to screen and log (1=screen+log, 0=only log)
  printlog  => 1, 
  
  # which messages do you NOT want to see in the logs (and screen)?
  
  # show all entries
  #suppress =>  "none",
  
  # keywords that can be suppressed (from high to low severity): 
  #   fatal fail error stop
  #   refused nodevice timeout
  #   reset warning secure unset
  #   add update delete
  #   list uplink
  #   beacon syncer
  #   stat kfnew
  #   info debug
  
  # show only important events
  suppress => "debug beacon uplink secure tcp add update delete",
  
  
# Network settings
# Port settings and timeouts

  # TCP/client port, default 28900
  listen_port   => 28900,
  
  # UDP/uplink port, default 27900    
  beacon_port   => 27900,

  # Timeout time for connections. Recommended: 5 (seconds)
  timeout_time => 5,
  
  
# Secure/Validate configuration
# Which servers have to authenticate?
  
  # accept only servers that can authenticate. takes longer before adding to the
  # database, but prevents malicious servers from sending fake query data
  require_secure_beacons => 1,
  
  # ignore keys from games that use multiple keys or do not support keys at all
  ignore_beacon_key   => "deusex ut wot rune",
  ignore_browser_key  => "deusex",
  
  # some games do not even support the "secure" and "validate" values. Bypass.
  secure_unsupported  => "tribesv",
  
  
# Synchronization settings
# Send beacons to the following selected masterservers. This joins us in the
# 333networks network and makes two-way synchronization possible for all games
# or only selected games. Requires at least one entry to a live masterserver.

  # Synchronization with other 333networks-based masterservers
  sync_enabled  => 1,

  # default masterservers to uplink to and synchronize with
  sync_masters  => [
        { address => "master.333networks.com", port => 28900, beacon => 27900 },
        { address => "master.noccer.de",       port => 28900, beacon => 27900 },
        { address => "master.oldunreal.com",   port => 28900, beacon => 27900 },
        { address => "master.errorist.tk",     port => 28900, beacon => 27900 },
  ],
  
  # sync all or selected games?
  # [0] = all
  sync_games => [0],
  
  # other example: [1 + gamenames] = selected games only
  #sync_games => [1, "ut unreal deusex"],
  
  # getting server status info from all servers. executed every 15 minutes to
  # keep information up to date. disabling breaks support for certain games
  # like tribesv.
  beacon_checker_enabled  => 1,
  
# Query UCC-based Applets
# Request the masterlist for single games from the remote UCC applet -- one way
  master_applet_enabled => 1,
  
  # default applets to query
  master_applet => [
    {address => "utmaster.epicgames.com",   port => 28900, games => [qw|ut unreal|]},
    {address => "master.hypercoop.tk",      port => 28900, games => [qw|unreal|]},
  ],

# Killing Floor Statistics
# 333networks has a UT2004+KillingFloor server for which we maintain statistics.
# not related to the masterserver, but we felt no need to remove it. Set to 0 if
# you do not use it.
  
  # Collect kfstats info
  kfstats_enabled  => 0,

  # kfstats.ini file location
  kfstats_file =>  "/UT2004/System/KFStats.ini",
  
);

1;
