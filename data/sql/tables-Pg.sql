CREATE TABLE appletlist(
  id              SERIAL UNIQUE NOT NULL PRIMARY KEY,
  ip              inet          NOT NULL,
  hostport        INTEGER       NOT NULL,
  gamename        TEXT          NOT NULL DEFAULT '',
  added           timestamptz   NOT NULL DEFAULT NOW(),
  updated         timestamptz   NOT NULL DEFAULT NOW()
);

CREATE TABLE serverlist(
  id          SERIAL UNIQUE NOT NULL PRIMARY KEY,
  ip          inet          NOT NULL,
  port        INTEGER       NOT NULL DEFAULT 0,
  gamename    TEXT          NOT NULL DEFAULT '',
  gamever     TEXT,
  hostname    TEXT,
  hostport    INTEGER       DEFAULT 0,
  country     TEXT,
  b333ms      BOOLEAN       DEFAULT FALSE,
  blacklisted BOOLEAN       DEFAULT FALSE,
  added       timestamptz   NOT NULL DEFAULT NOW(),
  beacon      timestamptz   NOT NULL DEFAULT NOW(),
  updated     timestamptz   NOT NULL DEFAULT NOW()
);
CREATE INDEX pendingaddress ON serverlist(ip, port);
CREATE INDEX updateaddress  ON serverlist(ip, hostport);
CREATE INDEX directbeacons  ON serverlist(gamename, b333ms);

CREATE TABLE games(
  gamename        TEXT NOT NULL,
  cipher          TEXT,
  description     TEXT,
  default_qport   INTEGER DEFAULT 0,
  num_uplink      INTEGER DEFAULT 0,
  num_total       INTEGER DEFAULT 0
);
CREATE INDEX gameprops ON games(gamename);

CREATE TABLE pending(
  id        SERIAL UNIQUE NOT NULL PRIMARY KEY,
  ip        inet          NOT NULL,
  heartbeat INTEGER       NOT NULL DEFAULT 0,
  added     timestamptz   NOT NULL DEFAULT NOW()
);

CREATE TABLE extended_info(
  server_id           SERIAL REFERENCES serverlist(id),
  minnetver           TEXT,
  location            TEXT,
  listenserver        TEXT,
  adminname           TEXT,
  adminemail          TEXT,
  password            TEXT,
  gametype            TEXT,
  gamestyle           TEXT,
  changelevels        TEXT,
  maptitle            TEXT,
  mapname             TEXT,
  numplayers          INTEGER DEFAULT 0,
  maxplayers          INTEGER DEFAULT 0,
  minplayers          INTEGER DEFAULT 0,
  botskill            TEXT,
  balanceteams        TEXT,
  playersbalanceteams TEXT,
  friendlyfire        TEXT,
  maxteams            TEXT,
  timelimit           TEXT,
  goalteamscore       TEXT,
  fraglimit           TEXT,
  mutators            TEXT DEFAULT 'None',
  updated      timestamptz NOT NULL DEFAULT NOW()
);

CREATE TABLE player_info(
  server_id SERIAL  NOT NULL,
  player    TEXT    DEFAULT 'Player',
  team      TEXT,
  frags     INTEGER DEFAULT 0,
  mesh      TEXT,
  skin      TEXT,
  face      TEXT,
  ping      INTEGER DEFAULT 0,
  ngsecret  TEXT,
  updated   timestamptz NOT NULL DEFAULT NOW()
);

CREATE TABLE kfstats(
  UTkey             TEXT    NOT NULL,
  Username          TEXT    DEFAULT ' ',
  CurrentVeterancy  TEXT    DEFAULT 'None',
  TotalKills        INTEGER NOT NULL DEFAULT 0,
  DecaptedKills     INTEGER NOT NULL DEFAULT 0,
  TotalMeleeDamage  INTEGER NOT NULL DEFAULT 0,
  MeleeKills        INTEGER NOT NULL DEFAULT 0,
  PowerWpnKills     INTEGER NOT NULL DEFAULT 0,
  BullpupDamage     INTEGER NOT NULL DEFAULT 0,
  StalkerKills      INTEGER NOT NULL DEFAULT 0,
  TotalWelded       INTEGER NOT NULL DEFAULT 0,
  TotalHealed       INTEGER NOT NULL DEFAULT 0,
  TotalPlaytime     INTEGER NOT NULL DEFAULT 0,
  GamesWon          INTEGER NOT NULL DEFAULT 0,
  GamesLost         INTEGER NOT NULL DEFAULT 0
);
