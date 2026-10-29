---
name: ci-service-account
description: Set up a Datum Cloud service account so CI, GitHub Actions, a cron job, a Kubernetes workload or a headless agent can run datumctl or datum-mcp without a person signing in. Use when someone wants to deploy to Datum Cloud from a pipeline, write a GitHub Actions workflow that calls datumctl, run datum-mcp on a server, or asks how to authenticate without a browser.
---

# Service accounts for CI and automation

A personal `datumctl login` needs a person to approve it in a browser, so it
cannot run in a pipeline. Unattended jobs sign in as a **service account**: a
machine identity with its own key and only the roles you grant it.

## 1. Create the service account (portal, by the person)

The person creates it in the [Datum Cloud portal](https://cloud.datum.net).
Walk them through it; you cannot do it for them.

1. Open the project, then **Service Accounts** in the sidebar.
2. **Create service account**. Pick the **CI/CD Pipeline** starting point for
   a pipeline, or **Service** for a backend workload.
3. Give it a lowercase name such as `ci-deploy`.
4. Choose **Datum-managed** key. The private key is shown once, so download
   the credentials JSON before closing the wizard.
5. On the account's **Roles** tab, grant only what the job needs.

A service account belongs to one project and cannot list organizations or
other projects. Create one per project the pipeline deploys to.

The credentials file holds a private key. Never write it into the repository,
a workflow file, a log or your reply. Tell the person to put it straight into
their CI system's secret store and delete the local copy.

## 2. Use it

### GitHub Actions

Ask the person to add the file's contents as a repository or environment
secret named `DATUM_SA_CREDENTIALS` (raw JSON or base64). Then:

```yaml
jobs:
  deploy:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4

      - name: Set up datumctl
        uses: datum-cloud/setup-datumctl-action@v1
        with:
          version: v0.15.0
          credentials: ${{ secrets.DATUM_SA_CREDENTIALS }}

      - name: Preview
        run: datumctl diff -f deploy/ --project my-project

      - name: Apply
        run: datumctl apply -f deploy/ --project my-project
```

- The setup step installs `datumctl` and signs in the service account, so
  later steps need no login.
- Pin `version` to a release so runs are reproducible. Check the latest at
  [datumctl releases](https://github.com/datum-cloud/datumctl/releases/latest).
- Pass `--project` on every command. A pipeline should not depend on an
  active context.
- Prefer `apply` and gate with `diff`. `datumctl delete` does not prompt.
- Add `--error-format json` when a later step needs to branch on the failure.

### Any other CI system, or a script

```bash
datumctl login --credentials "$DATUM_CREDENTIALS_FILE"
datumctl get workloads --project my-project
```

Write the secret to a temporary file with `0600` permissions, and remove it
when the job ends. On a runner with no system keyring, datumctl stores the
session in `~/.datumctl/credentials.json`; delete it at the end of a shared
runner's job.

### Kubernetes

```bash
kubectl create secret generic datum-credentials \
  --from-file=credentials.json=/path/to/credentials.json
```

Mount the secret into the pod read-only and run `datumctl login --credentials
/var/secrets/datum/credentials.json` before other commands.

### datum-mcp without a browser

datum-mcp does not read the credentials file itself. Sign in with datumctl,
then hand datum-mcp a token:

```bash
datumctl login --credentials "$DATUM_CREDENTIALS_FILE"
export DATUM_TOKEN="$(datumctl auth get-token)"
export DATUM_API_HOSTNAME=api.datum.net
datum-mcp
```

Both variables are required together. With a service account token,
datum-mcp works in that account's own project, so no organization or project
selection is needed. Tokens expire, so a long-running server needs the token
refreshed.

The token is a live credential. Never print it, echo it, write it to a file
or log, or include it in your reply. Pass it only through the environment as
shown.

## Troubleshooting

| Symptom | Fix |
|---|---|
| `type` is not `datum_service_account` | The file is not a Datum credentials file, or the secret was pasted wrongly. Download a new key. |
| Login works but a command is forbidden | Grant the role on the account's **Roles** tab. |
| A command returns nothing | Missing `--project`, or the account belongs to a different project. Run `datumctl whoami`. |
| The key was leaked or committed | Revoke it on the account's **Keys** tab, add a new key, and update the secret. |

To rotate without downtime: add a new key, update the secret, then revoke the
old key.

## Reference

- [Service accounts](https://www.datum.net/docs/projects/service-accounts)
- [Service accounts in datumctl](https://www.datum.net/docs/datumctl/auth/service-accounts)
- [GitHub Actions](https://www.datum.net/docs/datumctl/cicd/github-actions)
- [Automating datumctl in CI/CD](https://www.datum.net/docs/datumctl/cicd/automating)
