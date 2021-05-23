# MasterServer-Perl

Repository for the 333networks MasterServer written in Perl.


=========

# DESCRIPTION
  
  This repository contains software to host a MasterServer for a variety of 
  legacy games. The software was written Darkelarious to soften the effects of 
  GameSpy (GameSpy Industries, Inc.) shutting down their masterserver service.

  A masterserver is a program that maintains a list of online game servers and 
  presents this list to clients (gamers, players) who request the list of game 
  addresses. The 333networks Masterserver is a software framework that allows 
  gamers/players to browse online games.
  
  More information about the masterserver and variations on the protocol by
  333networks can be found online at 
        http://333networks.com/masterserver

# AUTHOR

  Darkelarious
  http://333networks.com
  darkelarious@333networks.com

# REQUIREMENTS

  - Postgresql, SQLite3
  - Perl 5.22 or above
  - The following CPAN modules:
      AnyEvent
      AnyEvent::Handle::UDP
      DBI
      DBD::Pg / DBD::SQLite
      Encode
      Exporter
      IP::Country::Fast;
      Socket
      Switch
      JSON
  - screen (or another terminal multiplexer, optional)

# INSTALL

  THE MASTER SERVER IS WRITTEN ON LINUX. IF YOU WANT TO RUN THE SOFTWARE IN 
  MICROSOFT WINDOWS OR APPLE OSX, IT WILL NOT WORK WITHOUT MODIFICATIONS.
  
  Download the masterserver files from our git repository (or zip) and extract
  them to your favorite server directory.
  
  The masterserver stores server addresses in the database. This database must
  be created manually. SQLite3 users should not forget to chmod the database 
  file with read/write access. The tables to be created can be found in the 
  "data/sql" folder in the tables-Pg/SQLite/mysql.sql file. Choose your 
  preferred database driver and create the tables by importing the SQL file or
  by manually creating the tables with your SQL shell. SQLite users can use the
  included util/create-sqlite-database.sh to create their database.
  
  This repository consists of Perl modules and is run in terminal. The software
  utilizes UDP and TCP connections to receive and send information about game
  servers. Carefully read through the code and documentation before you start 
  randomly querying other game servers and/or masterservers.
  
