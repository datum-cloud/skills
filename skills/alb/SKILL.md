# Skill: Application Load Balancer

> **MCP integration:** available. Datum's assistant is entitled to read-only ALB tools through the platform's capability catalog; this skill covers driving `datumctl` directly.

## Description

Create and manage Application Load Balancers on Datum Cloud — take internet traffic on one or more hostnames and send it to origins, with HTTPS, a web application firewall, and optional basic authentication.

An Application Load Balancer is a **product built from several objects**, not a single kind. Prefer `datumctl alb`, which presents it as one thing; drop to raw manifests only for the advanced policies at the end of this document.

## Capabilities

- Create a load balancer and get the hostname to point DNS at
- Attach custom hostnames and follow their verification, DNS and certificate progress
- Add routes and the origins behind them, by URL or by network service
- Configure traffic protection (WAF), request headers and basic authentication
- Read access logs for one load balancer
- Preview every change before applying it
- Attach advanced Envoy Gateway policies the plugin does not cover

## What an ALB is made of

| What you think about | What is stored |
|---|---|
| The load balancer | An `HTTPProxy` you create |
| Its generated hostname | `status.canonicalHostname` |
| A custom hostname | `spec.hostnames[]`, progress in `status.hostnameStatuses[]` |
| A route | One `spec.rules[]` entry: a path prefix and its origins |
| An origin | A URL, or a `NetworkService` and one of its declared **port names** |
| Force HTTPS | An extra redirect rule with no origins |
| Traffic protection | A `TrafficProtectionPolicy` attached to the load balancer |
| Basic auth | A `SecurityPolicy` and a `<name>-basic-auth` Secret |

You never name or edit the routing objects Datum derives from the `HTTPProxy`.

## The everyday commands

```bash
datumctl alb create my-app --endpoint https://origin.example.com
datumctl alb list
datumctl alb describe my-app
datumctl alb update my-app --display-name "Production API"
datumctl alb delete my-app --yes
```

`create` waits for the generated hostname (`<id>.datumproxy.net`) — that is what you CNAME at. Defaults match the portal: Force HTTPS on, traffic protection in `Enforce` at paranoia 1.

Omit the name and pass `--display-name` to derive a DNS-safe name the way the portal does. The printed message shows the name that was used; **carry it forward**, because it includes a random suffix and re-deriving gives a different one.

### Hostnames

```bash
datumctl alb hostname add my-app app.example.com
datumctl alb hostname list my-app
datumctl alb hostname remove my-app app.example.com
```

Two ways a hostname reaches a load balancer, and they fail differently:

- **Your own DNS** — create a CNAME to the generated hostname. Datum writes nothing. At a zone apex a CNAME is not legal; use ALIAS/ANAME if your provider offers it, or a subdomain.
- **A custom hostname** — prove you own the domain, then it goes through claim → ownership → DNS record → certificate, each gating the next.

`describe` prints each custom hostname with its available / DNS / certificate status.

### Routes and origins

```bash
datumctl alb route list my-app
datumctl alb route add my-app --path /api --endpoint https://api.example.com
datumctl alb route update my-app --path / --network-service storefront --port http
datumctl alb route remove my-app --path /api
datumctl alb route backend add my-app --path /api --endpoint https://api-2.example.com
```

`--port` is the port **name** the service declares (`http`), never a number. Datum never creates a `NetworkService`; naming one that does not exist fails before anything is written.

`route update` replaces every origin on that path and leaves other routes alone.

A route takes up to 16 origins and splits traffic across them, with one constraint that decides whether a pool works: **every origin in a route must agree on the Host header sent upstream.** NetworkService origins need no Host rewrite, so pools of those are fine. A URL origin takes its Host from its own hostname, so two URL origins on different hostnames conflict — and the load balancer does not reject the change. It keeps serving what it published last and explains why in the status message, while the reason still reads as though it were waiting.

Two ways round it, one of which is a trap:

- **Give each origin its own route.** Safe.
- **Set a Host override on the route.** The origins then agree and it publishes, but all of them receive the same Host, so any origin that serves by hostname (Vercel, Netlify, Fly.io, Cloudflare Pages) answers the wrong site or a 404. It looks like it worked.

A connector origin must be the only origin in its route.

### Traffic protection, headers, auth, logs

```bash
datumctl alb waf set my-app --mode Observe --paranoia 1
datumctl alb waf describe my-app
datumctl alb header set my-app Host=origin.example.com
echo 'secret' | datumctl alb auth set my-app --user admin --password-stdin
datumctl alb logs my-app --since 1h --code 502
```

Passwords are never printed and must come from stdin — never put one in a command line or a manifest. Every `--user` in one command gets the same password, and `auth set` replaces the whole user list rather than merging, so pass every user you want to keep.

`tpp` is an alias for `waf`. `--paranoia` sets the blocking and detection levels together and takes 1 to 4, but the portal offers only 1 and 2.

## Reading status without getting it wrong

Three properties of this API produce confident wrong answers. They matter whether you use the plugin or raw manifests:

- **Top-level conditions aggregate and name nothing.** `DNSRecordsProgrammed=PartialFailure` and `CertificatesReady=CertificatesPending` mean "one or more hostnames". Which one is in `status.hostnameStatuses[]`. Always resolve to the hostname before reporting.
- **`HostnamesInUse` is true when something is wrong.** Every other condition here is true when healthy, so a general "not True means broken" check silently treats a hostname collision as fine.
- **`DNSZoneNotFound` and `NotApplicable` are set True on purpose.** They mean Datum does not run that domain's DNS — a normal arrangement. Not a fault, and not something to wait for.

