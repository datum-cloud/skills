---
name: sign-in
description: Get a person signed in to Datum Cloud with datumctl and pointed at the right organization and project. Use when someone is setting up Datum Cloud for the first time, when a datumctl command fails with an auth error, returns nothing, or acts on the wrong project, or when they ask which account, organization or project they are using.
---

# Sign in to Datum Cloud

`datumctl` is the Datum Cloud CLI. Run it from the shell. It signs in once
per machine with `datumctl login` and keeps its credentials in the system
keyring.

## 1. Check it is installed

```bash
datumctl version
```

If it is missing, give the person the install command and wait for them to
run it. Do not install software for them without asking.

```bash
# macOS and Linux, with Homebrew
brew tap datum-cloud/tap
brew install datumctl
```

Without Homebrew, download a binary from the
[datumctl releases page](https://github.com/datum-cloud/datumctl/releases/latest)
and put it on `PATH`. The [datumctl install guide](https://www.datum.net/docs/datumctl/install)
covers Nix, Windows and building from source.

## 2. Sign in

```bash
datumctl login
```

It opens a browser, then offers a picker for the default organization or
project. The picker needs a terminal, so ask the person to run `datumctl
login` themselves (in Claude Code they can type `! datumctl login`) rather
than running it from your shell tool.

- No browser on this machine (SSH, a container, a remote box) but a person is
  present: `datumctl login --no-browser` prints a URL and a code to approve
  from any device.
- Nobody present (CI, a cron job): use a service account, never a personal
  login. See the `ci-service-account` skill.

## 3. Pick an organization and project

Most resources live in a project, and a project lives in an organization.
Nearly every "it returned nothing" problem is the wrong project, not a bug.

```bash
datumctl whoami          # who am I, and which context is active
datumctl ctx             # every org and project I can use; * marks the active one
datumctl ctx use acme/production
```

The scope for a command comes from, first match wins:

1. `--project` or `--organization` on the command
2. `DATUM_PROJECT` or `DATUM_ORGANIZATION` in the environment
3. The active context from `datumctl ctx use`

When you run commands on someone's behalf, pass `--project` explicitly rather
than changing their active context, unless they asked you to switch.

## When something fails

| Symptom | Likely cause | Fix |
|---|---|---|
| Empty list, or "not found" for something the person can see in the portal | Wrong project | `datumctl whoami`, then `datumctl ctx`. Look for a stray `DATUM_PROJECT`. |
| A project is missing from `datumctl ctx` | The signed-in account has no access to it | `datumctl ctx --all` lists the contexts for every signed-in account; `datumctl auth list` shows the accounts. |
| `datumctl` asks to log in again | Session removed or expired | `datumctl login` |
| Both `DATUM_PROJECT` and `DATUM_ORGANIZATION` set, and datumctl errors | They cannot both be set | Unset one. |

## Reference

- [Logging in](https://www.datum.net/docs/datumctl/auth/logging-in)
- [Contexts and scoping](https://www.datum.net/docs/datumctl/contexts-and-scoping)
