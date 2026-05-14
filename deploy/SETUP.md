# Deploy walkthrough — going live on Kimsufi

End-to-end checklist for taking BOA-IT from a folder on your laptop to a live
site at **https://best-onlinecasinoaustralia.it.com/**. Roughly 30–45 minutes
end-to-end, mostly waiting for DNS and apt.

Order matters. Don't skip steps.

---

## 1. Install Ubuntu on the Kimsufi box

In the Kimsufi manager:

1. Open the server → **Netboot** → choose **Boot on hard disk** (default).
2. Open **Reinstall** → pick **Ubuntu Server 24.04 LTS** (or 22.04 LTS — either works).
3. Set a root password (or upload an SSH key — recommended).
4. Wait for the reinstall to finish (~20 min). You'll get an email when it's done.

After reinstall, SSH in to confirm:

```bash
ssh root@<your-kimsufi-ip>
```

If you used a password, change it immediately and create your own user — but
the bootstrap script below also creates the `deploy` user you'll actually use
for deploys, so you can skip that for now.

---

## 2. Create the GitHub repo

On your Mac, from inside the `BOA-IT` folder:

```bash
cd "/Users/sanderpersons/Documents/Documents - Sander's MacBook Air/OGAUS/BOA-IT"
git init
git add .
git commit -m "Initial commit"
```

Create a new **private** repo on github.com (no README, no .gitignore — we
already have ours), then:

```bash
git branch -M main
git remote add origin git@github.com:<YOUR_GITHUB_USER>/boa-it.git
git push -u origin main
```

(If you haven't set up SSH for GitHub on this Mac, use the HTTPS URL instead
and authenticate with a personal access token.)

---

## 3. Bootstrap the server

SSH back into the Kimsufi box as root and run:

```bash
# Replace <YOUR_USER>/<YOUR_REPO> with your actual values
wget https://raw.githubusercontent.com/<YOUR_USER>/<YOUR_REPO>/main/deploy/server-setup.sh
chmod +x server-setup.sh
sudo ./server-setup.sh
```

The script will:

- install Caddy, ufw, fail2ban, rsync
- create a `deploy` user
- generate an SSH keypair for GitHub Actions
- open ports 22, 80, 443 in the firewall
- enable automatic security updates
- drop a "Coming soon" placeholder at `/var/www/best-onlinecasinoaustralia.it.com/`

**Save the output.** At the end it prints:

- The server's public IPv4 address — you'll need this for DNS and GitHub secrets.
- A private SSH key — copy everything between the `BEGIN`/`END` markers.

---

## 4. Point the domain at the server (GoDaddy)

1. Log in to GoDaddy → **My Products** → find `best-onlinecasinoaustralia.it.com` → **DNS**.
2. Delete any existing parked-page A records.
3. Add two A records:

   | Type | Name | Value                       | TTL    |
   |------|------|-----------------------------|--------|
   | A    | @    | `<your-kimsufi-ipv4>`       | 600 s  |
   | A    | www  | `<your-kimsufi-ipv4>`       | 600 s  |

4. Wait 5–15 minutes for propagation. Check with:

   ```bash
   dig +short best-onlinecasinoaustralia.it.com
   dig +short www.best-onlinecasinoaustralia.it.com
   ```

   Both should return your server's IP.

---

## 5. Add GitHub secrets

In the GitHub repo → **Settings** → **Secrets and variables** → **Actions** →
**New repository secret**. Add three:

| Name             | Value                                                    |
|------------------|----------------------------------------------------------|
| `DEPLOY_HOST`    | The Kimsufi IPv4 from step 3                             |
| `DEPLOY_USER`    | `deploy`                                                 |
| `DEPLOY_SSH_KEY` | The full private key from step 3 (BEGIN/END lines included) |

---

## 6. Trigger the first deploy

Either push an empty commit:

```bash
git commit --allow-empty -m "Trigger deploy"
git push
```

…or in GitHub: **Actions** → **Deploy to Kimsufi** → **Run workflow**.

Watch the run in the Actions tab. The first deploy syncs all the files and
pushes the Caddyfile. Caddy then provisions a Let's Encrypt cert (takes
30–60 seconds the first time).

---

## 7. Verify it's live

```bash
curl -I https://best-onlinecasinoaustralia.it.com/
```

Should return `HTTP/2 200`. Open it in a browser to confirm.

If you get cert errors right away, give it another minute — Let's Encrypt
issuance is async. Watch the Caddy log:

```bash
ssh deploy@<your-ip>
sudo journalctl -u caddy -f
```

---

## Troubleshooting

**"Permission denied (publickey)" during GitHub Actions deploy**
The `DEPLOY_SSH_KEY` secret is wrong. Re-copy the private key from
`/home/deploy/.ssh/github_actions` on the server. Include the
`-----BEGIN…-----` and `-----END…-----` lines and the trailing newline.

**Caddy won't get a cert**
DNS hasn't propagated yet, or port 80 is blocked. Re-check `dig` output and
`sudo ufw status`. You can also flip Caddy to the Let's Encrypt staging server
by uncommenting the `acme_ca` line in the Caddyfile — useful for testing
without burning through rate limits.

**The site loads but assets 404**
The rsync excludes `.git`, `.github`, `deploy`, `Caddyfile`, `README.md`,
`start-server.command`, `.gitignore`. Anything else in the repo root gets
synced. If you added a new top-level folder, double-check it isn't excluded.

**Pushing breaks the live site**
The deploy is atomic-ish (rsync `--delete` syncs the whole dir), so the worst
case is a broken HTML file overwriting a working one. Revert the commit and
push again — the next deploy fixes it.

---

## Updating in the future

```bash
# edit files
git add .
git commit -m "Add new operator review"
git push
```

That's it. The site updates within ~30 seconds.