Also: the same reason word means different things on different conditions. `Pending` on `Accepted` means nothing has reconciled; on a hostname's `CertificateReady` it means the certificate is not issued. Always read the condition type with the reason.

Two things status does not report at all: whether Datum's edge can actually serve the load balancer (conditions go true while the edge is still converging, and no window is published — confirm with a request), and a generated hostname's DNS record (no condition exists, so its absence means nothing).

## Advanced: policies the plugin does not cover

Attach these by manifest when you need rate limiting, OIDC, or WAF rule tuning. All attach via `targetRefs` to the Gateway derived from the load balancer, which carries the same name.

### WAF rule exclusions and score thresholds

```yaml
apiVersion: networking.datumapis.com/v1alpha
kind: TrafficProtectionPolicy
metadata:
  name: my-app
  namespace: default
spec:
  mode: Enforce
  ruleSets:
    - type: OWASPCoreRuleSet
      owaspCoreRuleSet:
        paranoiaLevels:
          detection: 2
          blocking: 1
        ruleExclusions: [942100, 920350]
  targetRefs:
    - group: gateway.networking.k8s.io
      kind: Gateway
      name: my-app
```

Keep `detection` at or above `blocking`, so you can preview stricter rules in the logs before enforcing them.

### Rate limiting and circuit breaking

```yaml
apiVersion: gateway.envoyproxy.io/v1alpha1
kind: BackendTrafficPolicy
metadata:
  name: traffic-control
  namespace: default
spec:
  rateLimit:
    - action: Deny
      limit: { requests: 100, unit: Hour }
      clientSelectors:
        - headers: [{ name: x-user-id }]
  circuitBreaker:
    maxConnections: 500
    maxPendingRequests: 100
    maxRequests: 1000
    maxRetries: 3
  targetRefs:
    - group: gateway.networking.k8s.io
      kind: Gateway
      name: my-app
```

### Authentication beyond basic auth

`SecurityPolicy` (`gateway.envoyproxy.io/v1alpha1`) carries JWT, OIDC, API key and external authorization. `datumctl alb auth` covers basic auth only; anything else is a manifest. See the Datum guides for OIDC with Google or Auth0.

```bash
datumctl get securitypolicies --project <project-id>
datumctl describe securitypolicy <name> --project <project-id>
```

## Driving this from a script or an agent

Four behaviours will catch you out if you key off exit status or assume a prompt:

- **`create` can exit non-zero having created the load balancer.** With the default `--wait`, a timeout waiting for the generated hostname is an error, but the object exists. Do not retry `create` — run `describe` first, or pass `--no-wait` and poll.
- **`create` is not atomic.** If the load balancer is created and traffic protection then fails to attach, the command exits non-zero and leaves an unprotected load balancer behind. Check `waf describe` after a failed create.
- **Confirmation prompts assume yes with no terminal.** `route remove` and `route backend remove` proceed in CI. Only `delete` refuses without `--yes`.
- **Adding a second URL origin succeeds even when it cannot be published.** The Host conflict above is caught at publish time, not at write time, so check `describe` afterwards.

Every writing command takes `--dry-run`, which validates against the API and discards the change. Use it before anything destructive.

Failures print a named exit code — `exit status 6 # ALB_INVALID`. The names are `ALB_USAGE` (2), `ALB_FORBIDDEN` (3), `ALB_NOT_FOUND` (4), `ALB_CONFLICT` (5), `ALB_INVALID` (6), `ALB_UNAVAILABLE` (8), `ALB_ABORTED` (9).

## Constraints & Guardrails

- Always use `datumctl` — never `kubectl`
- `--project` is required, or select one with `datumctl ctx use`
- `networking.datumapis.com/v1alpha` and `gateway.envoyproxy.io/v1alpha1` are unstable; field names may change between releases
- Prefer `datumctl alb` over raw manifests
- The portal edits one route with one origin and cannot show more. It does not lock the form: editing the origin, TLS or redirect settings there rebuilds the route list from the fields it models and drops extra routes, extra origins, weights and path matches, reporting success. After adding a route or a pool, tell the user that hostnames, protection and auth stay safe to edit in the portal and origin, TLS and redirect do not
- Traffic protection takes paranoia 1 to 4 here; the portal offers only 1 and 2
- Run `datumctl diff -f` before `apply`, and validate with `--dry-run=server`
- `delete` has no confirmation prompt — verify the name first. Deleting a load balancer also removes its traffic protection policy and basic auth
- Start traffic protection in `mode: Observe` on a live site, watch real traffic, then move to `Enforce`. Raise paranoia one level at a time; above 2 the false-positive rate climbs sharply
- Never put a password in a command line or a manifest — `--password-stdin` only
- Datum never creates a `NetworkService` or a `Domain` for you
- A certificate cannot be issued until the hostname resolves publicly to the load balancer, so a stuck certificate is usually a DNS problem

## See Also

- [Application Load Balancer documentation](https://www.datum.net/docs/alb/overview.md)
- [`datumctl` overview](https://www.datum.net/docs/datumctl/overview.md)
- [Envoy Gateway SecurityPolicy](https://gateway.envoyproxy.io/docs/api/extension_types/#securitypolicy)
- [OWASP Core Rule Set](https://coreruleset.org/)
