<?php
/**
 * Scrup - LSL scripts auto-update
 *
 * Version: 1.0.1
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

if(!$_SERVER['HTTP_X_SECONDLIFE_SHARD']) {
  // We only want to be called by in-world scripts
  header('HTTP/1.0 400 Bad Request', true, 400);
  die();
};

define('SCRUP_SLUG', 'scrup');
define('SCRUP_TMP', ini_get('upload_tmp_dir') ? ini_get('upload_tmp_dir') : sys_get_temp_dir());
define('SCRUP_LOG', SCRUP_TMP . '/' . SCRUP_SLUG  . '.log');
define('SCRUP_DBFILE', SCRUP_TMP . '/' . SCRUP_SLUG  . '.db');
// define('SCRUP_DBFILE', SCRUP_SLUG  . '.db');

if(file_exists('config.php')) include('config.php');
require('functions.php');
require('sqlite.php');

$action = $_POST['action'];
$type =  $_POST['type'];
switch("$action-$type") {
  case 'register-server':
  $serverURI = getObjectURI();
  if(!registerServer($serverURI)) {
    scrupDie(403, "Could not register server $serverURI");
  }
  break;

  case 'register-script':
  $scriptURI = getObjectURI();
  debug("script $scriptURI");
  if(!registerScript($scriptURI, $_POST['name'], $_POST['version'])) {
    scrupDie(400, "Could not register script $scriptURI");
  }
  break;

  case 'register-client':
  $clientURI = getObjectURI();
  debug("client $clientURI");
  debug(print_r($_POST));
  if(!registerClient($clientURI, $_POST['linkkey'], $_POST['version'], $_POST['pin'])) {
    scrupDie(400, "Could not register client $clientURI");
  }
  break;

  default:
  scrupDie(400, "unknown action $action-$type");
}
