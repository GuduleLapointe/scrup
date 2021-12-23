<?php if(!SCRUP_SLUG) die("I won't be called immediately");

/**
 * SQLite3 database, used for cache only and filled automatically.
 * Can be deleted anytime.
 */
class ScrupDB extends SQLite3
{
  function __construct()
  {
    $this->open(SCRUP_DBFILE);
    $this->checktables();
  }

  private function checktables() {
    $tablesquery = $this->query("SELECT name FROM sqlite_master WHERE type='table';");

    $this->addTable('servers', "CREATE TABLE servers (
      uri TEXT PRIMARY KEY,
      created DATETIME DEFAULT CURRENT_TIMESTAMP,
      lastseen DATETIME
    );");

    $this->addTable('scripts', "CREATE TABLE scripts (
      uri TEXT PRIMARY KEY,
      name TEXT,
      version TEXT,
      created DATETIME DEFAULT CURRENT_TIMESTAMP,
      lastseen DATETIME
    );");

    $this->addTable('clients', "CREATE TABLE clients (
      uri TEXT PRIMARY KEY,
      uuid TEXT,
      scriptname TEXT,
      version TEXT,
      pin INTEGER,
      created DATETIME DEFAULT CURRENT_TIMESTAMP,
      lastseen DATETIME
    );");
  }

  private function addTable($table, $sql) {
    $result = $this->query("SELECT name FROM sqlite_master WHERE type='table' AND name='$table';")->fetchArray();
    if($result) return;

    $result = $this->exec($sql);
    if($result) {
      debug("table $table created");
      return;
    } else {
      debug('error creating table');
      scrupDie(500);
    }
  }
}

$scrupdb = new ScrupDB();
if(!$scrupdb) scrupDie(500, 'Could not access database');
