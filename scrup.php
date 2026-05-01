<?php
/**
 * Scrup - LSL scripts auto-update
 *
 * Version: 1.0.3
 * Author: Speculoos World
 * GitHub URI: https://github.com/GuduleLapointe/scrup
 * Requires PHP: 5.5
 * Donate link: https://paypal.me/magicoli
 *
 * This is the web registration part of Scrup ecosystem.
 * It requires ScrupServer script to run in-world,
 * and ScrupClient to be included in auto-updating scripts.
 *
 * License:           AGPLv3
 * License URI:       https://www.gnu.org/licenses/agpl-3.0.txt
 */

namespace Scrup;

if (file_exists("config.php")) {
	include "config.php";
}

define("SCRUP_SLUG", "scrup");
define(
	"SCRUP_TMP",
	(ini_get("upload_tmp_dir") ?: sys_get_temp_dir()) . "/" . __NAMESPACE__,
);
if (!file_exists(SCRUP_TMP)) {
	mkdir(SCRUP_TMP, 0777, true);
}
error_log("SCRUP_TMP: " . SCRUP_TMP);

define("SCRUP_LOG", SCRUP_TMP . "/" . SCRUP_SLUG . ".log");

// define('SCRUP_DBFILE', SCRUP_SLUG  . '.db');

require "functions.php";
require "sqlite.php";

$action = $_REQUEST["action"] ?? "";
$type = $_REQUEST["type"] ?? "";
switch ("$action-$type") {
	case "register-server":
		$serverURI = getObjectURI();
		if (!registerServer($serverURI)) {
			scrupDie(403, "Could not register server $serverURI");
		}
		break;

	case "register-script":
		$scriptURI = getObjectURI();
		debug("script $scriptURI");
		if (
			!registerScript(
				$scriptURI,
				$_POST["name"] ?? "",
				$_POST["version"] ?? "",
			)
		) {
			scrupDie(400, "Could not register script $scriptURI");
		}
		break;

	case "register-client":
		$clientURI = getObjectURI();
		debug("client $clientURI");
		// debug(print_r($_POST));
		if (
			!registerClient(
				$clientURI,
				$_POST["linkkey"] ?? "",
				$_POST["version"] ?? "",
				$_POST["pin"] ?? "",
			)
		) {
			scrupDie(400, "Could not register client $clientURI");
		}
		break;

	case "get-version-": // defaults to script
	case "get-version-script":
		getVersion($_REQUEST["name"] ?? "");
		break;

	default:
		scrupDie(
			400,
			"Bad Request: unknown action/type combination $action-$type",
		);
}
