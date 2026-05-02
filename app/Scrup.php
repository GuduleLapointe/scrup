<?php
/**
 * Scrup - LSL scripts auto-update
 *
 * @version    1.2.0
 * @author     Speculoos World
 * @license    AGPLv3
 * @link       https://github.com/GuduleLapointe/scrup
 */

namespace Scrup;

class Scrup
{
	const VERSION = "1.2.0";
	const SLUG = "scrup";

	/** ScrupClient version that introduced the linkkey parameter. */
	const LINKKEY_SINCE = "1.1.0";

	private ScrupDB $db;
	private string $dataDir;

	/**
	 * @param string|null $dataDir  Override the data directory (default: auto-resolved).
	 */
	public function __construct(?string $dataDir = null)
	{
		$this->dataDir = rtrim($dataDir ?? self::resolveDataDir(), "/");
		if (!file_exists($this->dataDir)) {
			mkdir($this->dataDir, 0755, true);
		}
		$this->db = new ScrupDB($this->dataDir . "/" . self::SLUG . ".db");
	}

	/**
	 * Resolve the data directory from the environment or server context.
	 *
	 * Priority:
	 *   1. DATA_DIR environment variable
	 *   2. dirname(DOCUMENT_ROOT)/data  — outside the web root
	 *   3. dirname(SCRIPT_FILENAME)/data
	 *   4. Fallback: system temp dir / scrup
	 */
	public static function resolveDataDir(): string
	{
		if ($dir = getenv("DATA_DIR")) {
			return rtrim($dir, "/");
		}
		if (!empty($_SERVER["DOCUMENT_ROOT"])) {
			return dirname(rtrim($_SERVER["DOCUMENT_ROOT"], "/")) . "/data";
		}
		if (!empty($_SERVER["SCRIPT_FILENAME"])) {
			$scriptDir = dirname(
				realpath($_SERVER["SCRIPT_FILENAME"]) ?:
				$_SERVER["SCRIPT_FILENAME"],
			);
			if ($scriptDir && $scriptDir !== ".") {
				return $scriptDir . "/data";
			}
		}
		return (ini_get("upload_tmp_dir") ?: sys_get_temp_dir()) .
			"/" .
			self::SLUG;
	}

	// -------------------------------------------------------------------------
	// HTTP response

	/**
	 * Send an HTTP response and terminate.
	 *
	 * For status 200 the body is the message only; for other statuses the body
	 * is prefixed with the status code (original Scrup wire format).
	 */
	public static function respond(int $status, string $message = ""): never
	{
		if (empty($message)) {
			$message = match ($status) {
				200 => "OK",
				400 => "Bad Request",
				403 => "Forbidden",
				404 => "Not Found",
				500 => "Internal Server Error",
				default => "Unknown Error",
			};
		}
		$body = ($status !== 200 ? "$status " : "") . trim($message) . PHP_EOL;
		// error_log("DEBUG Scrup $status $body");
		http_response_code($status);
		exit($body);
	}

	// -------------------------------------------------------------------------
	// Request validation

	/**
	 * Terminate with 400 if the request does not carry valid in-world SL headers.
	 */
	public static function inWorldOrDie(): void
	{
		if (
			empty($_SERVER["HTTP_X_SECONDLIFE_SHARD"] ?? "") ||
			empty($_SERVER["HTTP_X_SECONDLIFE_REGION"] ?? "") ||
			empty($_SERVER["HTTP_X_SECONDLIFE_OBJECT_KEY"] ?? "")
		) {
			self::respond(400, "Bad Request: missing SL in-world headers");
		}
	}

