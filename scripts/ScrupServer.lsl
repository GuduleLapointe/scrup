string version = "1.2.0";
/**
 * ScrupServer
 *
 * Place this script in a prim, alongside scripts to serve updates for.
 *
 * In initial parameters below, set the scrupURL. Use the REST API base URL
 * (e.g. https://example.com/api/v3/scrup) for a current installation, or
 * the legacy direct URL (e.g. https://example.com/scrup/scrup.php) for older
 * installations. The script detects the style automatically.
 *
 * Under default "state_entry", set loginURI according to your platform.
 * Uncomment only the choice matching your platform, without changing it.
 *
 * Then add the scripts to deliver in the same prim as this script:
 * - They have to be set as NON RUNNING to avoid mismatches.
 * - They must be named with their VERSION NUMBER at the end
 * - Their base NAME MUST MATCH the name of the scripts in your live objects
 * - You can add multiple scripts, they will be processed independently
 */

integer DEBUG = FALSE;

string scrupURL = ""; // REST base URL or legacy scrup.php URL
integer scrupCheckInterval = 300; // In seconds

integer setText = TRUE;

// Do not change below
string registerRequestId;
string requestedScriptName;
integer requestedScriptId;
key clientKey;
string script;
integer start_param;
integer pin;
list scripts;
list versions;
float touchStarted;

string loginURI;

debug(string message) {
    if(DEBUG) llOwnerSay("/me " + llGetScriptName() + ": " + message);
}

notify(string message) {
    llOwnerSay("/me " + llGetScriptName() + ": " + message);
}

// Return the endpoint URL for a register action.
// Supports both REST API (scrupURL/register/type) and legacy (scrupURL with
// action/type in POST body — detected when scrupURL contains ".php").
string registerEndpoint(string type) {
    if (llSubStringIndex(scrupURL, ".php") >= 0) return scrupURL;
    return scrupURL + "/register/" + type;
}

// Return extra params required for legacy endpoints (empty for REST).
list legacyParams(string type) {
    if (llSubStringIndex(scrupURL, ".php") >= 0)
        return ["action=register", "type=" + type];
    return [];
}

startServer() {
    if(loginURI == "") {
        notify("SERVER NOT STARTED. Set loginURI in default state_entry, and set scrupURL to your Scrup web URL.");
        return;
    }
    if(scrupURL == "") {
        notify("Server not started. Set scrupURL in the script.");
        return;
    }
    list params = ["loginURI=" + loginURI] + legacyParams("server");
    registerRequestId = llHTTPRequest(
        registerEndpoint("server"),
        [HTTP_METHOD, "POST", HTTP_MIMETYPE, "application/x-www-form-urlencoded"],
        llDumpList2String(params, "&")
    );
    debug("requested server registration on " + scrupURL + " (" + (string)registerRequestId + ")");
}

list parseSoftwareInfo(string name)
{
    list parts = llParseString2List(name, [" "], []);
    integer i;
    for (i = 1; i < llGetListLength(parts); i++) {
        string part = llList2String(parts, i);
        string main = llList2String(llParseString2List(part, ["-"], []), 0);
        if (llGetListLength(llParseString2List(main, ["."], [])) > 1
        && llGetListLength(llParseString2List(main, [".", 0,1,2,3,4,5,6,7,8,9], [])) == 0) {
            return [
                llDumpList2String(llList2List(parts, 0, i - 1), " "),
                part,
                llDumpList2String(llList2List(parts, i + 1, llGetListLength(parts)), " ")
            ];
        }
    }
    return [name];
}

registerScripts() {
    debug("Get scripts list");
    scripts = [];
    integer i;
    for (i = 0; i < llGetInventoryNumber(INVENTORY_SCRIPT); i++) {
        string s = llGetInventoryName(INVENTORY_SCRIPT, i);
        if (getScriptVersion(s) != "") scripts += s;
    }
    if(setText) {
        llSetText(llGetObjectName()
        + "\nScrupServer " + version
        + "\n---\n" + llDumpList2String(scripts, "\n"), <1,1,1>, 1.0);
    }
    registerScript(0);
}

