package MasterServer;
our (%S, $ROOT);
our %S = (
################################################################################
# Masterserver HOST information                                                #
#                                                                              #
# Please fill in YOUR contact details here, for two-way synchronization and    #
# for your users to be able to contact you.                                    #
#                                                                              #
# Values may not contain backslashes and quotes: no \ or \\, nor ' and ",      #
# unless you know exactly what you're doing!                                   #
#                                                                              #
################################################################################
  
  # example: 333networks -- http://master.333networks.com -- info@333networks.com
  contact_details => '333networks -- http://master.333networks.com -- info@333networks.com',
  
  # host address, shows when using sync-options
  masterserver_address => 'master.333networks.com',
  
################################################################################
# Database Login Configuration                                                 #
#                                                                              #
# Login credentials for the database that was created manually before.         #
# Yes, that means that you need to create the database and tables on your own. #
# Use only one option: Postgresql, SQLite or MySQL                             #
#                                                                              #
################################################################################

  # Postgresql
  #dblogin => ['dbi:Pg:dbname=databasename', 'user', 'password'],
 
  # SQLite
  #dblogin => ["dbi:SQLite:dbname=$ROOT/data/databasename.db",'',''], 

  # MySQL
  dblogin => ["dbi:mysql:database=databasename;host=localhost;port=3306",'user','password'],
  
################################################################################
# Logging configuration                                                        #
#                                                                              #
# All messages are printed to the log (and screen) by default. The following   #
# settings determine the file locatioin and which messages are suppressed.     #
#                                                                              #
################################################################################
  
  # log file location (folder name!)
  log_dir   => "$ROOT/log/",
  
  #new log for every period of time? options: daily, weekly, monthly, yearly, none
  log_rotate => "weekly",
  
  # print to screen (1=yes, 0=no)
  printlog  => 1, 
  
  # which messages do you NOT want to see in the logs (and screen)?
  suppress  =>  "none", # show all entries
  
  # suppress the most annoying messages
  # suppress  => "add update delete read tcp udp secure query beacon hostname",
  
  # print database errors
  db_print => 0,
  
################################################################################
# Network settings                                                             #
#                                                                              #
# Beacon UDP port (beacons) and Browser TCP port  (serverlist)                 #
# Settings for games that require different data formats                       #
#                                                                              #
################################################################################

  # port settings
  listen_port   => 28900, # default 28900
  beacon_port   => 27900, # default 27900    

  # these games require a special hex format instead of \ip\ip:port\
  hex_format => "bcommander",

################################################################################
# Secure/Validate configuration                                                #
#                                                                              #
# Which servers have to validate? Which games may be ignored?                  #
#                                                                              #
################################################################################

  # disable checks, all games pass as validated (0=validate only, 1=don't check)
  debug_validate => 0,
  
  # accept only servers that pass the secure/validate challenge, takes longer
  require_secure_beacons => 0,
  
  # ignore keys from games that use multiple keys or do not support keys at all
  ignore_beacon_key   => "deusex ut",
  ignore_browser_key  => "deusex",

################################################################################
# Enable + Timer settings                                                      #
#                                                                              #
# When does what process start? Format: after [s], interval [s],               #
# maximum cycle time [s] (optional)                                            #
# Wait 60+ seconds before starting timers for incoming beacons                 #
#                                                                              #
################################################################################

  # Synchronization with other 333networks-based masterservers
  sync_enabled  => 1, # 0 = disabled
  sync_time     => [60, 900],
  
  # Query UCC-based applets
  master_applet_enabled => 1, # 0 = disabled
  master_applet_time    => [90, 900],

  # Beacon Checker query all addresses in the database, requesting "basic" and 
  # "info". Execute at least twice per hour, to avoid time-outs in own data.
  # disabling breaks support for certain games [citation needed].
  beacon_checker_enabled  => 1,
  beacon_checker_time     => [120, 0.5, 1800],

################################################################################
# Synchronization settings                                                     #
#                                                                              #
# Request the masterlist for selected or all games from other 333networks-     #
# based masterservers.                                                         #
#                                                                              #
################################################################################
  
  # masters to sync with
  sync_masters  => [
        { address => "master.333networks.com", port => 28900 }, # default
        { address => "master.noccer.de",       port => 28900 },
        { address => "master.oldunreal.com",   port => 28900 },
        { address => "master.errorist.tk",     port => 28900 },
  ],
  
  # sync all or only selected games?
  # 0 = all, 1 + gamenames = selected
  #sync_games => [1, "ut unreal"], # example with only UT/Unreal syncing
  sync_games => [0],
        
################################################################################
# Query UCC Applets                                                            #
#                                                                              #
# Request the masterlist for single games from the remote UCC applet or        #
# equivalent.                                                                  #
#                                                                              #
################################################################################        

  # remote applets to be queried
  master_applet => [
    {ip => "utmaster.epicgames.com",       port => 28900, game => "ut"},
    {ip => "master.newbiesplayground.net", port => 28900, game => "unreal"},
    {ip => "master.hlkclan.net",           port => 28900, game => "unreal"},
  ],

); #end %S config


################################################################################
#                                                                              #
# Supported Games.                                                             #
#                                                                              #
# List of games of which 333networks has the authentication ciphers. Note that #
# adding a game here does not necessarily mean that suddenly the protocol will #
# be supported.                                                                #
#                                                                              #
################################################################################
require "$ROOT/data/supportedgames.pl";

1;
