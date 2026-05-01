<?php
if (!SCRUP_SLUG) {
	die("I won't be called directly");
}

function debug($message)
{
	if (empty($message)) {
		return;
	}
	file_put_contents(SCRUP_LOG, $message . "\n", FILE_APPEND);
}

function scrupDie(?int $status, string $message = "")
{
	if (empty($message)) {
		switch ($status) {
			case 200:
				$message = "OK";
				break;
			case 400:
				$message = "Bad Request";
				break;
			case 403:
				$message = "Forbidden";
				break;
			case 404:
				$message = "Not Found";
				break;
			case 500:
				$message = "Internal Server Error";
				break;
			default:
				$message = "Unknown Error";
				break;
		}
	}
	$message = ($status != 200 ? "$status " : "") . trim($message) . PHP_EOL;
	error_log("$status $message");
	if (!empty($status)) {
		http_response_code($status);
	}
	die($message);
}

/**
 * Unique identifier for each object requesting registration (server, script, client)
 * @return string http://login.uri:port/[Region/]type/id-or-name
 */
function getObjectURI()
{
	if (
		empty($_POST["loginURI"]) ||
		empty($_POST["type"]) ||
		empty($_POST["action"])
	) {
		scrupDie(400, "Bad Request: missing loginURI, type, or action");
	}
	$region = trim(explode("(", getenv("HTTP_X_SECONDLIFE_REGION"))[0]);
	switch ($_POST["type"]) {
		case "server":
			return $_POST["loginURI"] .
				$region .
				"/" .
				SCRUP_SLUG .
				"/server/" .
				getenv("HTTP_X_SECONDLIFE_OBJECT_KEY");
			break;

		case "client":
			$scriptname = preg_replace(
				'/ +[0-9\._-]*$/',
				"",
				$_POST["scriptname"],
			);
			if (isset($_POST["linkkey"])) {
				$link = $_POST["linkkey"];
			} else {
				$link = getenv("HTTP_X_SECONDLIFE_OBJECT_KEY");
			}
			return $_POST["loginURI"] .
				$region .
				"/client/" .
				$link .
				"/" .
				$scriptname;
			break;

		case "script":
			if (isset($_POST["name"])) {
				return $_POST["loginURI"] .
					$region .
					"/script/" .
					$_POST["name"];
			}
			break;

		default:
			scrupDie(400, "Bad Request: unknown type {$_POST["type"]}");
	}
	if (empty($region)) {
		return false;
	}
}

/**
 * Output the version of a script by name
 */
function getVersion($name = null, $type = "script")
{
	if (empty($name)) {
		scrupDie(400, "Bad Request: missing {$type} name");
	}

	global $scrupdb;

	$stmt = $scrupdb->prepare(
		"SELECT version FROM scripts WHERE name = :name
    	ORDER BY version DESC, lastseen DESC LIMIT 1;",
	);
	$stmt->bindValue(":name", $name, SQLITE3_TEXT);
	$row = $stmt->execute()->fetchArray(SQLITE3_ASSOC);

	if (!$row) {
		scrupDie(404, "Script not found");
	}

	scrupDie(200, $row["version"]);
}

/**
 * Process server registration request
 * @param  string $uri  object identifier set by getObjectURI()
 * @return boolean      true if OK, die with HTTP response code on errors
 */
function registerServer($uri)
{
	inWorldOrDie();
	global $scrupdb;

	// $uri = getObjectURI();
	if (empty($uri)) {
		return false;
	}
	if (!$uri) {
		return false;
	}

	$stmt = $scrupdb->prepare("SELECT * FROM servers WHERE uri=:uri;");
	$stmt->bindValue(":uri", $uri, SQLITE3_TEXT);
	$found = $stmt->execute()->fetchArray();

	debug("found " . print_r($found, true));
	if (!$found) {
		$stmt = $scrupdb->prepare(
			"INSERT INTO servers (uri, lastseen) values(:uri, CURRENT_TIMESTAMP);",
		);
		$stmt->bindValue(":uri", $uri, SQLITE3_TEXT);
		if (!$stmt->execute()) {
			scrupDie(500, "could not insert server $uri");
		}
	} else {
		$stmt = $scrupdb->prepare(
			"UPDATE servers SET lastseen = CURRENT_TIMESTAMP WHERE uri = :uri",
		);
		$stmt->bindValue(":uri", $uri, SQLITE3_TEXT);
		if (!$stmt->execute()) {
			scrupDie(500, "could not update server $uri");
		}
	}
	return true;
}

/**
 * Process script registration request sent by the server
 * Output list if client UUIDs needing an update
 * @param  string $uri  object identifier set by getObjectURI()
 * @return boolean      true if OK, die with HTTP response code on errors
 */
