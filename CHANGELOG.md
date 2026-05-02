# Changelog

## 1.2.0

- new public `get-version` endpoint — query script version by name (`?name=`), or server version (`?type=scrup`); no LSL headers required
- add `inWorldOrDie()` guard — cleanly separates in-world authentication from business logic; register endpoints still require valid LSL headers
- add SQL injection prevention (all database queries use prepared statements)
- fix use `$_SERVER` instead of `getenv()` for LSL request headers (PHP built-in server compatibility)
- fix `fetchArray()` called on bool result
- fix client pin not updated when client already registered
- fix empty link key handling
- LSL ScrupServer `loginURI` now auto-populated via `osGetGridLoginURI()`
- LSL ScrupServer optional floating text display (`setText` flag)
- LSL ScrupClient owner notification when server is not configured

## 1.1.0

- add `linkkey` parameter to client registration
