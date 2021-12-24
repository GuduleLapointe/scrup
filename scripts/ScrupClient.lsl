/**
 * ScrupClient
 *
 * @Package: Scrup
 * @Author: Gudule Lapointe <gudule@speculoos.world>
 * @URL: https://github.com/GuduleLapointe/scrup
 *
 * Insert this code inside your own script.
 *
 * In initial parameters below, set the scrupURL, according to you web server
 * installation of scrup.php library.
 *
 * In the beginning of scrup() function, set loginURI according to your
 * platform, OpenSimulator or Second Life. Uncomment only the choice matching
 * your platform, without changing it. It won't work with a wrong value!
 *
 * - make sure to add scrup(TRUE) command in default state_entry(), and on_rez()
 *   if you don't llResetScript() at this stage
 * - if your script use multiple states, you might (or not) need to disable
 *   updates in some states (see example below)
 * - if you need custom settings, do not allow modifying values in your live
 *   script (they would be overidden at each update), use another method to
 *   store them, like the object description or a notecard
 *
 * To push a new release:
 * - update the version by renaming the script (semantic version x.y.z at the
 *   end, with a space before)
 * - put a copy of the script, non running, in the update server object
 *   (alongide ScrupServer script)
 */

string scrupURL = ""; // Change to your scrup.php URL
integer scrupAllowUpdates = TRUE; // should always be true, except for debug

string loginURI; // will be set by scrup() function
string scrupRequestID; // will be set dynamically
integer scrupSayVersion = TRUE; // to owner, after start or update
integer scrupPin;// will be set dynamically
string version; // do not set here, it will be fetched from the script name

debug(string message) {
    // llOwnerSay("/me " + llGetScriptName() + ": " + message);
}

scrup(integer enable) {
    // Uncomment the loginURI for your platform, comment or delete other line
    // loginURI = osGetGridLoginURI();  // If in OpenSimulator
    // loginURI = "secondlife://";      // If in Second Life

    if(loginURI == "" || scrupURL == "" |! scrupAllowUpdates |! enable)  { llSetRemoteScriptAccessPin(0); return; }

    string scrupLibrary = "1.1.0";
    version = ""; list parts=llParseString2List(llGetScriptName(), [" "], []);
    integer i = 1; do {
        string part = llList2String(parts, i);
        string main = llList2String(llParseString2List(part, ["-"], []), 0);
        if(llGetListLength(llParseString2List(main, ["."], [])) > 1
        && (integer)llDumpList2String(llParseString2List(main, ["."], []), "")) {
            version = part;
            jump break;
        }
    } while (i++ < llGetListLength(parts)-1 );
    if(version == "") { scrup(FALSE); return; }
    @break;
    list scriptInfo = [ llDumpList2String(llList2List(parts, 0, i - 1), " "), version ];
    string scriptname = llList2String(scriptInfo, 0);
    version = llList2String(scriptInfo, 1);
    if(scrupSayVersion) llOwnerSay(scriptname + " version " + version);
    scrupSayVersion = FALSE;

    if(llGetStartParameter() != 0) { i=0; do {
        string found = llGetInventoryName(INVENTORY_SCRIPT, i);
        if(found != llGetScriptName() && llSubStringIndex(found, scriptname + " ") == 0) {
            llOwnerSay("deleting duplicate '" + found + "'");
            llRemoveInventory(found);
        }
    } while (i++ < llGetInventoryNumber(INVENTORY_SCRIPT)-1); }

    scrupPin = (integer)(llFrand(999999999) + 56748);
    list params = [ "loginURI=" + loginURI, "action=register",
    "type=client", "linkkey=" + (string)llGetKey(), "scriptname=" + scriptname,
    "pin=" + (string)scrupPin, "version=" + version, "scrupLibrary=" + scrupLibrary ];
    scrupRequestID = llHTTPRequest(scrupURL, [HTTP_METHOD, "POST",
    HTTP_MIMETYPE, "application/x-www-form-urlencoded"],
    llDumpList2String(params, "&"));
    llSetRemoteScriptAccessPin(scrupPin);
}

default
{
    state_entry()
    {
        scrup(ACTIVE);

        // DISABLE NEXT COMMAND IN PUBLIC ENVIRONMENT llSetText is used here
        // only for debug purposes, you don't need it in your script (and if you
        // want it, NEVER display llGetStartParameter() value publicly)
        llSetText(llGetObjectName() + "\nScrupClient" + "\nallow updates: " + (string)scrupAllowUpdates + "\nstart parameter " + (string)llGetStartParameter() + "\n---\n" + llGetScriptName(),<1,1,1>, 1.0);
    }

    on_rez(integer start_param)
    {
        scrup(ACTIVE); // not needed if you llResetScript() too.
    }

    changed(integer change)
    {
        if(change & CHANGED_INVENTORY) {
            // Do not reset script right after an inventory change: the current
            // script would delete the updated version sent by Scrup server.
            // If you need to reset script, use llSleep() or llSetTimerEvent().
        }
    }

    http_response(key request_id, integer status, list metadata, string body)
    {
        if(request_id == scrupRequestID) {
            debug("response " + (string)status + "\n" + body);
        }
    }
}

state exampleWithoutUpdates
{
    state_entry()
    {
        // If you use multiple states, depending on the way your script work,
        // you might or not want to disable updates when entering other states,
        // as an update would force a restart and go back to default state. In
        // this cases, updates will resume when coming back to default state.
        //
        // Disable authorisation when in this state:
        scrup(FALSE);
        // llSetRemoteScriptAccessPin(0);
    }
}
