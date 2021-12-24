# Scrup - LSL scripts auto-update

An update ecosystem to allow OpenSimulator scripts to self-update. It should also work in Second Life with a small tweak (see below).

## Installation

- **ScrupServer**: the lsl server script, to put inside an in-world object. The object will also contain non-running copies of the latest versions of the scripts to update.
- **ScrupClient**: The portions of code to include own script. It is intended to be lightweight, we don't want it to get bigger than the script itself.
- **Web application**: the rest of this repository. It will allow both client and server to register an exchange the needed information for updates.
- **Database**: scrup use a sqlite database for efficiency only. It will be created automatically in PHP tmp_dir (or upload_tmp_dir). It stores only runtime data sent by server and client, so it can get deleted or lost without real harm.

### In the client script:

- copy the variables and the scrup() function as is in your script (also include debug() function if you don't have one)
- please include a credit line at the beginning, after yours
- insert scrup(ACTIVE) at beginning of default state_entry() and on_rez() (the latter only if you don't use llResetScript)
- use scrup(FALSE) to stop updates at any time in your script (for example, while executing a task that should not be interrupted). The authorization pin will be revoked and a new one will be generated on scrup(ACTIVE) or scrup(TRUE)
- use scrup(TRUE) or scrup(ACTIVE) to resume normal operations (value of scrupAllowUpdates is still honored)

## Status

This is a work in progress and more like a proof of concept. Updates are functional, but...

- only if the server and the object are in the same region (you can wear the object and TP to the region hosting the server, though, and even wear the server and visit the regions where objects need update)
- only one client can be present in a prim (several can if each one is in a different prim of the same object, though)
- there are no verifications (allowed grids, owners, creators), so it should probably not be used at a wide scale. Yet.

## Second Life

The only OSSL function used in scripts is osGetGridLoginURI(), in , which is useless in SL. So to make the script work in SL, replace the function by a fixed value "secondlife://" (detailed explanation in the scripts comments).

## Roadmap

- Let ScrupServer script update itself too
- Let two ScrupServers exchange their latest versions
- If there are no updater in the same region, send a message notification to the owner
- Or better: send an updater box to the owner as a workaround to region limitations (wear to update)
- Allow bundles (all scripts in an object + other inventory items), mix with updater box concept
- Find a f_*_ way to send updates to other regions (let's forget other grids for now)
