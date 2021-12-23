string version = "1.0.5";
/**
 * ScrupServer
 *
 * Place this script in a prim, alongside scripts to serve updates for.
 * - Updated scripts have to be set as non running to avoid mismatches.
 * - Updated scripts must be named with their version number at the end
 */

integer DEBUG = FALSE;

string scrupURL = ""; // Change to your scrup.php URL
integer scrupCheckInterval = 60;

// Do not change below
string registerRequestId;
string registerRequestScript;
key clientKey;
string script;
integer start_param;
integer pin;
list scripts;
list versions;
float touchStarted;

debug(string message) {
    if(DEBUG) llOwnerSay("/me (debug): " + message);
}

notify(string message) {
    llOwnerSay(message);
}

startServer() {
    if(scrupURL =="") {
        notify("Server not started. Update scrupURL in your script with the URL of your scrup.php web URL");
        return;
    }
    list params = [
    "loginURI=" + osGetGridLoginURI(),
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
    string part;
    // list softParts=[];
    list parts=llParseString2List(name, [" "], "");
    integer i; for (i=1;i<llGetListLength(parts);i++)
    {
        part = llList2String(parts, i);
        string main = llList2String(llParseString2List(part, ["-"], ""), 0);
        if(llGetListLength(llParseString2List(main, ["."], [])) > 1
        && llGetListLength(llParseString2List(main, [".", 0,1,2,3,4,5,6,7,8,9], [])) == 0) jump break;
    }
    return name;

    @break;
    // list nameList = llList2List(parts, 0, i - 1);
    return [
    llDumpList2String(llList2List(parts, 0, i - 1), " "),
    part,
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
    if(!script) {
        debug("end list " + i);
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
        notify("missing version number for " + script);
        registerScript(i+1);
        return;
    }

    list params = [
    "loginURI=" + osGetGridLoginURI(),
    "action=register",
    "type=script",
    "name=" + scriptname,
    "version=" + scriptVersion
    ];
    registerRequestScript = script;
    registerRequestId = llHTTPRequest(scrupURL, [HTTP_METHOD, "POST",
    HTTP_MIMETYPE, "application/x-www-form-urlencoded"],
    llDumpList2String(params, "&"));
    debug("requested script " + scriptname + " (" + scriptVersion + ") status");
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
        notify(llGetScriptName() + " starting");
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
            debug("response for (" + llListFindList(scripts, registerRequestScript) + ")" + registerRequestScript + ": " + (integer)status + "\n" + body);
            if(status ==200) {
                list clients = llParseString2List(body, [ "," ], [] );
                if(llGetListLength(clients) > 1) {
                    llSetTimerEvent(0); // might be long, suspend other checks
                    integer i=0; do {
                        list client = llParseString2List(llList2String(clients, i), [ " " ], [] );
                        key clientKey = llList2Key(client, 0);
                        integer pin = llList2Integer(client, 1);
                        if(clientKey == "ENDLIST") jump endlist;
                        if(llKey2Name(clientKey) != "") {
                            // If no name, the object has been deleted or is in another grid
                            debug("sending update for " + registerRequestScript + " to " + llKey2Name(clientKey));
                            llRemoteLoadScriptPin(clientKey, registerRequestScript, pin, TRUE, pin);
                        }
                    } while (i++ < llGetListLength(clients)-1);
                    @endlist;
                }
                llSleep(1); // avoid asking too much too fast
                registerScript(llListFindList(scripts, registerRequestScript) + 1);
            } else {
                notify("could not register " + registerRequestScript + ", web server answered " + (string)status
                // + " metadata " + llDumpList2String(metadata, ", ")
                + "\n" + body
                );
            }
        }
    }
}
