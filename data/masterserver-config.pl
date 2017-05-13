package MasterServer;

#
# Last update: Sat 13 May 2017 13:37 GMT+1
#

our (%S, $ROOT);
our %S = (
  # preserve root path  
  root => $ROOT,

################################################################################
# Masterserver HOST information                                                #
#                                                                              #
# Please fill in your contact details here, for two-way synchronization and    #
# for your users to be able to contact you.                                    #
#                                                                              #
# Values may not contain backslashes and quotes: no \ or \\, nor ' and ",      #
# unless you know exactly what you're doing!                                   #
#                                                                              #
################################################################################

  # our public display name (shows in "online masterservers" on 333networks.com)
  masterserver_hostname => "master.333networks.com (333networks MasterServer Template)",
  
  # contact details (shows in TCP requests directly from master to master)
  masterserver_contact  => 'Darkelarious -- info@333networks.com',
  masterserver_address  => 'master.333networks.com',
  
################################################################################
# Database Login Configuration                                                 #
#                                                                              #
# Login credentials for the database that was created manually before.         #
# Yes, that means that you need to create the database and tables on your own. #
# Use only one option: Postgresql, SQLite, MySQL (not tested with MySQL)       #
#                                                                              #
################################################################################

  # Postgresql
  dblogin => ['dbi:Pg:dbname=masterserver', 'user', 'password'],
 
  # SQLite
  #dblogin => ["dbi:SQLite:dbname=$ROOT/data/masterserver.db",'',''], 

  # MySQL
  #dblogin => ["dbi:mysql:database=masterserver;host=localhost;port=3306",'user','password'],

  # backup database dump
  # new backup for every period of time? options: daily, weekly, monthly, yearly, none
  dump_db => "daily",

################################################################################
# Logging configuration                                                        #
#                                                                              #
# All messages are printed to the log (and screen) by default. The following   #
# settings determine the file location and which messages are suppressed.      #
#                                                                              #
################################################################################
  
  # log file location (folder name!)
  log_dir   => "$ROOT/log/",
  
  # new log for every period of time? options: daily, weekly, monthly, yearly, none
  log_rotate => "weekly",
  
  # print both to screen and log (1=screen+log, 0=only log)
  printlog  => 1, 
  
  # which messages do you NOT want to see in the logs (and screen)?
  # show all entries
  #suppress =>  "none",
  
  # show only important events
  suppress => "debug beacon uplink secure tcp add update delete",
  
  # more keywords that can be suppressed: 
  # applet-rx error info kfstat stat sync-rx sync-tx list ignore dump support
  
################################################################################
# Network settings                                                             #
#                                                                              #
# Beacon UDP port (beacons) and Browser TCP port (serverlist)                  #
#                                                                              #
################################################################################

  # port settings
  listen_port   => 28900, # default 28900
  beacon_port   => 27900, # default 27900    

  # Timeout time for connections. Some clients are on slow connections
  # or are queued for a relatively long time. Recommended: 5s
  timeout_time => 10,

################################################################################
# Secure/Validate configuration                                                #
#                                                                              #
# Which servers have to validate? Which games may be ignored?                  #
#                                                                              #
################################################################################

  # disable checks, all games pass as validated (0=validate only, 1=don't check)
  debug_validate => 0,
  
  # accept only servers that pass the secure/validate challenge, takes longer
  # but prevents malicious servers from sending fake query data
  require_secure_beacons => 1,
  
  # ignore keys from games that use multiple keys or do not support keys at all
  ignore_beacon_key   => "deusex ut wot rune",
  ignore_browser_key  => "deusex",

################################################################################
# Enable settings                                                              #
#                                                                              #
# 0 = disabled                                                                 #
#                                                                              #
################################################################################
  
  # Query UCC-based applets
  master_applet_enabled => 1,

  # Synchronization with other 333networks-based masterservers
  sync_enabled  => 1,

  # Beacon Checker query all addresses in the database, requesting "basic" and 
  # "info". Execute at least twice per hour, to avoid time-outs in own data.
  # disabling breaks support for certain games [like tribesv].
  beacon_checker_enabled  => 1,

  # Collect server information for the 333networks main site. Identical
  # mechanism as the Beacon Checker. Is used for by 333networks to show
  # Unreal Tournament information on the site.
  # NB: with some work it can be adapted to work with any other game. Own risk.
  utserver_query_enabled  => 0,

################################################################################
# Synchronization settings                                                     #
#                                                                              #
# Send beacons to the following selected masterservers. This joins us in the   #
# 333networks network and makes two-way synchronization possible for all games #
# or only selected games. Requires at least one entry to a live masterserver.  #
################################################################################
  
  # default masterservers to uplink to
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

################################################################################
# Query UCC Applets                                                            #
#                                                                              #
# Request the masterlist for single games from the remote UCC applet or        #
# equivalent.                                                                  #
#                                                                              #
# Arguments: domain/ip, tcp  port, array of gamenames                          #
################################################################################        
  master_applet => [
    {address => "utmaster.epicgames.com",   port => 28900, games => [qw|ut unreal|]},
    {address => "master.hypercoop.tk",      port => 28900, games => [qw|unreal|]},
    {address => "sof1master.megalag.org",   port => 28900, games => [qw|sofretail|]},
    {address => "master.deusexnetwork.com", port => 28900, games => [qw|deusex|]},
  ],

################################################################################
# Killing Floor Statistics                                                     #
#                                                                              #
# Read player statistics from the KFstats file in the UT2004 configuration.    #
# Applies to 333networks Killing Floor Server only!                            #
################################################################################
  
  # Collect kfstats info
  kfstats_enabled  => 0,

  #kfstats.ini file location
  kfstats_file =>  "/UT2004/System/KFStats.ini",
  
); #end configuration %S

################################################################################
#                                                                              #
# Supported Games.                                                             #
#                                                                              #
# List of games that are supported by the 333networks masterserver. Note that  #
# adding a game does not necessarily mean that suddenly the protocol will      #
# be supported. It only needs the provided ciphers.                            #
#                                                                              #
################################################################################
require "$ROOT/data/supportedgames.pl";

1;
