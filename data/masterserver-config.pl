package MasterServer;

#
# Last update: Sat 19 Oct 2016 20:23 GMT+1
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
  masterserver_hostname => "master.333networks.com (333networks MasterServer)",
  
  # contact details (shows in TCP requests directly from master to master)
  masterserver_contact  => 'Darkelarious -- info@333networks.com',
  masterserver_address  => 'master.333networks.com',
  
################################################################################
# Database Login Configuration                                                 #
#                                                                              #
# Login credentials for the database that was created manually before.         #
# Yes, that means that you need to create the database and tables on your own. #
# Use only one option: Postgresql, SQLite, MySQL (only tested with Postgresql) #
#                                                                              #
################################################################################

  # Postgresql
  dblogin => ['dbi:Pg:dbname=masterserver', 'user', 'password'],
 
  # SQLite
  #dblogin => ["dbi:SQLite:dbname=$ROOT/data/testdatabase.db",'',''], 

  # MySQL
  #dblogin => ["dbi:mysql:database=database_name;host=localhost;port=3306",'user','password'],
  
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
  printlog  => 0, 
  
  # which messages do you NOT want to see in the logs (and screen)?
  # show all entries
  #suppress =>  "none",
  
  # disable most messages, except for important events
  suppress => "udp add update tcp udp delete uplink stat beacon secure utserver hostname kfstat debug",
  
  # print database errors
  db_print => 0,
  
################################################################################
# Network settings                                                             #
#                                                                              #
# Beacon UDP port (beacons) and Browser TCP port (serverlist)                  #
# Settings for games that require different data formats                       #
#                                                                              #
################################################################################

  # port settings
  listen_port   => 28900, #28905, # default 28900
  beacon_port   => 27900, #28906, # default 27900    

  # these games require a special hex format instead of \ip\ip:port\
  # if the current protocol is correct, you don't need to touch this ever.
  hex_format => "",

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
  # disabling breaks support for certain games [citation needed].
  beacon_checker_enabled  => 1,

  # Collect server information for the 333networks main site. Identical
  # mechanism as the Beacon Checker. Is used for by 333networks to show
  # Unreal Tournament information on the site.
  # NB: with some work it can be adapted to work with any other game. Own risk.
  utserver_query_enabled  => 0,

################################################################################
# Synchronization settings                                                     #
#                                                                              #
# Request the masterlist for selected or all games from other 333networks-     #
# based masterservers. Also uplinks to these servers in return.                #
#                                                                              #
################################################################################
  
  # additional masters to sync with (in addition to db-entries)
  sync_masters  => [
        { address => "master.333networks.com", port => 28900, beacon => 27900 }, # default
        { address => "master.noccer.de",       port => 28900, beacon => 27900 },
        { address => "master.oldunreal.com",   port => 28900, beacon => 27900 },
        { address => "master.errorist.tk",     port => 28900, beacon => 27900 },
#        { address => "master.333networks.com", port => 28905, beacon => 28906 }, # if available, devmaster
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
################################################################################        
  master_applet => [
    {ip => "utmaster.epicgames.com",       port => 28900, game => "ut"},
    {ip => "master.newbiesplayground.net", port => 28900, game => "unreal"},
  ],

################################################################################
# Killing Floor Statistics                                                     #
#                                                                              #
# Read player statistics from the KFstats file in the UT2004 configuration.    #
# Applies to 333networks Killing Floor Server only!                            #
################################################################################

  #kfstats.ini file location
  kfstats_file =>  "/home/darkelarious/ut2004/System/KFStats.ini",
  
  # Collect kfstats info
  kfstats_enabled  => 0,
  
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
