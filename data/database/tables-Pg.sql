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

CREATE TABLE games(
  gamename        VARCHAR(50)        NOT NULL,
  cipher          VARCHAR(10)        NOT NULL DEFAULT ' ',
  description     VARCHAR(200)       NOT NULL DEFAULT ' ',
  default_qport   INTEGER            NOT NULL DEFAULT 0,
  num_uplink      INTEGER            NOT NULL DEFAULT 0,
  num_total       INTEGER            NOT NULL DEFAULT 0
);
