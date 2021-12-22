# Scrup - LSL scripts auto-update

An update ecosystem to allow LSL (or OpenSimulator) scripts to self-update.

## Installation

- **ScrupServer**: the lsl server script, to put inside an in-world object. The object will also contain non-running copies of the latest versions of the scripts to update.
- **ScrupClient**: The portions of code to include own script. It is intended to be lightweight, we don't want it to get bigger than the script itself.
- **Web application**: the rest of this repository. It will allow both client and server to register an exchange the needed information for updates.
- **Database**: scrup use a sqlite database for efficiency only. It will be created automatically in PHP tmp_dir (or upload_tmp_dir). It stores only data provided by server and client, so it can get deleted or lost without real harm.

## Status

This is a work in progress.

As for now, those three parts communicate pretty well together, but the updates are not yet sent (yeah, I know, the most interesting part is yet to come).
