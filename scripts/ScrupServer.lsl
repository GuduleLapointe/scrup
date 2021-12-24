string version = "1.1.0";
/**
 * ScrupServer
 *
 * Place this script in a prim, alongside scripts to serve updates for.
 *
 * In initial parameters below, set the scrupURL, according to you web server
 * installation of scrup.php library.
 *
 * Under default "state_entry", set loginURI according to your platform.
 * OpenSimulator or Second Life. Uncomment only the choice matching your
 * platform, without changing it. It won't work with a wrong value!
 *
 * Then add the scripts to deliver in the same prim as this script:
 * - They have to be set as NON RUNNING to avoid mismatches.
 * - They must be named with their VERSION NUMBER at the end
 * - Their base NAME MUST MATCH the name of the scripts in your live objects
 * - You can add multiple scripts, they will be processed independently
 */

integer DEBUG = FALSE;

string scrupURL = ""; // Change to your scrup.php URL
integer scrupCheckInterval = 300; // In seconds

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

startServer() {
    if(loginURI == "") {
        notify("SERVER NOT STARTED. Set loginURI value in default state_entry section, according to your platform (OpenSimulator or Second Life), and change scrupURL to your scrup.php web URL");
        return;
    }

    if(scrupURL =="") {
        notify("Server not started. Update scrupURL in your script with your scrup.php web URL");
        return;
    }
    list params = [
    "loginURI=" + loginURI,
    "action=register",
    "type=server"
    ];
    registerRequestId = llHTTPRequest(scrupURL, [HTTP_METHOD, "POST",
    HTTP_MIMETYPE, "application/x-www-form-urlencoded"],
    llDumpList2String(params, "&"));
    debug("requested server registration on " + scrupURL + "(" + (string) registerRequestId + ")");
}

list parseSoftwareInfo(string name)
{
    string foundVersion = ""; list parts=llParseString2List(name, [" "], []);
    integer i = 1; do {
        string part = llList2String(parts, i);
        string main = llList2String(llParseString2List(part, ["-"], []), 0);
        if(llGetListLength(llParseString2List(main, ["."], [])) > 1
        && (integer)llDumpList2String(llParseString2List(main, ["."], []), "")) {
            foundVersion = part;
            jump break;
        }
    } while (i++ < llGetListLength(parts)-1 );
    if(foundVersion == "") return [ name ];
    @break;

    return [
    llDumpList2String(llList2List(parts, 0, i - 1), " "),
    foundVersion,
    llDumpList2String(llList2List(parts, i+1, llGetListLength(parts)), " ")
    ];
}

registerScripts() {
    debug("Get scripts list");
    scripts = [];
    integer i = 0; do {
        string script = llGetInventoryName(INVENTORY_SCRIPT, i);
        string name = getScriptName(script);
        string scriptVersion = getScriptVersion(script);
        if(scriptVersion != "") {
            scripts += script;
        }
    } while(i++ < llGetInventoryNumber(INVENTORY_SCRIPT) -1 );
    llSetText(llGetObjectName()
    + "\nScrupServer " + version
    + "\n---\n" + llDumpList2String(scripts, "\n"),<1,1,1>, 1.0);
    registerScript(0);
}

registerScript(integer i) {
    string script = llGetInventoryName(INVENTORY_SCRIPT, i);
    if(script=="") {
        debug("end list " + (string)i);
        llSetTimerEvent(scrupCheckInterval);
        return;
    }

    if (script == llGetScriptName()) {
        debug("that's me, not processing");
        registerScript(i+1);
        return;
    }

    string scriptname = getScriptName(script);
    string scriptVersion = getScriptVersion(script);
    if(scriptVersion == "") {
        notify("no version number for " + script + ", ignoring");
        registerScript(i+1);
        return;
    }

    list params = [
    "loginURI=" + loginURI,
    "action=register",
    "type=script",
    "name=" + scriptname,
    "version=" + scriptVersion
    ];
    requestedScriptName = script;
    requestedScriptId = i;
    registerRequestId = llHTTPRequest(scrupURL, [HTTP_METHOD, "POST", HTTP_MIMETYPE, "application/x-www-form-urlencoded"], llDumpList2String(params, "&"));
    debug("requested script " + (string)i + ": " + scriptname + " (" + scriptVersion + ") status");
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
        // Uncomment the loginURI for your platform, leave other one commented
        // loginURI = osGetGridLoginURI();  // If in OpenSimulator
        // loginURI = "secondlife://";      // If in Second Life

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
            if(status ==200) {
                state serving;
            } else {
                notify("could not register, web server andswered " + (string)status
                + "\n" + body
                );
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
        touchStarted=llGetTime();
    }

    touch_end(integer num)
    {
        if(llDetectedKey(0)==llGetOwner() && llGetTime() - touchStarted > 2)
        llResetScript();
    }

    timer()
    {
        registerScripts();
    }

    http_response(key request_id, integer status, list metadata, string body)
    {
        if(request_id == registerRequestId) {
            debug("response for "  + requestedScriptName + ": " + (string)status + "\n" + body);
            if(status ==200) {
                list clients = llParseString2List(body, [ "," ], [] );
                if(llGetListLength(clients) > 1) {
                    llSetTimerEvent(0); // might be long, suspend other checks
                    integer i=0; do {
                        list client = llParseString2List(llList2String(clients, i), [ " " ], [] );
                        key clientKey = llList2Key(client, 0);
                        integer pin = llList2Integer(client, 1);
                        if(clientKey == "ENDLIST") jump endlist;
                        if(clientKey != llGetKey() && llKey2Name(clientKey) != "") {
                            // If no name, the object has been deleted or is in another grid
                            debug("sending update for " + requestedScriptName + " to " + llKey2Name(clientKey));
                            llRemoteLoadScriptPin(clientKey, requestedScriptName, pin, TRUE, pin);
                        }
                    } while (i++ < llGetListLength(clients)-1);
                    @endlist;
                }
                llSleep(1); // avoid asking too much too fast
                registerScript( requestedScriptId + 1 );
            } else {
                notify("could not register " + requestedScriptName + ", web server answered " + (string)status
                // + " metadata " + llDumpList2String(metadata, ", ")
                + "\n" + body
                );
            }
        }
    }
}
