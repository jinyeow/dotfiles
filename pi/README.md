# Pi

Tracked, non-secret Pi configuration and first-party resources. Install with
`setup.ps1 -Module pi` on Windows or `setup.sh -m pi` on Linux/WSL.

`settings.json` is authoritative for non-secret preferences and exact package
references. Pi credentials and session/authentication state remain in Pi's
user directory and are never copied by setup.

Place repository-owned extensions, skills, prompt templates, and themes in the
corresponding directories. They are projected into Pi's native global resource
locations by the installer and therefore take precedence over package resources
with the same name.
