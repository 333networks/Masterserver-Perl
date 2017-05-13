CREATE TABLE appletlist(
  id              INTEGER          PRIMARY KEY AUTOINCREMENT,
  ip              VARCHAR(15)      NOT NULL DEFAULT '0.0.0.0',
  port            INTEGER          NOT NULL DEFAULT 0,
  gamename        VARCHAR(50)      NOT NULL DEFAULT ' ',
  added           timestamptz      NOT NULL DEFAULT CURRENT_TIMESTAMP,
  updated         timestamptz      NOT NULL DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE serverlist(
  id              INTEGER          PRIMARY KEY AUTOINCREMENT,
  ip              VARCHAR(15)      NOT NULL DEFAULT '0.0.0.0',
  port            INTEGER          NOT NULL DEFAULT 0,
  gamename        VARCHAR(100)     NOT NULL DEFAULT ' ',
  gamever         VARCHAR(50)      NOT NULL DEFAULT ' ',
  hostname        VARCHAR(100)     NOT NULL DEFAULT ' ',
  hostport        INTEGER          NOT NULL DEFAULT 0,
  country         VARCHAR(5),
  b333ms          BOOLEAN          NOT NULL DEFAULT 0,
  blacklisted     BOOLEAN          NOT NULL DEFAULT 0,
  added           timestamptz      NOT NULL DEFAULT CURRENT_TIMESTAMP,
  beacon          timestamptz      NOT NULL DEFAULT CURRENT_TIMESTAMP,
  updated         timestamptz      NOT NULL DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE games(
  gamename        VARCHAR(50)        NOT NULL,
  cipher          VARCHAR(10)        NOT NULL DEFAULT ' ',
  description     VARCHAR(200)       NOT NULL DEFAULT ' ',
  default_qport   INTEGER            NOT NULL DEFAULT 0,
  num_uplink      INTEGER            NOT NULL DEFAULT 0,
  num_total       INTEGER            NOT NULL DEFAULT 0
);

CREATE TABLE pending(
  id              INTEGER          PRIMARY KEY AUTOINCREMENT,
  ip              VARCHAR(15)      NOT NULL DEFAULT '0.0.0.0',
  beaconport      INTEGER          NOT NULL DEFAULT 0,
  heartbeat       INTEGER          NOT NULL DEFAULT 0,
  gamename        VARCHAR(25)      NOT NULL DEFAULT ' ',  
  secure          VARCHAR(12)      NOT NULL DEFAULT 'wookie',
  enctype         INTEGER          NOT NULL DEFAULT 0,
  added           timestamptz      NOT NULL DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE utserver_info(
  server_id           INTEGER      PRIMARY KEY AUTOINCREMENT,
  minnetver           INTEGER      NOT NULL DEFAULT 400,
  gamever             INTEGER      NOT NULL DEFAULT 400,
  location            INTEGER      NOT NULL DEFAULT 0,
  listenserver        BOOLEAN      NOT NULL DEFAULT TRUE,
  hostport            INTEGER      NOT NULL DEFAULT 7777,
  hostname            varchar(200) NOT NULL DEFAULT 'Another UT server',
  adminname           varchar(200) NOT NULL DEFAULT '',
  adminemail          varchar(300) NOT NULL DEFAULT '',
  password            BOOLEAN      NOT NULL DEFAULT 0,
  gametype            varchar(50)  NOT NULL DEFAULT '',
  gamestyle           varchar(50)  NOT NULL DEFAULT 'Normal',
  changelevels        BOOLEAN      NOT NULL DEFAULT 0,
  maptitle            varchar(100) NOT NULL DEFAULT 'Unknown',
  mapname             varchar(100) NOT NULL DEFAULT '',
  numplayers          INTEGER      NOT NULL DEFAULT 0,
  maxplayers          INTEGER      NOT NULL DEFAULT 0,
  minplayers          INTEGER      NOT NULL DEFAULT 0,
  botskill            varchar(30)  NOT NULL DEFAULT 'Novice',
  balanceteams        BOOLEAN      NOT NULL DEFAULT 0,
  playersbalanceteams BOOLEAN      NOT NULL DEFAULT 0,
  friendlyfire        varchar(10)  NOT NULL DEFAULT '0%',
  maxteams            INTEGER      NOT NULL DEFAULT 4,
  timelimit           INTEGER      NOT NULL DEFAULT 0,
  goalteamscore       INTEGER      NOT NULL DEFAULT 0,
  fraglimit           INTEGER      NOT NULL DEFAULT 0,
  mutators            TEXT         NOT NULL DEFAULT 'None',
  updated             timestamptz  NOT NULL DEFAULT CURRENT_TIMESTAMP,
  FOREIGN KEY(server_id) REFERENCES serverlist(id)
);

CREATE TABLE utplayer_info(
  server_id INTEGER,
  player    varchar(40)   NOT NULL DEFAULT 'Player',
  team      INTEGER       NOT NULL DEFAULT 255,
  frags     INTEGER       NOT NULL DEFAULT 0,
  mesh      varchar(100)  NOT NULL DEFAULT '',
  skin      varchar(100)  NOT NULL DEFAULT '',
  face      varchar(100)  NOT NULL DEFAULT '',
  ping      INTEGER       NOT NULL DEFAULT 0,
  ngsecret  varchar(10)   NOT NULL DEFAULT 'false',
  updated   timestamptz   NOT NULL DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE kfstats(
  UTkey             varchar(34) NOT NULL,
  Username          varchar(80) NOT NULL DEFAULT '',
  CurrentVeterancy  varchar(80)          DEFAULT 'None',
  TotalKills        INTEGER     NOT NULL DEFAULT 0,
  DecaptedKills     INTEGER     NOT NULL DEFAULT 0,
  TotalMeleeDamage  INTEGER     NOT NULL DEFAULT 0,
  MeleeKills        INTEGER     NOT NULL DEFAULT 0,
  PowerWpnKills     INTEGER     NOT NULL DEFAULT 0,
  BullpupDamage     INTEGER     NOT NULL DEFAULT 0,
  StalkerKills      INTEGER     NOT NULL DEFAULT 0,
  TotalWelded       INTEGER     NOT NULL DEFAULT 0,
  TotalHealed       INTEGER     NOT NULL DEFAULT 0,
  TotalPlaytime     INTEGER     NOT NULL DEFAULT 0,
  GamesWon          INTEGER     NOT NULL DEFAULT 0,
  GamesLost         INTEGER     NOT NULL DEFAULT 0
);