# CONFIGURATION

  The 333networks masterserver comes with options. These options are found in
  configuration file "data/masterserver-config.pl". Comments in that file give
  a brief description. Here, the configuration is discussed in further detail.
  
  Masterserver HOST information
  
  Fill in your contact details here to be able to synchronize with other 
  masterservers. These settings are displayed on the web interfaces and are 
  shown to others in order to connect to your masterserver.
  
  This information is also shown when others use the \status\ query on your
  server: they can see who hosts this masterserver, which build you are running 
  and which games you currently support. Filling in this information is highly 
  recommended and much appreciated by the community.
  
  Database login information
  
  The masterserver supports different database types. In the module 
  "lib/MasterServer/Databases" you can see which types are currently supporting
  out of the box. To choose a database type, specify the "dblogin" variable:
  
    # Postgresql
    dblogin => ['dbi:Pg:dbname=databasename', 'user', 'password'],
 
    # SQLite
    dblogin => ["dbi:SQLite:dbname=$ROOT/data/databasename.db",'',''], 

    # MySQL
    dblogin => ["dbi:mysql:database=databasename;host=localhost;port=3306",
                                                            'user','password'],
  
  Keep in mind that the database needs to be created manually. That means that 
  you first have to create your postgres/mysql user and grant permissions as
  described in the proprietary manuals that come with your database 
  installation. After that, you have to insert the tables manually, which are 
  provided in the "data/sql" folder. The masterserver script requires
  read-and-write permissions on the SQL database file(s).

    dump_db => "daily",
  
  It is useful to dump the database every once in a while for backup purposes.
  This can be done by specifying the "dump_db" option as above, with the options
  every day, week, month, year or not at all.
  
  Logging
  
  All events are logged by default. Every new beacon, database transaction or 
  serverlist request is recorded in the logfile. For debugging purposes, this is
  very useful, but for regular use, the logfile will grow big very fast. With
  the "suppress" option, log messages can be suppressed from being logged. This
  option takes the message type, separated by spaces. To suppress a message
  type, use the identifier between brackets. Example: 
    
    [2017-05-13 17:31:47] [debug] > Connected to the Postgres database.
  
  In this message, the timestamp of the message is shown first, followed by the
  identifier "debug". To suppress this type of message, the following
  parameter can be set:
  
    suppress => "debug"
    suppress => "debug beacon secure stat"
  
  More message types can be suppressed, where the types are separated by spaces 
  as shown in the second example. If you want to log a lot of events, you could 
  consider rotating the logs every day, week, month or year. The 'log_rotate' 
  allows you to store events in different files with specified interval.
  
  Network settings
  
  The masterserver uses UDP and TCP networking. The default port numbers are 
  27900 for server beacons (UDP) and 28900 for serverlists (TCP). Home-hosters
  have to open those firewall ports. 
  
    timeout_time => 5,
  
  Some servers and clients have slow connections or a lot of latency. If you 
  experience issues with this, increase the time-out time for connections. 
  Recommended: 5 seconds.
  
  Supported Games & Secure/Validate
  
  All GameSpy protocol games communicate according to a protocol that requires
  servers and clients to authenticate each other. As far as 333networks are 
  concerned, the authentication ciphers (keys) are confidential and intellectual
  property of the individual game companies. 
  
  If you have a configuration file with keys, you can simply import this list
  at the bottom of the configuration file as shown there. If you do not have the
  correct ciphers, you can choose to bypass the secure/validate challenge. This
  also allows hackers and opportunists to provide fake data or request the data
  without authorization. See option "require_secure_beacons".
  
  If you use the proper authentication ciphers, keep in mind that some games, 
  like Deus Ex, have more than one cipher, or do not support the challenge at 
  all. Other games may have been modified to counter the vulnerability against
  long queries. Some UT servers have been observed to respond with "Orange" 
  instead of the correct response. Both situations can be in- or excluded in
  the "ignore_key" options. Contact 333networks for more information about 
  obtaining ciphers.
  
  Enable settings
  
  There are three methods to add server addresses to the list: by receiving a
  direct beacon, by validating a pending server and by synchronization. Some of
  these functions can be disabled from the configuration.
  
  Direct beacons can be processed by adding them to the database directly after
  they validated. When validation is not an option (because missing ciphers), 
  the masterserver can query the addresses individually, to determine whether
  they are valid game servers. Change with "beacon_checker_enabled".
  
  This also scans servers periodically to see whether they are still online,
  what game they are and other server information such as version/compatibility
  and server name.
  
  Query UCC Applets
  
  In addition, other UCC masterserver applets can be queried for more server
  addresses. This should not be done without permission of the UCC applet
  hosts, it's impolite to do so without asking. The new servers are added to
  the "pending" list, where they wait to be queried individually as described
  above. If "beacon_checker_enabled" is disabled, this function will NOT work 
  properly. Enable/Disable with "master_applet_enabled".
  
  Synchronization settings
  
  Synchronization between masterservers allows you to receive the list from 
  other masterservers. In return and to make this communication two-way, the
  masterserver sends uplinks to all other masterservers that are specified in
  your list. Your masterserver is then queried in the same way as if it were an
  ordinary game server. This also shares the information that you provided
  earlier in the HOST information section. If you do not wish this to happen, 
  you should disable synchronization entirely. Change with "sync_enabled".
  
  Newly received servers are added to the "pending" list as described above. 
  Please note that this will not prevent others from obtaining the server 
  lists. Attempting to disable this is ambiguous, as "regular" clients do the 
  same to get the serverlist.
  
  BY ENABLING SYNCHRONIZATION, YOU AGREE TO BE QUERIED BY OTHER 333NETWORKS 
  BASED MASTERSERVERS AND SYNCHRONIZATION TOOLS. To us, this sounds perfectly
  reasonable and logical, but some newlings actually started complaining that 
  when they leeched off masterservers, others actually queried them too. If you
  do not want other people querying your masterserver, then why are you running
  a masterserver in the first place?
  
  We do not want authorized people spamming our (or other's) masterservers 
  with sync request to determine whether the server is online (yes, this 
  actually happens -- use the \status\ query for that!) or to keep the list 
  unnecessary updated. Sync requests should not be executed more than 1-2 times 
  per hour.
  
  If you want to sync with us, please email us on info@333networks.com
  
# RUNNING

  After all CPAN modules have been installed and all options have been reviewed
  in the configuration file, the masterserver can be started with the following 
  command from within the util directory of this folder:
   
    screen -dmS "masterserver" ./masterserver.pl
  
  You can also choose to run the masterserver with ./masterserver without the 
  use of a terminal multiplexer, for example for debugging purposes or a
  dry-run to test if your settings are properly configured.
  
  The masterserver works great in combination with one of the MasterServer 
  Interface websites. This allows you to keep an eye on your masterserver and
  allows others to view directly which games you support, how many servers are
  available and more.
  
  The provided configuration is optimized for generic use. Keep in mind that the
  masterserver in this form was originally designed for use with other 
  333networks functions. If you want to set up your own system for any
  game other than Unreal Tournament, you may want to look at other repositories
  on 333networks HOW this is achieved. See also http://git.333networks.com
  
  333networks is not responsible for your masterserver querying (or spamming)
  game servers and/or masterservers. Your configuration is YOUR responsibility!

# TOOLS

  In the "util/tools" folder, a few handy tools are included. In general, it is
  not necessary to use these tools. While debugging and writing new features for
  the masterserver, these scripts have been very handy. Therefore, they are
  included in the repository. Poor documentation is included in the scripts and
  in the required files themselves. Do not forget to change database settings 
  per tool. Expert knowledge required!
  These tools will move to a new repository on our git soon.

# KNOWN ISSUES

  There are a few known issues that will be resolved in future versions. The
  following issues are listed and do not need to be reported.
  
  Memory Expansion
  On some operating systems and with certain CPAN module versions, the memory
  usages keeps increasing to the point where the entire OS crashes or freezes.
  For some CPAN modules has been confirmed that they contribute to this. This
  goes for AnyEvent::UDP::Handle v0.048 on Ubuntu Server 14.04. Try downgrading
  to version v0.043 to temporary solve the problem. This will reduce if not
  stop the memory increase.
  
  This README file is unnecessary long. Over the time we have added a lot of
  functions and therefore a lot of documentation. This README file becomes 
  bloated with things everybody already knows or does not intend to use. There 
  is an initiative to write the masterserver documentation in a single document
  that is more focused on comprehensively outlining the fundamentals of the 
  masterserver, its functions and how to use it. For now, we are stuck with this
  in-depth, redundant and waaay too long README file.
  
  MySQL has not been tested with this masterserver version. When any database
  other than Postgresql or SQLite3 is selected, the masterserver may crash. 
  Support for MySQL will follow at some point, hopefully late 2017.
  
  Differences in statistics compared to other 333networks-based masterservers.
  Some other masterserver interfaces may show different statistics than your
  own masterserver. This may have multiple reasons: servers could have gone
  offline before your masterserver established whether these addresses were 
  online; servers may have missed the update moment and show offline,
  but may get updated in the next cycle; servers send beacons to the other
  masterserver directly, but have incorrect firewall settings that prevent them
  from being checked after synchronization. These factors can not be compensated
  by the 333networks masterservers.
  
  Slow database: currently, database requests are blocking. On slow hardware,
  these requests may take enough time to miss/deny incoming beacons and list
  requests. No solution available in this version. The current configuration 
  for 333networks and affiliated servers do not suffer from this problem.

  No servers found after syncing with 333networks or others: the syncing 
  protocol also requires authentication. We do not want people spamming our 
  (or other's) masterservers with unnecessarily fast sync request. If you want 
  to sync with us, please email us on info@333networks.com

# COPYING
  See file COPYING