function registerScript($uri, $name, $version)
{
	inWorldOrDie();
	global $scrupdb;

	// $uri = getObjectURI();
	if (empty($uri)) {
		return false;
	}
	if (!$uri) {
		return false;
	}

	$found = $scrupdb
		->query("SELECT * FROM scripts WHERE uri='$uri';")
		->fetchArray();
	// debug('found ' . print_r($found, true));

	if (!$found) {
		$stmt = $scrupdb->prepare(
			"INSERT INTO scripts (uri, name, version, lastseen) values(:uri, :name, :version, CURRENT_TIMESTAMP);",
		);
		$stmt->bindValue(":uri", $uri, SQLITE3_TEXT);
		$stmt->bindValue(":name", $name, SQLITE3_TEXT);
		$stmt->bindValue(":version", $version, SQLITE3_TEXT);
		if (!$stmt->execute()) {
			scrupDie(500, "could not insert script $uri");
		}
	} else {
		$status = version_compare($version, $found["version"]);
		if ($status < 0) {
			scrupDie(403, "A newer version {$found["version"]} already exists");
		} elseif ($status > 0) {
			$stmt = $scrupdb->prepare(
				"UPDATE scripts SET lastseen = CURRENT_TIMESTAMP, version=:version WHERE uri = :uri",
			);
			$stmt->bindValue(":uri", $uri, SQLITE3_TEXT);
			$stmt->bindValue(":version", $version, SQLITE3_TEXT);
			if (!$stmt->execute()) {
				scrupDie(500, "could not update script $uri");
			}
		}

		// Get out of date clients
		// clients (uri, uuid, scriptname, version, pin, lastseen

		$stmt = $scrupdb->prepare(
			"SELECT * FROM clients WHERE scriptname = :name;",
		);
		$stmt->bindValue(":name", $name, SQLITE3_TEXT);
		$clients = $stmt->execute();
		while ($client = $clients->fetchArray()) {
			// TODO: split if list is too long
			if (version_compare($client["version"], $version) < 0) {
				echo $client["uuid"] . " " . $client["pin"] . ",";
			}
		}
		echo "ENDLIST";

		// debug('data ' . print_r($found, true));
	}
	return true;
}

/**
 * Process client (script) registration. Store client key and pin to deliver
 * when server request updates.
 * The output is ignored by the client script, to keep the code to include as
 * small as possible.
 * @param  string $uri  object  identifier set by getObjectURI()
 * @param  string $link  link key (version) set by the client
 * @param  string $version      current version installed on client
 * @param  integer $pin          pin (update authorisation code) set by the client
 * @return boolean      true if OK, die with HTTP response code on errors
 */
function registerClient($uri, $link, $version, $pin)
{
	inWorldOrDie();

	global $scrupdb;

	if (empty($uri)) {
		return false;
	}
	if (empty($link)) {
		if (
			isset($_POST["scrupVersion"]) &&
			version_compare($_POST["scrupVersion"], "1.1.0") < 0
		) {
			$link = getenv("HTTP_X_SECONDLIFE_OBJECT_KEY");
		} else {
			scrupDie(400, "The missing link key ($version)");
		}
	}
	if (empty($pin)) {
		scrupDie(400, "No pin, no service");
	}
	if (empty($version)) {
		scrupDie(400, "No version, no service");
	}
	if (!$uri) {
		return false;
	}

	$found = $scrupdb
		->query("SELECT * FROM clients WHERE uri='$uri';")
		->fetchArray();
	// debug('found ' . print_r($found, true));

	if (!$found) {
		$scriptname = basename($uri);
		$stmt = $scrupdb->prepare(
			"INSERT INTO clients (uri, uuid, scriptname, version, pin, lastseen)
    values(:uri, :uuid, :scriptname, :version, :pin, CURRENT_TIMESTAMP);",
		);
		$stmt->bindValue(":uri", $uri, SQLITE3_TEXT);
		$stmt->bindValue(":uuid", $link, SQLITE3_TEXT);
		$stmt->bindValue(":scriptname", $scriptname, SQLITE3_TEXT);
		$stmt->bindValue(":version", $version, SQLITE3_TEXT);
		$stmt->bindValue(":pin", $pin, SQLITE3_TEXT);
		if (!$stmt->execute()) {
			scrupDie(500, "could not insert client $uri");
		}
	} else {
		$stmt = $scrupdb->prepare(
			"UPDATE clients SET lastseen = CURRENT_TIMESTAMP, version=:version, pin=:pin WHERE uri = :uri",
		);
		$stmt->bindValue(":version", $version, SQLITE3_TEXT);
		$stmt->bindValue(":pin", $pin, SQLITE3_TEXT);
		$stmt->bindValue(":uri", $uri, SQLITE3_TEXT);
		if (!$stmt->execute()) {
			scrupDie(500, "could not update client $uri");
		}
	}
	return true;
}

/**
 * Reject requests that are not coming from in-world scripts
 *
 * This function should be called at the start of any function relying on
 * in-world script context.
 *
 * @return void
 */
function inWorldOrDie()
{
	// if (!$_SERVER["HTTP_X_SECONDLIFE_SHARD"]) {
	if (
		empty(getenv("HTTP_X_SECONDLIFE_SHARD")) ||
		empty(getenv("HTTP_X_SECONDLIFE_REGION")) ||
		empty(getenv("HTTP_X_SECONDLIFE_OBJECT_KEY"))
	) {
		scrupDie(
			400,
			"Bad Request: missing HTTP_X_SECONDLIFE_SHARD, HTTP_X_SECONDLIFE_REGION, or HTTP_X_SECONDLIFE_OBJECT_KEY",
		);
	}
}