registerScript(integer i) {
    string script = llGetInventoryName(INVENTORY_SCRIPT, i);
    if(script == "") {
        debug("end of list at " + (string)i);
        llSetTimerEvent(scrupCheckInterval);
        return;
    }
    if (script == llGetScriptName()) {
        debug("that's me, skipping");
        registerScript(i + 1);
        return;
    }

    string scriptname = getScriptName(script);
    string scriptVersion = getScriptVersion(script);
    if(scriptVersion == "") {
        notify("no version number for " + script + ", ignoring");
        registerScript(i + 1);
        return;
    }

    list params = [
        "loginURI=" + loginURI,
        "name=" + scriptname,
        "version=" + scriptVersion
    ] + legacyParams("script");
    requestedScriptName = script;
    requestedScriptId = i;
    registerRequestId = llHTTPRequest(
        registerEndpoint("script"),
        [HTTP_METHOD, "POST", HTTP_MIMETYPE, "application/x-www-form-urlencoded"],
        llDumpList2String(params, "&")
    );
    debug("requested script " + (string)i + ": " + scriptname + " (" + scriptVersion + ")");
}

string getScriptName(string name)
{
    return llList2String(parseSoftwareInfo(name), 0);
}

string getScriptVersion(string name)
{
    return llList2String(parseSoftwareInfo(name), 1);
}

default
{
    state_entry()
    {
        if(setText) llSetText("", <1,1,1>, 1.0);
        // Uncomment the loginURI for your platform, leave the other commented
        loginURI = osGetGridLoginURI();  // If in OpenSimulator
        // loginURI = "secondlife://";   // If in Second Life

        startServer();
    }

    on_rez(integer start_param)
    {
        llResetScript();
    }

    changed(integer change)
    {
        if(change & CHANGED_OWNER
        || change & CHANGED_REGION
        || change & CHANGED_INVENTORY
        ) {
            startServer();
        }
    }

    http_response(key request_id, integer status, list metadata, string body)
    {
        if(request_id == registerRequestId) {
            if(status == 200) {
                state serving;
            } else {
                notify("could not register on " + scrupURL + ", server status " + (string)status
                + "\n" + body);
            }
        }
    }
}

state serving {
    state_entry()
    {
        notify("start serving updates");
        registerScripts();
    }

    on_rez(integer start_param)
    {
        llResetScript();
    }

    changed(integer change)
    {
        if(change & CHANGED_OWNER
        || change & CHANGED_REGION
        || change & CHANGED_INVENTORY
        ) {
            registerScripts();
        }
    }

    touch_start(integer index)
    {
        touchStarted = llGetTime();
    }

    touch_end(integer num)
    {
        if(llDetectedKey(0) == llGetOwner() && llGetTime() - touchStarted > 2)
            llResetScript();
    }

    timer()
    {
        registerScripts();
    }

    http_response(key request_id, integer status, list metadata, string body)
    {
        if(request_id == registerRequestId) {
            debug("response for " + requestedScriptName + ": " + (string)status + "\n" + body);
            if(status == 200) {
                list clients = llParseString2List(body, [","], []);
                if(llGetListLength(clients) > 1) {
                    llSetTimerEvent(0); // might be long, suspend other checks
                    integer i;
                    for (i = 0; i < llGetListLength(clients); i++) {
                        list client = llParseString2List(llList2String(clients, i), [" "], []);
                        key clientKey = llList2Key(client, 0);
                        integer pin = llList2Integer(client, 1);
                        if(clientKey == "ENDLIST") jump endlist;
                        if(clientKey != llGetKey() && llKey2Name(clientKey) != "") {
                            // If no name, the object has been deleted or is in another region
                            debug("sending update for " + requestedScriptName + " to " + llKey2Name(clientKey));
                            llRemoteLoadScriptPin(clientKey, requestedScriptName, pin, TRUE, pin);
                        }
                    }
                    @endlist;
                }
                llSleep(1); // avoid flooding the server
                registerScript(requestedScriptId + 1);
            } else {
                notify("could not register " + requestedScriptName + ", server status " + (string)status
                + "\n" + body);
            }
        }
    }
}
