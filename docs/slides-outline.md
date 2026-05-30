# Slides outline

13 slides plus a live demo slot. Targeting ~30 minutes total: 15-17 min slides, 7 min demo, 5-7 min Q&A. Bullets are speaker anchors, not a script. Narrate around them.

## Slide 1 — Title

**On screen:**
- tailscale-demo-mm
- Identity-based access to private Kubernetes services
- Mike McArthur

**Speaker bullets:**
- Brief who-I-am
- What this is: a take-home demo, built end-to-end on my homelab
- We'll do 10 minutes of context, 7 minutes of live demo, time for Q&A

---

## Slide 2 — The problem, in one sentence

**On screen:**
- Internal tools shouldn't need to be on the public internet
- But the default playbook puts them there anyway

**Speaker bullets:**
- Every company has internal apps that only ten or twenty people need
- Dashboards, admin consoles, developer utilities, support tools
- These get exposed publicly by default because that's the easiest path
- Once they're public, you're managing certs, WAFs, scanning bots, and trusting your app's auth against the whole internet

---

## Slide 3 — The default playbook today

**On screen:**
A three-row table:

| Approach | What it costs |
|---|---|
| Public ingress + auth in front | Cert lifecycle, WAF, attack surface, audit burden |
| VPN | Client OS quirks, IP allowlists, "on the network" trust assumption |
| Bastion + SSH | Key sprawl, jump-host hygiene, manual rotation |

**Speaker bullets:**
- All three approaches share one weakness: they grant access based on where a packet came from, not who sent it
- A laptop on the corporate LAN gets the same trust as a laptop on Starbucks WiFi
- This is the root assumption Tailscale flips

---

## Slide 4 — What I built

**On screen:**
- Two internal apps in my Kubernetes cluster
- Two human identities — admin and contractor — with different access
- Access enforced by Tailscale's policy file, managed in Terraform

**Speaker bullets:**
- The apps are stand-ins for any internal tool
- The admin/contractor split is the typical "who's allowed to see what" decision every company makes
- The policy file is the single source of truth — everything flows from one place

---

## Slide 5 — Architecture diagram

**On screen:**
The architecture diagram from `docs/architecture.png` (the one we already sketched: two laptops, the tailnet, the cluster, the two apps with their tags).

**Speaker bullets:**
- Two services in Kubernetes, each running with a Tailscale sidecar
- The sidecar joins the tailnet directly with a tag — `tag:app-public` or `tag:app-admin`
- Two human users with identities — admin and contractor
- No public ingress, no public DNS, no public TLS cert
- The only thing on the public internet is Tailscale's coordination server, and that just brokers — it doesn't see the traffic

---

## Slide 6 — How traffic flows

**On screen:**
Numbered list, 5 steps:

1. Laptop resolves it-tools to a 100.x tailnet IP via MagicDNS
2. Tailscale checks the policy: is this identity allowed?
3. If yes, WireGuard tunnel directly to the sidecar
4. Sidecar terminates TLS with a real Let's Encrypt cert
5. Sidecar forwards to the app on localhost:80

**Speaker bullets:**
- The policy check happens *before* any packet leaves the laptop
- "Denied" means the packet is never sent — not a TCP reset, not an HTTP 403
- The tunnel is direct WireGuard when possible — peer-to-peer encrypted
- Falls back to a DERP relay if NAT prevents direct, but the keys stay on the endpoints — the relay can't decrypt
- Real Let's Encrypt certs because Tailscale issues them for `*.tail-xxxxx.ts.net`

---

## Slide 7 — LIVE DEMO

**On screen:**
- Live screen-share of both VM windows, chewbaca terminal, and Tailscale admin console
- No slide content — the demo is the content

**Speaker bullets:**
- (Follows `docs/demo-flow.md`)
- Three acts:
  1. Admin reaches both apps
  2. Contractor reaches only it-tools
  3. Revoke contractor → access dies in seconds
- Hit ~6-7 minutes. If running long, skip the restore narration

---

## Slide 8 — What you just saw, in customer terms

**On screen:**
Three short statements:

1. Access decisions are code changes, reviewable in PR
2. Enforcement happens on the user's device, before packets leave
3. Recovery is symmetric — revoke and restore are the same speed

**Speaker bullets:**
- The first one matters for compliance: every grant has a commit history
- The second one matters for security: there's no application to attack from a denied identity
- The third one matters for operations: if you revoke too aggressively, restoring is one PR away — no rebuilds, no key rotation

---

## Slide 9 — Tailscale vs traditional approaches

**On screen:**
Side-by-side table:

