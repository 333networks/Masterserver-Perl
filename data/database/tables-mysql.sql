CREATE TABLE serverlist(
  id              INTEGER          NOT NULL AUTO_INCREMENT,
  ip              VARCHAR(15)      NOT NULL DEFAULT '0.0.0.0',
  port            INTEGER          NOT NULL DEFAULT 0,
  gamename        VARCHAR(100)     NOT NULL DEFAULT ' ',
  gamever         VARCHAR(50)      NOT NULL DEFAULT ' ',
  hostname        VARCHAR(100)     NOT NULL DEFAULT ' ',
  hostport        INTEGER          NOT NULL DEFAULT 0,
  country         VARCHAR(5),
  b333ms          BOOLEAN          NOT NULL DEFAULT 0,
  blacklisted     BOOLEAN          NOT NULL DEFAULT 0,
  added           TIMESTAMP        NOT NULL DEFAULT NOW(),
  beacon          TIMESTAMP        NOT NULL DEFAULT NOW(),
  updated         TIMESTAMP        NOT NULL DEFAULT NOW(),
  PRIMARY KEY (id)
);

CREATE TABLE pending(
  id              INTEGER          NOT NULL AUTO_INCREMENT,
  ip              VARCHAR(15)      NOT NULL DEFAULT '0.0.0.0',
  beaconport      INTEGER          NOT NULL DEFAULT 0,
  heartbeat       INTEGER          NOT NULL DEFAULT 0,
  gamename        VARCHAR(25)      NOT NULL DEFAULT ' ',  
  secure          VARCHAR(12)      NOT NULL DEFAULT ' ',
  enctype         INTEGER          NOT NULL DEFAULT 0,
  added           TIMESTAMP        NOT NULL DEFAULT NOW(),
  PRIMARY KEY (id)
);