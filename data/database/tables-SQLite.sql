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

CREATE TABLE pending(
  id              INTEGER          PRIMARY KEY AUTOINCREMENT,
  ip              VARCHAR(15)      NOT NULL DEFAULT '0.0.0.0',
  beaconport      INTEGER          NOT NULL DEFAULT 0,
  heartbeat       INTEGER          NOT NULL DEFAULT 0,
  gamename        VARCHAR(25)      NOT NULL DEFAULT ' ',  
  secure          VARCHAR(12)      NOT NULL DEFAULT ' ',
  enctype         INTEGER          NOT NULL DEFAULT 0,
  added           timestamptz      NOT NULL DEFAULT CURRENT_TIMESTAMP
);
