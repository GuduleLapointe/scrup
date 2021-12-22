/**
 * ScrupClient
 *
 * Insert the code inside the script you want to make auto-updatable (alongside
 * your own code)
 * - make sure to add scrup() command in state_entry(),
 *   for each state if you have more than "default" (and in on_rez and changed
 *   if you don't llResetScript() at these stages)
 * - update scrupURL with according to your web server config
 * - change the scrupPin number
 *
 * To distribute a new release:
 * - update the version variable
 * - rename the script with the version at the end (separated by a space)
 * - put a copy of the full script, non running, in the update server object
 *   (alongide ScrupServer script)
 */

string version = "1.0.0";

float rev = 7;
key clientKey;

// Do not change below unless you know what you're doing
integer scrupAllowUpdates = TRUE;
integer scrupPin = 56748;
string scrupURL = "http://dev.w4os.org/updater/scrup.php";
string scrupRequestID;

debug(string message) {
    llOwnerSay(message);
}

scrup() {
    if(!scrupAllowUpdates) return;
    if(version == "") return;

    list params = [ "loginURI=" + osGetGridLoginURI(), "action=register",
    "type=client", "scriptname=" + llGetScriptName(), "pin=" + scrupPin,
    "version=" + version ];
    scrupRequestID = llHTTPRequest(scrupURL, [HTTP_METHOD, "POST",
    HTTP_MIMETYPE, "application/x-www-form-urlencoded"],
    llDumpList2String(params, "&"));
    llSetRemoteScriptAccessPin(scrupPin);
}

default
{
    state_entry()
    {
        scrup();
    }

    on_rez(integer start_param)
    {
        scrup();
    }

    changed(integer change)
    {
        if(change & CHANGED_INVENTORY) {
            llResetScript();;
        }
    }
}
