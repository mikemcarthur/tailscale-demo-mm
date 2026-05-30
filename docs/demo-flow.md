# Demo flow

This is my rehearsal runbook for the live demo. The total demo runs 6-8 minutes, sitting inside a ~30-minute presentation that also covers context, architecture, trade-offs, and Q&A.

The demo is fully live. Everything below is what I do on screen, what I say, and what to watch for. There are recovery notes inline for the most common things that could go wrong.

## Before the call

Fifteen minutes before the call:

1. **Both Mint VMs running.** Power them on, log in, give them a minute to settle.
2. **Both VMs on the tailnet.** Open a terminal on each and run `tailscale status`. Confirm both see what they should:
   - admin-laptop: sees admin-laptop, contractor-laptop, it-tools, status-page, k8s-operator-demo
   - contractor-laptop: sees contractor-laptop and it-tools only
3. **Restore the policy if it was left revoked.** From chewbaca: `cd ~/tailscale-demo-mm/terraform && terraform apply` (only if previous rehearsal left things revoked).
4. **Clear Firefox cache in contractor-laptop.** Ctrl+Shift+Delete → clear everything. This prevents cached pages from confusing the revocation moment.
5. **Pre-arrange all four windows on screen:**
   - admin-laptop VM (Firefox + terminal visible)
   - contractor-laptop VM (Firefox + terminal visible)
   - chewbaca terminal at `~/tailscale-demo-mm/terraform/`
   - Browser tab: Tailscale admin console at https://login.tailscale.com/admin → Machines view
6. **In admin-laptop VM:** Two Firefox tabs open, one to each app, both showing the rendered pages. Both visible at the start of the demo.
7. **In contractor-laptop VM:** One Firefox tab open in *private browsing mode*, navigated to it-tools and showing the page rendered. This is the tab we'll revoke later.
8. **In contractor-laptop VM terminal:** Pre-run `watch -n 2 tailscale status`. The continuously-refreshing output is the visual proof during the revocation moment.

Five minutes before the call: do one dry-run of the entire flow below. Then restore everything.

## The flow

### Act 0: Setup framing (30 seconds)

*Share the screen showing all four windows.*

Say:

> "Two virtual machines on my home network. Both running Linux Mint, both running the Tailscale client. The left machine is signed in as my admin account. The right machine is signed in as a contractor account.
>
> On the cluster — separate from these laptops — I have two internal applications. it-tools, a collection of developer utilities. And a status page that shows live cluster information. Neither application has a public DNS record. Neither has a public IP. Neither has a TLS cert from a public CA. They are not on the internet."

### Act 1: Show what admin can do (90 seconds)

*Click into admin-laptop VM. Bring the terminal forward.*

```bash
tailscale status
```

Say:

> "From the admin laptop, here's the tailnet view. You can see both apps as tailnet devices. They have 100.x.y.z IPs in Tailscale's CGNAT range — these aren't routable from the internet."

*Click to Firefox. Show both pages.*

Say:

> "When I open it-tools, here's the rendered page. URL bar shows `it-tools.tail957262.ts.net`. Green padlock. Real Let's Encrypt cert, issued for this internal hostname. Same for the status page — live cluster data, four nodes, kubernetes version, all served from inside the cluster.
>
> No port forwarding. No public ingress. No DNS in Cloudflare or Route 53. The entire access path is identity-mediated by Tailscale."

### Act 2: Show what contractor cannot do (90 seconds)

*Switch to contractor-laptop VM. Bring the terminal forward — the `watch tailscale status` is running and visible.*

Say:

> "Same network. Same building. Same machine type. The only thing different about this laptop is the identity it's signed in as. Watch the tailnet view."

*Pause, let the audience read the watch output.*

Say:

> "Contractor sees only two devices: itself and it-tools. The status page is invisible. It does not appear in the list because the access policy doesn't permit the contractor identity to reach it. There's literally no IP to connect to from this machine's perspective."

*Click to Firefox in contractor-laptop. The private-mode tab is open to it-tools.*

Say:

> "it-tools renders fine. Contractor has been granted access to that one app. Now try the other one."

*In private Firefox, navigate to `https://status-page.tail957262.ts.net`.*

It should fail within seconds with a "Server Not Found" or "Unable to connect" page.

Say:

> "Connection failure. Not an HTTP error code from the server. Not a login screen. The packet doesn't leave the machine. The local Tailscale daemon checked the policy, saw no grant, refused to send.
>
> This is what identity-based access at the network layer looks like. Compared to the traditional bastion-plus-VPN pattern, where the contractor would be on the network and the application would have to enforce auth itself."

### Act 3: The revocation moment (90 seconds)

*Bring the chewbaca terminal forward. It's already in `~/tailscale-demo-mm/terraform`.*

Say:

> "Now I'm going to remove this contractor from the access group entirely. The policy file is in Terraform. I'm editing one variable and running terraform apply.
>
> What you should watch is the contractor's tailnet view on the right. Within seconds of the policy applying, it-tools disappears from the list."

*Run:*

```bash
vi terraform.tfvars
```

In vi, change:
```
contractor_emails = [
  "mike.tsdemo.contractor@gmail.com",
]
```
to:
```
contractor_emails = []
```

Save (`:wq`).

