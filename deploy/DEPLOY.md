# Nature Fete — Moving off Render (own VPS, no sleeping, ~$4–6/month)

The Render free tier sleeps after ~15 min idle (30–60s wake-up). A small VPS
runs 24/7, supports WebSockets natively, and costs about the price of one
smoothie per month.

**Recommended VPS (any Ubuntu 22.04/24.04 works):**

| Provider | Spec | Price | Notes |
|---|---|---|---|
| **Hetzner** (best value) | 2 vCPU / 4 GB | **€3.79/mo** | Very reliable, EU/US. Card or PayPal. |
| **DigitalOcean** | 1 vCPU / 1 GB | $6/mo | **$200 free credit** for new accounts (2 months free). |
| **Racknerd** (cheapest) | 1 vCPU / 1 GB | **~$11/YEAR** | Annual deals, US locations, PayPal. |
| **Contabo** | 4 vCPU / 8 GB | ~$5/mo | Most RAM for the money. |

Nigerian cards sometimes get declined abroad — PayPal (linked to a virtual
dollar card) is the most reliable payment method. 1 GB RAM is plenty: the API
uses ~150 MB.

---

## Deploy in 4 steps (~15 minutes)

### 1. Rent the VPS
Choose Ubuntu 24.04, any region (EU is closest to Lagos). Create an SSH key
or use the root password the provider emails you.

### 2. Point your domain
In your domain's DNS panel, add an **A record**:

```
api.yourdomain.com   →   A   →   <your VPS IP>
```

(Use a subdomain like `api.` — your main domain stays free for a website.)

### 3. Run one command on the server
```bash
ssh root@<VPS IP>

apt update && apt install -y git
git clone https://github.com/leafsolar6-oss/luxefeast-delivery.git
cd luxefeast-delivery

sudo ./deploy/deploy.sh api.yourdomain.com
```

It asks for three values — **copy them from the Render dashboard**
(luxefeast-api → Environment):
- `DATABASE_URL` — the Neon connection string (keeps ALL your data: menus, orders, accounts)
- `JWT_SECRET` — copy exactly (keeps everyone logged in, no forced re-logins)
- `FIREBASE_SERVICE_ACCOUNT` — the service-account JSON (keeps push notifications working)

Then it builds and starts everything. HTTPS certificates are automatic
(Let's Encrypt via Caddy) — no setup.

### 4. Verify
```
https://api.yourdomain.com/api/health
→ {"status":"healthy", ..., "push":"firebase"}
```

---

## After the new server is verified

1. Tell me the domain — I rebuild all three APKs pointing at
   `https://api.yourdomain.com` and you install them (last time, promise).
2. Keep the OLD apps working until everyone has updated.
3. Then delete the Render service: dashboard → luxefeast-api → Settings →
   Delete. (Do this only after the new APKs are installed on your phones.)

## Server maintenance (rarely needed)
```bash
cd luxefeast-delivery
git pull && sudo docker compose -f deploy/docker-compose.yml up -d --build  # update
sudo docker compose -f deploy/docker-compose.yml logs -f                    # logs
```
The stack restarts itself if it crashes or the server reboots.