	/**
	 * Build a unique URI for the requesting in-world object.
	 *
	 * @return string  loginURI/Region/type/id-or-name
	 */
	public static function getObjectURI(): string
	{
		if (
			empty($_POST["loginURI"]) ||
			empty($_POST["type"]) ||
			empty($_POST["action"])
		) {
			self::respond(
				400,
				"Bad Request: missing loginURI, type, or action",
			);
		}

		$region = trim(
			explode("(", $_SERVER["HTTP_X_SECONDLIFE_REGION"] ?? "")[0],
		);
		$base = rtrim($_POST["loginURI"], "/") . "/" . $region;

		switch ($_POST["type"]) {
			case "server":
				return $base .
					"/" .
					self::SLUG .
					"/server/" .
					($_SERVER["HTTP_X_SECONDLIFE_OBJECT_KEY"] ?? "");

			case "client":
				$scriptname = preg_replace(
					'/ +[0-9._-]*$/',
					"",
					$_POST["scriptname"] ?? "",
				);
				$link =
					$_POST["linkkey"] ??
					($_SERVER["HTTP_X_SECONDLIFE_OBJECT_KEY"] ?? "");
				return $base . "/client/" . $link . "/" . $scriptname;

			case "script":
				if (!empty($_POST["name"])) {
					return $base . "/script/" . $_POST["name"];
				}
				self::respond(400, "Bad Request: missing script name");

			default:
				self::respond(
					400,
					"Bad Request: unknown type " . $_POST["type"],
				);
		}

		self::respond(400, "Bad Request");
	}

	// -------------------------------------------------------------------------
	// Business logic

	/**
	 * Return the current version of a script, or the Scrup server version string.
	 *
	 * - No params / empty params → server version ("Scrup X.Y.Z Server")
	 * - type=scrup               → server version
	 * - type=script without name → 400
	 * - name=<script>            → version from DB, or 404
	 */
	public function getVersion(?string $name, ?string $type): string
	{
		if ($type === "scrup" || empty(($name ?? "") . ($type ?? ""))) {
			return "Scrup " . self::VERSION . " Server";
		}
		if (empty($name)) {
			self::respond(400, "Bad Request: missing script name");
		}
		$stmt = $this->db->prepare(
			"SELECT version FROM scripts WHERE name = :name
			ORDER BY version DESC, lastseen DESC LIMIT 1",
		);
		$stmt->bindValue(":name", $name, SQLITE3_TEXT);
		$row = $stmt->execute()->fetchArray(SQLITE3_ASSOC);
		if (empty($row["version"])) {
			self::respond(404, "Script not found");
		}
		return $row["version"];
	}

	/**
	 * Register or refresh an in-world Scrup server.
	 */
	public function registerServer(string $uri): bool
	{
		self::inWorldOrDie();
		if (empty($uri)) {
			return false;
		}

		$stmt = $this->db->prepare("SELECT uri FROM servers WHERE uri = :uri");
		$stmt->bindValue(":uri", $uri, SQLITE3_TEXT);
		$found = $stmt->execute()->fetchArray();

		if (!$found) {
			$stmt = $this->db->prepare(
				"INSERT INTO servers (uri, lastseen) VALUES (:uri, CURRENT_TIMESTAMP)",
			);
		} else {
			$stmt = $this->db->prepare(
				"UPDATE servers SET lastseen = CURRENT_TIMESTAMP WHERE uri = :uri",
			);
		}
		$stmt->bindValue(":uri", $uri, SQLITE3_TEXT);
		if (!$stmt->execute()) {
			self::respond(500, "Could not save server $uri");
		}
		return true;
	}

