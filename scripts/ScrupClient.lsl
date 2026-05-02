/**
 * ScrupClient
 *
 * @Package: Scrup
 * @Author: Gudule Lapointe <gudule@speculoos.world>
 * @URL: https://github.com/GuduleLapointe/scrup
 *
 * Insert this code inside your own script.
 *
 * In initial parameters below, set scrupURL. Use the REST API base URL
 * (e.g. https://example.com/api/v3/scrup) for a current installation, or
 * the legacy direct URL (e.g. https://example.com/scrup/scrup.php) for older
 * installations. The script detects the style automatically.
 *
 * At the beginning of the scrup() function, uncomment only the loginURI line
 * matching your platform. It won't work with a wrong value!
 *
 * - call scrup(TRUE) in default state_entry() and in on_rez() if you don't
 *   llResetScript() there
 * - if your script uses multiple states, you may want to call scrup(FALSE) in
 *   states where you don't want updates (they would restart the script)
 * - if you need custom settings, do not store them in your live script (they
 *   would be overwritten at each update); use the object description or a
 *   notecard instead
 *
 * To push a new release:
 * - update the version by renaming the script (semantic version x.y.z at the
 *   end, with a space before)
 * - put a copy of the script, non running, in the update server object
 *   (alongside ScrupServer script)
 */

debug(string message) {
    // llOwnerSay("/me " + llGetScriptName() + ": " + message);
}

string version; // Leave empty or match version in script name

string scrupURL = ""; // Leave empty to use API update server
integer scrupAllowUpdates = TRUE; // set to FALSE only for debugging
integer scrupSayVersion = TRUE; // announces version to owner after start or update
integer scrupPin = 56748;
string scrupRequestID; // set dynamically, used in http_response handler

scrup(integer enable) {
    // Uncomment the loginURI for your platform, comment or delete the other
    string loginURI = osGetGridLoginURI();  // If in OpenSimulator
    // string loginURI = "secondlife://";   // If in Second Life

    string scrupVersion = "1.2.0";

    if(scrupURL == "" && apiURL != "") {
    	scrupURL = apiURL + "/scrup";
    }
    if (loginURI == "" || scrupURL == "" || !scrupAllowUpdates || !enable) {
        if (loginURI == "") llOwnerSay("loginURI not set, auto-updates disabled");
        else if (scrupURL == "") llOwnerSay("scrupURL not set, auto-updates disabled");
        llSetRemoteScriptAccessPin(0);
        return;
    }

    debug("scrupURL: " + scrupURL);
    debug(llGetScriptName() + " stored version: " + version);

    // Detect API style: legacy (.php URL uses POST body params) vs REST (path-based)
    string clientEndpoint;
    string scriptname;
    string scriptnameVersion = "";

    list extraParams;
    if (llSubStringIndex(scrupURL, ".php") >= 0) {
        clientEndpoint = scrupURL;
        extraParams = ["action=register", "type=client"];
    } else {
        clientEndpoint = scrupURL + "/register/client";
        extraParams = [];
    }

    // Extract version from script name (first token matching x.y.z[-suffix])

    list parts = llParseString2List(llGetScriptName(), [" "], []);
    integer i;
    for (i = 1; i < llGetListLength(parts); i++) {
        string part = llList2String(parts, i);
        string main = llList2String(llParseString2List(part, ["-"], []), 0);
        if (llGetListLength(llParseString2List(main, ["."], [])) > 1
        && llGetListLength(llParseString2List(main, [".", 0,1,2,3,4,5,6,7,8,9], [])) == 0) {
            scriptnameVersion = part;
            scriptname = llDumpList2String(llList2List(parts, 0, i - 1), " ");
            jump versionFound;
        }
    }
    scrupAllowUpdates = FALSE;
    llSetRemoteScriptAccessPin(0);
    return;

    @versionFound;

    debug(scriptname + " version from name: " + scriptnameVersion);
    if(version != "" && version != scriptnameVersion) {
    	llOwnerSay("Inventory name does not match the inside version. To avoid update conflicts,"
	    	+ "\nyou should rename \"" + llGetScriptName() + "\" as \"" + scriptname + " " + version + "\""
		);
    }

    // After an update, announce version and delete any older copy in inventory
    if (llGetStartParameter() == scrupPin) {
        if (scrupSayVersion || DEBUG) llOwnerSay(scriptname + " found version " + version);
        scrupSayVersion = FALSE;
        i = 0; do {
            string found = llGetInventoryName(INVENTORY_SCRIPT, i);
            if (found != llGetScriptName() && llSubStringIndex(found, scriptname + " ") == 0) {
                llOwnerSay("removing previous version '" + found + "'");
                llRemoveInventory(found);
            }
        } while (i++ < llGetInventoryNumber(INVENTORY_SCRIPT) - 1);
    }

    list params = [
        "loginURI=" + loginURI,
        "linkkey=" + (string)llGetKey(),
        "scriptname=" + scriptname,
        "pin=" + (string)scrupPin,
        "version=" + version,
        "scrupVersion=" + scrupVersion
    ] + extraParams;
    scrupRequestID = llHTTPRequest(
        clientEndpoint,
        [HTTP_METHOD, "POST", HTTP_MIMETYPE, "application/x-www-form-urlencoded"],
        llDumpList2String(params, "&")
    );
    llSetRemoteScriptAccessPin(scrupPin);
}

default
{
    state_entry()
    {
        scrup(ACTIVE);

        debug("ScrupClient"
            + "\nallow updates: " + (string)scrupAllowUpdates
            + "\nstart parameter " + (string)llGetStartParameter()
            + "\n---\n" + llGetScriptName(), <1,1,1>, 1.0));
    }

    on_rez(integer start_param)
    {
        scrup(ACTIVE); // not needed if you llResetScript() here instead
    }

    changed(integer change)
    {
        if (change & CHANGED_INVENTORY) {
            // Do not reset right after inventory change: the current script
            // would delete the updated version just delivered by ScrupServer.
            // If you need a reset, use llSleep() or llSetTimerEvent() first.
        }
    }

    http_response(key request_id, integer status, list metadata, string body)
    {
        if (request_id == scrupRequestID) {
            // Scrup client does not process the http response, code below
            // is only for debugging.
            // debug("response " + (string)status + "\n" + body);
        }
    }
}

state exampleWithoutUpdates
{
    state_entry()
    {
        // If your script uses multiple states, you may want to disable updates
        // while in states where a forced restart would be disruptive.
        // Updates will resume automatically when returning to default state.
        scrup(FALSE);
    }
}
