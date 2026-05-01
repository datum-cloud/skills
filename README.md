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

### npx skills

Install [`npx skills`](https://skills.sh) CLI to install the skills:

```
npx skills add https://github.com/datum-cloud/skills
```

### Cursor

Install them by manually adding them via **Settings > Rules > Add Rule > Remote Rule (Github)** with `datum-cloud/skills`.

