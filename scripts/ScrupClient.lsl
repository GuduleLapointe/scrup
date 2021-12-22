/**
 * ScrupClient
 *
 * @Package: Scrup
 * @Author: Gudule Lapointe <gudule@speculoos.world>
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
 *
 * If you use multiple states, depending on the way your script work, you
 * might or not want to disable updates when entering other states, as an update
 * would force a restart and go back to default state. In this cases, updates
 * will resume when coming back to default state.
 */

// Change only in your master script
string scrupURL = ""; // Change to your scrup.php URL
integer scrupPin = 56748; // Change or not, it shouldn't hurt
integer scrupAllowUpdates = TRUE; // should always be true, except for debug

// Do not change below
string scrupRequestID;
string version;

debug(string message) {
    // llOwnerSay(message);
}

scrup() {
    string scrupVersion = "1.0.1";
    if(!scrupAllowUpdates)  {
        llSetRemoteScriptAccessPin(0);
        return;
    }

    // Get version from script name
    string name = llGetScriptName();
    string part;
    // list softParts=[];
    list parts=llParseString2List(name, [" "], "");
    integer i; for (i=1;i<llGetListLength(parts);i++)
    {
        part = llList2String(parts, i);
        string main = llList2String(llParseString2List(part, ["-"], ""), 0);
        if(llGetListLength(llParseString2List(main, ["."], [])) > 1
        && llGetListLength(llParseString2List(main, [".", 0,1,2,3,4,5,6,7,8,9], [])) == 0) {
            version = part;
            jump break;
        }
    }
    version = "";
    scrupAllowUpdates = FALSE;
    llSetRemoteScriptAccessPin(0);
    return;

    @break;
    list scriptInfo = [ llDumpList2String(llList2List(parts, 0, i - 1), " "), version ];
    string scriptname = llList2String(scriptInfo, 0);
    version = llList2String(scriptInfo, 1);

    if(llGetStartParameter() == scrupPin) {
        llOwnerSay(scriptname + " version " + version);
        // Delete other scripts with the same name. As we just got started after
        // an update, we should be the newest one.
        i=0; do {
            string found = llGetInventoryName(INVENTORY_SCRIPT, i);
            if(found != llGetScriptName()) {
                // debug("what shall we do with " + found);
                integer match = llSubStringIndex(found, scriptname + ' ');
                if(match == 0) {
                    llOwnerSay("deleting duplicate '" + found + "'");
                    llRemoveInventory(found);
                }
            }
        } while (i++ < llGetInventoryNumber(INVENTORY_SCRIPT)-1);
    }

    list params = [ "loginURI=" + osGetGridLoginURI(), "action=register",
    "type=client", "scriptname=" + scriptname, "pin=" + scrupPin,
    "version=" + version, "scrupVersion=" + scrupVersion ];
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

        // DISABLE NEXT COMMAND IN PUBLIC ENVIRONMENT llSetText is used here
        // only for debug purposes, you don't need it in your script (and if you
        // want it, NEVER display llGetStartParameter() value publicly)
        llSetText(llGetObjectName() + "\nScrupClient" + "\nallow updates: " + scrupAllowUpdates + "\nstart parameter " + llGetStartParameter() + "\n---\n" + llGetScriptName(),<1,1,1>, 1.0);
    }

    on_rez(integer start_param)
    {
        scrup(); // not needed if you llResetScript() too.
    }

    changed(integer change)
    {
        if(change & CHANGED_INVENTORY) {
            // Do not reset script right after an inventory change: the current
            // script would delete the updated version sent by Scrup server.
            // If you need to reset script, use llSleep() or llSetTimerEvent().
        }
    }
}

state exampleWithoutUpdates
{
    state_entry()
    {
        // Disable authorisation to avoid updates occuring in this state
        llSetRemoteScriptAccessPin(0);
    }
}
