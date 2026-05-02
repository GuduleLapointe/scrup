<?php
/**
 * Scrup HTTP dispatcher
 *
 * Entry point for direct web requests. Loads the Scrup class (via Composer
 * autoload if available, or directly otherwise), reads action/type from the
 * request, and dispatches to the appropriate method.
 *
 * @version 1.2.0
 * @license AGPLv3
 * @link    https://github.com/GuduleLapointe/scrup
 */

namespace Scrup;

if (file_exists(__DIR__ . "/vendor/autoload.php")) {
	require_once __DIR__ . "/vendor/autoload.php";
} else {
	require_once __DIR__ . "/app/ScrupDB.php";
	require_once __DIR__ . "/app/Scrup.php";
}

// Optional local config — may define DATA_DIR or other settings.
if (file_exists(__DIR__ . "/config.php")) {
	include __DIR__ . "/config.php";
}

$scrup = new Scrup(defined("DATA_DIR") ? DATA_DIR : null);

$action = $_REQUEST["action"] ?? "";
$type = $_REQUEST["type"] ?? "";

switch ("$action-$type") {
	case "register-server":
		$uri = Scrup::getObjectURI();
		if (!$scrup->registerServer($uri)) {
			Scrup::respond(403, "Could not register server $uri");
		}
		break;

	case "register-script":
		$uri = Scrup::getObjectURI();
		if (
			!$scrup->registerScript(
				$uri,
				$_POST["name"] ?? "",
				$_POST["version"] ?? "",
			)
		) {
			Scrup::respond(400, "Could not register script $uri");
		}
		break;

	case "register-client":
		$uri = Scrup::getObjectURI();
		if (
			!$scrup->registerClient(
				$uri,
				$_POST["linkkey"] ?? "",
				$_POST["version"] ?? "",
				$_POST["pin"] ?? "",
			)
		) {
			Scrup::respond(400, "Could not register client $uri");
		}
		break;

	case "get-version-": // no type param — defaults to server version
	case "get-version-script":
	case "get-version-scrup":
		$version = $scrup->getVersion(
			$_REQUEST["name"] ?? null,
			$_REQUEST["type"] ?? null,
		);
		Scrup::respond(200, $version);
		break;

	default:
		Scrup::respond(
			400,
			"Bad Request: unknown action/type combination $action/$type",
		);
}