```bash
terraform apply
```

Type `yes` when prompted.

*The apply takes ~5 seconds.*

Say:

> "Apply complete. Watch the contractor's terminal."

*Click to contractor-laptop VM, bring the watch output forward.*

Within 5-10 seconds, the `watch tailscale status` output updates and **it-tools disappears from the contractor's device list**. Now showing only contractor-laptop.

Say:

> "Gone. The contractor's view of the tailnet now shows only its own machine. No it-tools. No way to enumerate. No way to scan. The application still exists in my cluster, but from this identity's perspective it doesn't.
>
> Refresh the Firefox tab to confirm at the application layer."

*Switch to private Firefox tab, hit Ctrl+R.*

The tab fails to load. "Server Not Found" or "Unable to connect."

Say:

> "Same URL that was working 30 seconds ago. Same machine. Same WireGuard tunnel. The only thing that changed is one line in a YAML-like policy file. The Tailscale coordination server pushed the new policy to every device in the tailnet within seconds, and the local daemon enforced it.
>
> In a traditional bastion+VPN setup, this would be a ticket: revoke SSH key on bastion, remove user from VPN AD group, rotate certs that might be cached. Hope you got them all. Here, it's a pull request to the policy file. Reviewed in code review like any other change."

### Act 4: Restore for any later questions (30 seconds)

*Back to chewbaca terminal.*

Say:

> "And to put the contractor back, I revert the change."

*Edit terraform.tfvars to restore the contractor email. Apply.*

```bash
terraform apply
```

Within seconds, contractor's `watch tailscale status` shows it-tools reappearing.

Say:

> "Back. Same speed."

### Wrap (15 seconds)

Say:

> "Three things just happened that are worth sitting with. The access decision was a code change, reviewable. The enforcement was at the network layer, on the contractor's machine, before any packet left. And the recovery from a bad policy is symmetric — same speed forward and back. That's the substance of what I wanted to show."

---

## Recovery notes

### If it-tools doesn't render in admin's Firefox at the start

- Check `kubectl get pods -n tailscale-demo` from chewbaca — confirm both pods are `2/2 Running`
- If the it-tools sidecar restarted, the Let's Encrypt cert may need to re-provision. On admin-laptop: `tailscale cert it-tools.tail957262.ts.net` to force it.
- Worst case: switch to the pre-recorded backup video.

### If contractor's `tailscale status` still shows it-tools after revocation

- Check the live policy in admin console DNS section. If `group:contractor` still has the email, terraform apply didn't take. Re-run it.
- If the policy is correct but the contractor daemon hasn't refreshed, on contractor-laptop: `sudo systemctl restart tailscaled` — this forces a fresh netmap fetch.
- Allow up to 15 seconds of propagation time before showing the failure.

### If the revocation works but Firefox shows a cached page

- This is the cached browser content issue we discovered. Always demo with private browsing.
- If you forgot and a regular tab is open: Ctrl+Shift+Delete to clear cache, then Ctrl+R.

### If `terraform apply` errors

- Most likely cause: another `terraform apply` is somehow already running. Ctrl+C, wait, retry.
- If the OAuth client is rejected: the secret in `terraform.tfvars` may have been rotated. This is a build issue, not a demo issue — pre-flight check should have caught it.

### If anything else breaks

Pause, acknowledge it, and move to the trade-offs slide. The demo is the centerpiece, but the analytical content carries weight too. A graceful "this would be a great moment for me to show you how I think about diagnostics" recovery is better than fumbling at the terminal.

## What I'm explicitly NOT showing in the live demo

These are mentioned in the slides or Q&A but not demoed live to keep the time tight:

- Tailscale SSH (would be its own demo)
- Tailnet Lock (no visible UI to show)
- Device posture (free tier doesn't have it)
- Subnet routers (no traffic to a non-Tailscale resource here)
- Multi-cluster (only one cluster)

These all become talking points in "what I'd do differently with more time."

## Window arrangement target

Imagine a 1920×1080 screenshare:

```
+--------------------------------+--------------------------------+
|                                |                                |
|  admin-laptop VM               |  contractor-laptop VM          |
|  (Firefox + terminal)          |  (Firefox + terminal)          |
|                                |  watch tailscale status running|
|                                |                                |
+--------------------------------+--------------------------------+
|                                |                                |
|  chewbaca terminal             |  Tailscale admin console       |
|  ~/tailscale-demo-mm/terraform |  Machines view                 |
|                                |                                |
+--------------------------------+--------------------------------+
```

Quadrant layout works best. Audience always sees all four contexts. No alt-tabbing surprises.

## Timing reference

If I'm hitting these times on the rehearsal, the demo is paced well:

| Moment | Cumulative time |
|---|---|
| Open: setup framing | 0:30 |
| Admin reaches both apps | 2:00 |
| Contractor reaches only it-tools | 3:30 |
| Hit terraform apply | 4:00 |
| Watch contractor lose it-tools | 4:30 |
| Refresh Firefox, see failure | 5:00 |
| Restore + wrap | 6:30 |

If I'm over by minute 6:00 on the revocation, skip the restore narration and just say "and I'd restore the same way."

If I'm hit 8 minutes, the audience has lost attention. Cut the wrap entirely and move to the next slide.
