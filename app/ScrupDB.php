<?php
/**
 * Scrup SQLite database.
 *
 * Stores runtime data only (servers, scripts, clients). The database is
 * essentially a cache: it can be deleted at any time with no lasting harm.
 *
 * @package Scrup
 */

namespace Scrup;

class ScrupDB extends \SQLite3
{
	public function __construct(string $dbFile)
	{
		$this->open($dbFile);
		$this->createTables();
	}

	/** Create missing tables. Existing tables are left untouched. */
	private function createTables(): void
	{
		foreach ($this->schema() as $table => $sql) {
			if (!$this->querySingle(
				"SELECT name FROM sqlite_master WHERE type='table' AND name='$table'",
			)) {
				if (!$this->exec($sql)) {
					throw new \RuntimeException("Scrup: could not create table $table");
				}
			}
		}
	}

	/** @return array<string, string>  table name → CREATE TABLE statement */
	private function schema(): array
	{
		return [
			"servers" => "CREATE TABLE servers (
				uri      TEXT PRIMARY KEY,
				created  DATETIME DEFAULT CURRENT_TIMESTAMP,
				lastseen DATETIME
			)",
			"scripts" => "CREATE TABLE scripts (
				uri      TEXT PRIMARY KEY,
				name     TEXT,
				version  TEXT,
				created  DATETIME DEFAULT CURRENT_TIMESTAMP,
				lastseen DATETIME
			)",
			"clients" => "CREATE TABLE clients (
				uri        TEXT PRIMARY KEY,
				uuid       TEXT,
				scriptname TEXT,
				version    TEXT,
				pin        INTEGER,
				created    DATETIME DEFAULT CURRENT_TIMESTAMP,
				lastseen   DATETIME
			)",
		];
	}
}
