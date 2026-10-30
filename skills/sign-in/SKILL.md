---
name: sign-in
description: Get a person signed in to Datum Cloud and pointed at the right organization and project, with datumctl and the datum-mcp server. Use when someone is setting up Datum Cloud for the first time, when a datumctl command or datum-mcp tool fails with an auth error, returns nothing, or acts on the wrong project, or when they ask which account, organization or project they are using.
---

# Sign in to Datum Cloud

Datum Cloud has two front doors for an agent, and each one signs in on its
own:

| Surface | What it is | How it signs in |
|---|---|---|
| `datumctl` | The CLI. Run it from the shell. | `datumctl login`, once per machine |
| `datum-mcp` | The MCP server this plugin starts. Its tools are named `context`, `organizations`, `projects` and so on. | A browser sign-in on its first tool call |

They keep separate credentials in the system keyring, so signing in to one
does not sign in the other. A person who uses both signs in twice, once each.

## 1. Check what is installed

```bash
datumctl version
command -v datum-mcp
```

If either is missing, give the person the install command and wait for them
to run it. Do not install software for them without asking.

```bash
# macOS and Linux, with Homebrew
brew tap datum-cloud/tap
brew install datumctl datum-mcp
```

Without Homebrew, download binaries from the releases pages of
[datumctl](https://github.com/datum-cloud/datumctl/releases/latest) and
[datum-mcp](https://github.com/datum-cloud/datum-mcp/releases/latest) and put
them on `PATH`. The [datumctl install guide](https://www.datum.net/docs/datumctl/install)
covers Nix, Windows and building from source. After installing `datum-mcp`, restart Claude Code so the
plugin can start the server.

## 2. Sign in

### datumctl

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

### datum-mcp

Call the `context` tool. On the first call the server opens a browser to sign
in, then reuses and refreshes the token. If the person is on a machine with no
browser, the server cannot sign in interactively; set `DATUM_TOKEN` and
`DATUM_API_HOSTNAME` instead (see the `ci-service-account` skill).

## 3. Pick an organization and project

Most resources live in a project, and a project lives in an organization.
Nearly every "it returned nothing" problem is the wrong project, not a bug.

### With datumctl

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

### With datum-mcp

1. `context` shows what is already set.
2. `organizations` with `list`, then `set` the one to use.
3. `projects` with `list`, then `set` the project.

Or run the server's `onboard-to-project` prompt, which does all three. A
`DATUM_PROJECT` environment variable wins over a project set with `projects
set`. datum-mcp reads its organization from `DATUM_ORG`, not datumctl's
`DATUM_ORGANIZATION`.

## When something fails

| Symptom | Likely cause | Fix |
|---|---|---|
| Empty list, or "not found" for something the person can see in the portal | Wrong project | `datumctl whoami`, then `datumctl ctx`; or the `context` tool. Look for a stray `DATUM_PROJECT`. |
| A project is missing from `datumctl ctx` | The signed-in account has no access to it | `datumctl ctx --all` lists the contexts for every signed-in account; `datumctl auth list` shows the accounts. |
| `datumctl` asks to log in again | Session removed or expired | `datumctl login` |
| datum-mcp tools are missing in Claude Code | `datum-mcp` is not on `PATH`, or Claude Code started before it was installed | Install it, then restart Claude Code. `/mcp` shows the server's status. |
| Both `DATUM_PROJECT` and `DATUM_ORGANIZATION` set, and datumctl errors | They cannot both be set | Unset one. |

## Reference

- [Logging in](https://www.datum.net/docs/datumctl/auth/logging-in)
- [Contexts and scoping](https://www.datum.net/docs/datumctl/contexts-and-scoping)
- [Datum MCP](https://www.datum.net/docs/agents/datum-mcp)
