# Firebase setup — Auth, Firestore, Storage

Google sign-in, website CMS edits, comments, cloud saves, analytics, and branding uploads all use **Firebase**. Games stay in `games/` + `games.json` (not Firebase Storage).

See also: [`FIREBASE_SETUP.md`](FIREBASE_SETUP.md) for Auth click-by-click, and [`NO_SUPABASE_SETUP.md`](NO_SUPABASE_SETUP.md) for the full site guide.

---

## What Firebase powers now

| Feature | Firebase service |
|---------|------------------|
| Google sign-in | Auth |
| Admin CMS (settings, pages, nav, devlogs, services) | Firestore |
| User profiles, comments, cloud saves | Firestore |
| First-party analytics | Firestore |
| Thumbnails, videos, studio assets | Storage |
| Game catalog & HTML5 builds | **GitHub** (`games.json` + `games/`) |

---

## One-time Firebase Console setup

### 1. Create project + web app

Follow [`FIREBASE_SETUP.md`](FIREBASE_SETUP.md) Steps 1–4. Copy the four config values into `cms/firebase-config.json`.

### 2. Enable Firestore

1. Firebase Console → **Build** → **Firestore Database**
2. **Create database** → **Start in production mode**
3. Pick a region close to your users (e.g. `us-central1`)

### 3. Enable Storage

1. Firebase Console → **Build** → **Storage**
2. **Get started** → production mode → same region as Firestore

### 4. Deploy security rules

From the repo root (after `npx firebase login` and `npx firebase use <project-id>`):

```bash
npx -y firebase-tools@latest deploy --only firestore:rules,firestore:indexes,storage
```

I've set up prototype Security Rules to keep Firestore and Storage data safe. They restrict CMS writes and asset uploads to `@criminallydevdads.com` admins. Review `firestore.rules` and `storage.rules` before broadly sharing the app.

### 5. Commit config + deploy site

1. Fill in `cms/firebase-config.json` with your four values
2. Commit and push — GitHub Actions builds and deploys to Pages
3. Hard-refresh https://criminallydevdads.com

---

## Admin workflow

| Action | Where it saves |
|--------|----------------|
| Theme, settings, pages, nav, devlogs, services | **Firestore** (live immediately) |
| Games (metadata + catalog) | **GitHub** `games.json` (GitHub PAT) |
| Game HTML5 builds | **GitHub** `games/<slug>/` (Games tab ZIP upload) |

Optional: still use **GitHub sync** (PAT) to snapshot Firestore content into `cms/*.json` for backup — Firestore is the live source when Firebase is configured.

---

## Migrating data from Supabase

If you had content in Supabase Postgres:

1. Export tables as JSON from Supabase dashboard (Table Editor → export)
2. Import into matching Firestore collections (`site_settings/main`, `site_pages/<slug>`, etc.)
3. Or re-enter content in `/admin` — saves go to Firestore

Games in Supabase Storage should be moved to `games/<slug>/` in the repo instead.

---

## Not yet on Firebase (use workarounds)

| Feature | Workaround |
|---------|------------|
| Stripe built-in checkout | Set `purchase_url` / Stripe Payment Links — see `docs/STRIPE_SETUP.md` |
| Mailing broadcast | Export list from Admin → Mailing; send via Resend manually |
| Admin AI copilot | Requires Cloud Functions (future) |

---

## Troubleshooting

**Comments / saves / admin saves fail with permission denied**
→ Deploy rules: `npx firebase deploy --only firestore:rules,storage`
→ Sign in with a `@criminallydevdads.com` Google account for admin writes

**Firebase not configured**
→ `cms/firebase-config.json` is empty or not deployed

**Games don't play**
→ Unrelated to Firebase — check `games/<slug>/index.html` exists

**Thumbnail upload fails**
→ Enable Storage in Console and deploy `storage.rules`
