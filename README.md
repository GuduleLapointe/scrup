# Scrup - LSL scripts auto-update

An update ecosystem to allow OpenSimulator scripts to self-update. It should also work in Second Life with a small tweak (see below).

## Installation

- **ScrupServer**: the lsl server script, to put inside an in-world object. The object will also contain non-running copies of the latest versions of the scripts to update.
- **ScrupClient**: The portions of code to include own script. It is intended to be lightweight, we don't want it to get bigger than the script itself.
- **Web application**: the rest of this repository. It will allow both client and server to register an exchange the needed information for updates.
- **Database**: scrup use a sqlite database for efficiency only. It will be created automatically in PHP tmp_dir (or upload_tmp_dir). It stores only data provided by server and client, so it can get deleted or lost without real harm.

## Status

This is a work in progress and more like a proof of concept. Updates are functional, but...

- only if the server and the object are in the same region (you can wear the object and TP to the region hosting the server, though, and even wear the server and visit the regions where objects need update)
- there is no specific verification (allowed grids, owners, creators), so it should probably not be used at a wide scale.

## Second Life

The only OSSL function used in scripts is osGetGridLoginURI(), in , which is useless in SL. So to make the script work in SL, replace the function by a fixed value, like secondlife.com.