| Concern | Bastion + VPN | Tailscale |
|---|---|---|
| Where access is decided | Multiple places (firewall, bastion, app) | One policy file |
| Onboarding a new user | Add to AD, distribute VPN config, SSH key | Add to group in policy |
| Offboarding | Revoke in multiple systems, hope you got them all | Remove from group |
| Where the attack surface lives | Public IP, public cert, exposed services | Tailscale coordination server only |
| What "denied" looks like | TCP/HTTP error from server | Packet never sent |

**Speaker bullets:**
- This isn't bashing VPNs — VPNs are fine for the use case they were designed for
- The point is the *primitive*: VPNs grant access by network location, Tailscale grants by identity
- For internal tools with small audiences, the identity primitive is dramatically simpler

---

## Slide 10 — Where Tailscale doesn't replace existing tools

**On screen:**
- Not an app-layer auth provider — needs a second factor at the app for high-assurance
- Not a WAF — public-facing customer apps still need WAF/CDN
- Not a substitute for device posture on its own — that's a separate enterprise feature
- Coordination plane is SaaS — not for regulated environments that need self-hosted control

**Speaker bullets:**
- Naming the trade-offs builds credibility — vendors who say "yes to everything" lose credibility fast
- For most internal-tool use cases, the gaps above don't matter
- For customer-facing apps, Tailscale's not the right tool — your existing CDN/WAF/auth stack is

---

## Slide 11 — What was difficult or surprising

**On screen:**
Three short items:

1. OAuth client tag scope and policy tagOwners are two separate authorization layers
2. Tailscale operator's Service-exposure mode had unreliable serve-config behavior — pivoted to sidecar pattern
3. Browser caches can mask the moment of revocation — always demo in private mode

**Speaker bullets:**
- The first one cost me an hour of debugging — the error message said "tags invalid" but the real fix was the policy file, not the OAuth client
- The second one is a real product lesson: the documented happy path didn't work, so I shifted to the sidecar pattern, which is what Tailscale's own examples use
- The third one is a presentation lesson — easy to get burned during a live demo if you don't think about it

---

## Slide 12 — What I'd do differently with more time

**On screen:**
- Application-layer auth, layered on top of the network gate
- Device posture checks for the admin group
- Streaming audit logs to a SIEM
- Tailnet Lock for high-assurance environments

**Speaker bullets:**
- The demo gates the network connection, which is necessary but not sufficient for true zero trust
- Each item above adds a layer: app auth handles compromised credentials, posture handles compromised devices, audit logs handle "what happened," Tailnet Lock handles "what if Tailscale itself is compromised"
- For a real customer deployment, you'd layer these in based on their threat model and compliance needs

---

## Slide 13 — Communicating value: different stakeholders, different pitches

**On screen:**
Four short rows:

| Audience | The pitch |
|---|---|
| Platform engineer | "One policy file, GitOps-managed, identity-based" |
| Security team | "No public attack surface, instant revocation, audit by default" |
| CFO | "Replaces three vendors (VPN, bastion, cert mgmt) with one" |
| End user | "Sign in with SSO. Tools work like they always did." |

**Speaker bullets:**
- The same architecture sells differently to different rooms
- Platform engineers care about the operational primitive
- Security cares about the threat model
- CFOs care about vendor consolidation and cost
- End users care that nothing changed for them
- A good SE knows which audience they're in and which framing to lead with

---

## Slide 14 — Q&A

**On screen:**
- Q&A
- Repo: github.com/mikemcarthur/tailscale-demo-mm
- Mike McArthur — contact info

**Speaker bullets:**
- Standard close
- Have a Tailscale-admin-console browser tab ready in case someone wants to see something specific
- If they ask about competitors (Zscaler, Cloudflare Access, Twingate), have a one-sentence framing for each in your head — don't bash them, position Tailscale's distinct take

---

## Timing target

| Slide | Cumulative time |
|---|---|
| 1-3: Opening + problem | 2:00 |
| 4-6: What I built + architecture | 5:00 |
| 7: Live demo | 12:00 |
| 8-10: Takeaways + comparisons + trade-offs | 17:00 |
| 11-13: Findings + value framing | 22:00 |
| 14: Q&A | 22:00 onwards |

If running short, skip the table in slide 13 and just speak the framings. If running long, skip slide 9 entirely — the demo already showed the comparison.

## Presentation notes

- One idea per slide. If something on a slide takes more than 90 seconds to explain, it should be two slides
- Read your slides backward before the call to spot any that contradict each other
- Have the demo backup video ready in case the live demo crashes — same flow, ~6 minutes
- Pre-arrange windows BEFORE joining the call, not during

---

## What I'm not including

- Detailed code walkthroughs — the README does that, and live code review is boring
- Performance benchmarks — irrelevant for this use case
- A live competitor comparison demo — risky and out of scope
- Detailed pricing — not my place to position commercial terms in a demo
