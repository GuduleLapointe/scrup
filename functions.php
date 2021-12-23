<?php if(!SCRUP_SLUG) die("I won't be called immediately");

function debug($message) {
  if(empty($message)) return;
  file_put_contents(
    SCRUP_LOG,
    $message . "\n",
    FILE_APPEND
  );
}

function scrupDie($status = 200, $message = "") {
  debug("$status $message");
  http_response_code($status);
  die($message);
}

function getObjectURI() {
  if(empty($_POST['loginURI']) || empty($_POST['type']) || empty($_POST['action']) || empty(getenv('HTTP_X_SECONDLIFE_REGION')) || empty(getenv('HTTP_X_SECONDLIFE_OBJECT_KEY')) || empty(getenv('HTTP_X_SECONDLIFE_OBJECT_KEY'))) scrupDie(400, 'Bad Request');
  $region = trim(explode('(', getenv('HTTP_X_SECONDLIFE_REGION'))[0]);
  switch($_POST['type']) {
    case 'server':
    return $_POST['loginURI'] . $region . '/' . SCRUP_SLUG . '/server/' . getenv('HTTP_X_SECONDLIFE_OBJECT_KEY');
    break;

    case 'client':
    $scriptname = preg_replace('/ +[0-9\._-]*$/', '', $_POST['scriptname']);
    return $_POST['loginURI'] . $region . '/client/' . $_POST['linkkey'] . '/' . $scriptname;
    break;

    case 'script':
    if(isset($_POST['name']))
    return $_POST['loginURI'] . $region . '/script/' . $_POST['name'];
    break;

    default:
    scrupDie(400, 'Unknown type');
  }
  if(empty($region)) return false;
}

function registerServer($uri) {
  global $scrupdb;

  // $uri = getObjectURI();
  if(empty($uri)) return false;
  if(!$uri) return false;

  $found = $scrupdb->query("SELECT * FROM servers WHERE uri='$uri';")->fetchArray();
  debug('found ' . print_r($found, true));

  if(!$found) {
    if(! $scrupdb->exec("INSERT INTO servers (uri, lastseen) values('$uri', CURRENT_TIMESTAMP);"))
    scrupDie(500, "could not insert server $uri");
  } else {
    if(! $scrupdb->exec("UPDATE servers SET lastseen = CURRENT_TIMESTAMP WHERE uri = '$uri'"))
    scrupDie(500, "could not update server $uri");
  }
  return true;
}

function registerScript($uri, $name, $version) {
  global $scrupdb;

  // $uri = getObjectURI();
  if(empty($uri)) return false;
  if(!$uri) return false;

  $found = $scrupdb->query("SELECT * FROM scripts WHERE uri='$uri';")->fetchArray();
  // debug('found ' . print_r($found, true));

  if(!$found) {
    if(! $scrupdb->exec("INSERT INTO scripts (uri, name, version, lastseen) values('$uri', '$name', '$version', CURRENT_TIMESTAMP);"))
    scrupDie(500, "could not insert script $uri");
  } else {
    $status = version_compare($version, $found['version']);
    if($status < 0) scrupDie(403, "A newer version ${found['version']} already exists");
    else if($status > 0) {
      if(! $scrupdb->exec("UPDATE scripts SET lastseen = CURRENT_TIMESTAMP, version='$version' WHERE uri = '$uri'"))
      scrupDie(500, "could not update script $uri");
    }

    // Get out of date clients
    // clients (uri, uuid, scriptname, version, pin, lastseen

    $clients = $scrupdb->query("SELECT * FROM clients WHERE scriptname = '$name';");
    while($client = $clients->fetchArray()) {
      // TODO: split if list is too long
      if(version_compare($client['version'], $version) < 0)
      echo $client['uuid'] . ' ' . $client['pin'] . ',';
    }
    echo "ENDLIST";

    // debug('data ' . print_r($found, true));
  }
  return true;
}

function registerclient($uri, $link, $version, $pin) {
  global $scrupdb;

  // $uri = getObjectURI();
  if(empty($uri)) return false;
  if(empty($link)) scrupDie('400', "The missing link key");
  if(empty($pin)) scrupDie('400', "No pin, no service");
  if(empty($version)) scrupDie('400', "No version, no service");
  if(!$uri) return false;

  $found = $scrupdb->query("SELECT * FROM clients WHERE uri='$uri';")->fetchArray();
  // debug('found ' . print_r($found, true));

  if(!$found) {
    $scriptname = basename($uri);
    if(! $scrupdb->exec("INSERT INTO clients (uri, uuid, scriptname, version, pin, lastseen)
    values('$uri', '$link', '$scriptname', '$version', $pin, CURRENT_TIMESTAMP);"))
    scrupDie(500, "could not insert client $uri");
  } else {
    if(! $scrupdb->exec("UPDATE clients SET lastseen = CURRENT_TIMESTAMP, version='$version' WHERE uri = '$uri'"))
    scrupDie(500, "could not update client $uri");
  }
  return true;
}


// "loginURI=" + osGetGridLoginURI(),
// "action=register",
// "type=client",
// "name=" + llGetScriptName(), // or the name of another script in this prim
// "pin=" + scrupPin,
// "version=" + version
