# Datum Skills
This repository contains skills to help various coding agents (e.g. Claude, Codex, etc) better interact with Datum Cloud.

Each skill is self-contained in its own folder with a SKILL.md file containing the necessary instructions and metadata. 

## Installation

These skills work with any agent with support for Skills like but not limited to: Claude, Codex, Pi, OpenCode, Mistral Vibe.

### Claude Code

Install via the [plugin marketplace](https://code.claude.com/docs/en/discover-plugins#add-from-github):

```terminal
/plugin marketplace add datum-cloud/skills
/plugin install datum-cloud@datum-cloud
```

The Claude Code plugin also connects Claude to your Datum Cloud projects:

- It starts the [Datum MCP server](https://github.com/datum-cloud/datum-mcp), so there is no MCP setup to do by hand. Install the `datum-mcp` binary first (`brew install datum-cloud/tap/datum-mcp`); it signs you in through your browser on first use.
- It adds the hosted [Datum Docs MCP](https://www.datum.net/docs/agents/datum-mcp#datum-docs-mcp) server, so Claude answers from the current documentation.
- `sign-in` gets you signed in with `datumctl` and `datum-mcp` and pointed at the right organization and project.
- `ci-service-account` sets up a service account for GitHub Actions, other CI systems and headless agents.
- `datum-cloud-assistant` tells Claude when to hand a question to Patch, Datum's own assistant.

### npx skills

Install [`npx skills`](https://skills.sh) CLI to install the skills:

```
npx skills add https://github.com/datum-cloud/skills
```

### Cursor

Install them by manually adding them via **Settings > Rules > Add Rule > Remote Rule (Github)** with `datum-cloud/skills`.

