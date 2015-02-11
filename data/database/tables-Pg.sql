CREATE TABLE serverlist(
  id              SERIAL    UNIQUE NOT NULL PRIMARY KEY,
  ip              inet             NOT NULL DEFAULT '0.0.0.0',
  port            INTEGER          NOT NULL DEFAULT 0,
  gamename        VARCHAR(50)      NOT NULL DEFAULT ' ',
  gamever         VARCHAR(50)      NOT NULL DEFAULT ' ',
  hostname        VARCHAR(100)     NOT NULL DEFAULT ' ',
  hostport        INTEGER          NOT NULL DEFAULT 0,
  country         VARCHAR(5),
  b333ms          BOOLEAN          NOT NULL DEFAULT FALSE,
  blacklisted     BOOLEAN          NOT NULL DEFAULT FALSE,
  added           timestamptz      NOT NULL DEFAULT NOW(),
  beacon          timestamptz      NOT NULL DEFAULT NOW(),
  updated         timestamptz      NOT NULL DEFAULT NOW()
);

-- TODO
CREATE TABLE user_stats(
  gamename        VARCHAR(50)      NOT NULL DEFAULT ' ',
  requests        INTEGER          NOT NULL DEFAULT 1,
  beacons         INTEGER          NOT NULL DEFAULT 1
);

CREATE TABLE pending(
  id              SERIAL    UNIQUE NOT NULL PRIMARY KEY,
  ip              inet             NOT NULL DEFAULT '0.0.0.0',
  beaconport      INTEGER          NOT NULL DEFAULT 0,
  heartbeat       INTEGER          NOT NULL DEFAULT 0,
  gamename        VARCHAR(25)      NOT NULL DEFAULT ' ',  
  secure          VARCHAR(12)      NOT NULL DEFAULT ' ',
  enctype         INTEGER          NOT NULL DEFAULT 0,
  added           timestamptz      NOT NULL DEFAULT NOW()
);

CREATE TABLE server_info(
  server_id           SERIAL       REFERENCES serverlist(id),
  minnetver           INTEGER      NOT NULL DEFAULT 400,
  gamever             INTEGER      NOT NULL DEFAULT 400,
  location            INTEGER      NOT NULL DEFAULT 0,
  listenserver        BOOLEAN      NOT NULL DEFAULT TRUE,
  hostport            INTEGER      NOT NULL DEFAULT 7777,
  hostname            varchar(200) NOT NULL DEFAULT '',
  adminname           varchar(200) NOT NULL DEFAULT '',
  adminemail          varchar(300) NOT NULL DEFAULT '',
  password            BOOLEAN      NOT NULL DEFAULT FALSE,
  gametype            varchar(50)  NOT NULL DEFAULT '',
  gamestyle           varchar(50)  NOT NULL DEFAULT 'Normal',
  changelevels        BOOLEAN      NOT NULL DEFAULT FALSE,
  maptitle            varchar(100) NOT NULL DEFAULT 'Unknown',
  mapname             varchar(100) NOT NULL DEFAULT '',
  numplayers          INTEGER      NOT NULL DEFAULT 0,
  maxplayers          INTEGER      NOT NULL DEFAULT 0,
  minplayers          INTEGER      NOT NULL DEFAULT 0,
  botskill            varchar(30)  NOT NULL DEFAULT 'Novice',
  balanceteams        BOOLEAN      NOT NULL DEFAULT FALSE,
  playersbalanceteams BOOLEAN      NOT NULL DEFAULT FALSE,
  friendlyfire        varchar(10)  NOT NULL DEFAULT '0%',
  maxteams            INTEGER      NOT NULL DEFAULT 4,
  timelimit           INTEGER      NOT NULL DEFAULT 0,
  goalteamscore       INTEGER      NOT NULL DEFAULT 0,
  fraglimit           INTEGER      NOT NULL DEFAULT 0,
  mutators            TEXT         NOT NULL DEFAULT 'None'
);

CREATE TABLE player_info(
  server_id SERIAL        NOT NULL,
  player    varchar(40)   NOT NULL DEFAULT 'Player',
  team      INTEGER       NOT NULL DEFAULT 255,
  frags     INTEGER       NOT NULL DEFAULT 0,
  mesh      varchar(100)  NOT NULL DEFAULT '',
  skin      varchar(100)  NOT NULL DEFAULT '',
  face      varchar(100)  NOT NULL DEFAULT '',
  ping      INTEGER       NOT NULL DEFAULT 0,
  ngsecret  varchar(10)   NOT NULL DEFAULT 'false',
  updated   timestamptz   NOT NULL DEFAULT NOW()
);


