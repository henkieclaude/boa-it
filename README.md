# Best Online Casinos Australia (BOA-IT)

Static site published at **https://best-onlinecasinoaustralia.it.com/**.

## Project layout

```
.
├── index.html               # The whole site (single page)
├── assets/
│   ├── css/styles.css
│   ├── js/site.js
│   └── logos/               # Operator + partner logos
├── start-server.command     # Local dev: opens Chrome and serves on :8080
├── Caddyfile                # Production web server config (used on the Kimsufi box)
├── deploy/
│   ├── server-setup.sh      # One-time provisioning script for a fresh Ubuntu install
│   └── SETUP.md             # Full step-by-step deploy walkthrough
└── .github/workflows/
    └── deploy.yml           # Auto-deploys to the server on push to main
```

## Local development

Double-click `start-server.command` (macOS) or run:

```bash
python3 -m http.server 8080
```

Then open <http://localhost:8080/>.

## Publishing changes

1. Edit files locally.
2. `git add . && git commit -m "your message" && git push`
3. GitHub Actions rsyncs the new files to the server within ~30 seconds.

First-time deploy? See [`deploy/SETUP.md`](deploy/SETUP.md).