	/**
	 * Register or update a script version.
	 *
	 * When the script is already known, outputs the list of out-of-date clients
	 * so the in-world server can push updates to them.
	 */
	public function registerScript(
		string $uri,
		string $name,
		string $version,
	): bool {
		self::inWorldOrDie();
		if (empty($uri)) {
			return false;
		}

		$stmt = $this->db->prepare("SELECT * FROM scripts WHERE uri = :uri");
		$stmt->bindValue(":uri", $uri, SQLITE3_TEXT);
		$found = $stmt->execute()->fetchArray(SQLITE3_ASSOC);

		if (!$found) {
			$stmt = $this->db->prepare(
				"INSERT INTO scripts (uri, name, version, lastseen)
				VALUES (:uri, :name, :version, CURRENT_TIMESTAMP)",
			);
			$stmt->bindValue(":uri", $uri, SQLITE3_TEXT);
			$stmt->bindValue(":name", $name, SQLITE3_TEXT);
			$stmt->bindValue(":version", $version, SQLITE3_TEXT);
			if (!$stmt->execute()) {
				self::respond(500, "Could not insert script $uri");
			}
		} else {
			$cmp = version_compare($version, $found["version"]);
			if ($cmp < 0) {
				self::respond(
					403,
					"A newer version {$found["version"]} already exists",
				);
			}
			if ($cmp > 0) {
				$stmt = $this->db->prepare(
					"UPDATE scripts SET lastseen = CURRENT_TIMESTAMP, version = :version
					WHERE uri = :uri",
				);
				$stmt->bindValue(":uri", $uri, SQLITE3_TEXT);
				$stmt->bindValue(":version", $version, SQLITE3_TEXT);
				if (!$stmt->execute()) {
					self::respond(500, "Could not update script $uri");
				}
			}

			// Output list of out-of-date clients for the server to push updates.
			// TODO: split output if the list grows too long.
			$stmt = $this->db->prepare(
				"SELECT * FROM clients WHERE scriptname = :name",
			);
			$stmt->bindValue(":name", $name, SQLITE3_TEXT);
			$clients = $stmt->execute();
			while ($client = $clients->fetchArray(SQLITE3_ASSOC)) {
				if (version_compare($client["version"], $version) < 0) {
					echo $client["uuid"] . " " . $client["pin"] . ",";
				}
			}
			echo "ENDLIST";
		}
		return true;
	}

	/**
	 * Register or refresh a script client (stores key and pin for update delivery).
	 *
	 * The response is intentionally minimal — the client script ignores it to
	 * keep the ScrupClient include as lightweight as possible.
	 */
	public function registerClient(
		string $uri,
		string $link,
		string $version,
		string $pin,
	): bool {
		self::inWorldOrDie();
		if (empty($uri)) {
			return false;
		}

		if (empty($link)) {
			// Backward compat: clients before LINKKEY_SINCE didn't send linkkey;
			// fall back to the object key from SL headers.
			if (
				isset($_POST["scrupVersion"]) &&
				version_compare($_POST["scrupVersion"], self::LINKKEY_SINCE) < 0
			) {
				$link = $_SERVER["HTTP_X_SECONDLIFE_OBJECT_KEY"] ?? "";
			} else {
				self::respond(
					400,
					"Missing link key (client version $version)",
				);
			}
		}
		if (empty($pin)) {
			self::respond(400, "No pin, no service");
		}
		if (empty($version)) {
			self::respond(400, "No version, no service");
		}

		$stmt = $this->db->prepare("SELECT uri FROM clients WHERE uri = :uri");
		$stmt->bindValue(":uri", $uri, SQLITE3_TEXT);
		$found = $stmt->execute()->fetchArray();

		if (!$found) {
			$scriptname = basename($uri);
			$stmt = $this->db->prepare(
				"INSERT INTO clients (uri, uuid, scriptname, version, pin, lastseen)
				VALUES (:uri, :uuid, :scriptname, :version, :pin, CURRENT_TIMESTAMP)",
			);
			$stmt->bindValue(":uri", $uri, SQLITE3_TEXT);
			$stmt->bindValue(":uuid", $link, SQLITE3_TEXT);
			$stmt->bindValue(":scriptname", $scriptname, SQLITE3_TEXT);
			$stmt->bindValue(":version", $version, SQLITE3_TEXT);
			$stmt->bindValue(":pin", $pin, SQLITE3_TEXT);
		} else {
			$stmt = $this->db->prepare(
				"UPDATE clients SET lastseen = CURRENT_TIMESTAMP,
				version = :version, pin = :pin WHERE uri = :uri",
			);
			$stmt->bindValue(":version", $version, SQLITE3_TEXT);
			$stmt->bindValue(":pin", $pin, SQLITE3_TEXT);
			$stmt->bindValue(":uri", $uri, SQLITE3_TEXT);
		}
		if (!$stmt->execute()) {
			self::respond(500, "Could not save client $uri");
		}
		return true;
	}

	// -------------------------------------------------------------------------
	// Logging

	/** Append a debug message to the Scrup log file. */
	private function debug(string $message): void
	{
		if (empty($message)) {
			return;
		}
		file_put_contents(
			$this->dataDir . "/" . self::SLUG . ".log",
			$message . PHP_EOL,
			FILE_APPEND,
		);
	}
}
