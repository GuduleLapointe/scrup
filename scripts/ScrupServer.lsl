/**
 * ScrupServer
 * Version: 1.0
 *
 * Place this script in a prim, alongside scripts to serve updates for.
 * - Updated scripts have to be set as non running to avoid mismatches.
 * - Updated scripts must be named with their version number at the end
 */

integer DEBUG = TRUE;

// Do not change below
string scrupURL = "http://dev.w4os.org/updater/scrup.php";
string registerRequestId;
key clientKey;
string script;
integer start_param;
integer pin;

debug(string message) {
    if(DEBUG) llOwnerSay("/me (debug): " + message);
}

notify(string message) {
    llOwnerSay(message);
}

sendUpdates(string scriptname, string scriptversion) {
    debug("requesting clients on " + scrupURL);
    list params = [
    "loginURI=" + osGetGridLoginURI(),
    "action=get",
    "type=clients",
    "scripname=" + scriptname,
    "version=" + scriptversion
    ];
    registerRequestId = llHTTPRequest(scrupURL, [HTTP_METHOD, "POST",
    HTTP_MIMETYPE, "application/x-www-form-urlencoded"],
    llDumpList2String(params, "&"));
}

sendUpdate(key client, string script, integer pin) {
    return;
    llRemoteLoadScriptPin(clientKey, script, pin, TRUE, start_param);
}

startServer() {
    debug("requesting status on " + scrupURL);
    list params = [
    "loginURI=" + osGetGridLoginURI(),
    "action=register",
    "type=server"
    ];
    registerRequestId = llHTTPRequest(scrupURL, [HTTP_METHOD, "POST",
    HTTP_MIMETYPE, "application/x-www-form-urlencoded"],
    llDumpList2String(params, "&"));

    // llRequestURL();
}

list parseSoftwareInfo(string name)
{
    string part;
    list softParts=[];
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
    list nameList = llList2List(parts, 0, i - 1);
    return [
    llDumpList2String(llList2List(parts, 0, i - 1), " "),
    part,
    llDumpList2String(llList2List(parts, i+1, llGetListLength(parts)), " ")
    ];
}

registerScripts() {
    registerScript(0);
}

registerScript(integer i) {
    string script = llGetInventoryName(INVENTORY_SCRIPT, i);
    if(!script) {
        debug("end list " + i);
        return;
    }
    if (script == llGetScriptName()) jump break;

    string name = getScriptName(script);
    string version = getScriptVersion(script);
    if(version == "") {
        notify("missing version number for " + script);
        jump break;
    }
    debug("register " + name + " (" + version + ")");

    list params = [
    "loginURI=" + osGetGridLoginURI(),
    "action=register",
    "type=script",
    "name=" + name,
    "version=" + version
    ];
    registerRequestId = llHTTPRequest(scrupURL, [HTTP_METHOD, "POST",
    HTTP_MIMETYPE, "application/x-www-form-urlencoded"],
    llDumpList2String(params, "&"));


    @break;
    registerScript(i+1);
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
        debug("starting " + llGetKey());
        startServer();
    }

    on_rez(integer start_param)
    {
        llResetScript();
    }

    http_response(key request_id, integer status, list metadata, string body)
    {
        if(request_id == registerRequestId) {
            if(status ==200) {
                state serving;
            } else {
                debug("could not register, got status " + (string)status
                // + " metadata " + llDumpList2String(metadata, ", ")
                + "\n" + body
                );
            }
        }
    }
}

state serving {
    state_entry()
    {
        debug("serving");
        registerScripts();
    }

    on_rez(integer start_param)
    {
        llResetScript();
    }

    changed(integer change)
    {
        if(change & CHANGED_INVENTORY) {
            registerScripts();
        }
    }

    http_response(key request_id, integer status, list metadata, string body)
    {
        if(request_id == registerRequestId) {
            if(status ==200) {
                debug("script registered " + (string)status
                // + " metadata " + llDumpList2String(metadata, ", ")
                + "\n TODO: register output should include keys of clients to update (lower version),"
                + "\n and this script must serve them from here"
                + "\n" + body
                );
            } else {
                debug("could not register, got status " + (string)status
                // + " metadata " + llDumpList2String(metadata, ", ")
                + "\n" + body
                );
            }
        }
    }
}
