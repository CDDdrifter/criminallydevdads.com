# Firebase setup — exact click-by-click

Google sign-in for criminallydevdads.com. **Free.** No credit card needed.

---

## Who can sign in?

| Who | What happens |
|-----|----------------|
| **Any Google account** | Can sign in to play, save progress, use `/account` |
| **`@criminallydevdads.com` Google email** | Same + **admin** at `/admin` |
| **Emails in `admin_emails`** | Same + **admin** at `/admin` |

Only `/admin` checks the allow list. Everyone else can still sign in with Google.

Extra admins → edit `cms/admin-config.json`, commit, push.

---

# PART A — Firebase website

## Step 1 — Create a project

1. Open **https://console.firebase.google.com**
2. Click **Add project** (or **Create a project**)
3. Name: `criminallydevdads` → **Continue** → **Create project** → **Continue**

You land on **Project Overview**.

## Step 2 — Turn on Google sign-in

1. Left sidebar → **Build** (expand if needed) → **Authentication**
2. Click **Get started** (first time only)
3. Tab **Sign-in method** → click **Google** in the list
4. Toggle **Enable** → pick support email → **Save**

## Step 3 — Allow your website domain

1. Still in **Authentication** → tab **Settings** (top)
2. Scroll to **Authorized domains**
3. Click **Add domain** → type `criminallydevdads.com` → **Add**
4. Add `www.criminallydevdads.com` too if you use www
5. If you use a `github.io` URL, add that domain as well

No `https://` — domain only.

## Step 4 — Register a Web app and copy config

1. Left sidebar → **Project Overview**
2. Click **Web** icon **`</>`** (center of page)  
   — or **Add app** → **Web** `</>` if you already added apps before
3. Nickname: `criminallydevdads-hub`
4. **Do not** check Firebase Hosting
5. Click **Register app**
6. Copy the **firebaseConfig** block — you need these four fields:

```javascript
apiKey: "AIzaSy...",
authDomain: "your-project.firebaseapp.com",
projectId: "your-project-id",
appId: "1:123456789:web:abc123",
```

7. Click **Continue to console**

**Lost the screen?** Gear icon → **Project settings** → **General** → **Your apps** → web app → **Config**.

---

# PART B — Connect Firebase to your live site (the important part)

You do **not** need GitHub secrets for Firebase. Firebase web keys are **public** (safe in the repo). Security comes from **Authorized domains** in Step 3.

## Step 5 — Paste config into the repo

1. Open this file in your project: **`cms/firebase-config.json`**
2. Replace the empty strings with your four Firebase values:

```json
{
  "apiKey": "AIzaSyBxxxxxxxxxxxxxxxxxxxxxxxxxxxx",
  "authDomain": "your-project.firebaseapp.com",
  "projectId": "your-project-id",
  "appId": "1:987654321012:web:a1b2c3d4e5f6g7h8"
}
```

3. **Save the file**
4. **Commit and push** to GitHub (or ask Cursor to do it)
5. Wait for **Deploy to GitHub Pages** to finish (Actions tab → green checkmark)
6. Open **https://criminallydevdads.com** → hard refresh (**Ctrl+Shift+R**)
7. Click **Sign in with Google**

That is it. Anyone with a Google account can sign in once this file is filled in and deployed.

---

## Step 6 — Confirm it worked

| Test | Expected |
|------|----------|
| Homepage → **Sign in with Google** | Google account picker opens, then you are signed in |
| Any Gmail → `/account` | Account page loads |
| `@criminallydevdads.com` → `/admin` | Admin panel |
| Random Gmail → `/admin` | Access denied |

---

# Troubleshooting

### Sign-in button missing
→ `cms/firebase-config.json` is empty or not deployed. Fill in all four fields, commit, push, redeploy.

### “This domain is not authorized” / auth/unauthorized-domain
→ Firebase → Authentication → **Settings** → **Authorized domains** → add the exact domain you visit.

### Google picker opens then fails
→ Google sign-in not enabled (Step 2), or wrong domain (Step 3).

### Admin says Firebase not connected
→ Same as “button missing” — check `cms/firebase-config.json` on GitHub has your values (not empty strings).

### Still using GitHub Actions secrets?
→ Optional backup only. The site reads **`cms/firebase-config.json` first**. If that file has values, secrets are ignored. Prefer the JSON file — it is simpler and matches how Firebase docs expect web apps to work.

### Sign-in goes to Google then returns unsigned in
→ You were using **redirect** sign-in, which breaks on GitHub Pages + custom domain. The site now uses a **popup**. Allow popups for criminallydevdads.com and try again. You do **not** need Firestore for sign-in.

### Popups blocked
→ Browser blocked the Google window. Allow popups for this site, then retry.

---

# What you need for Google sign-in (minimum)

You do **not** need Firestore or Storage just to sign in. Minimum setup:

| Required | Firebase Console step |
|----------|----------------------|
| Yes | Create project + web app (Steps 1, 4) |
| Yes | Enable **Google** sign-in (Step 2) |
| Yes | Add **Authorized domains** — `criminallydevdads.com` and `www.criminallydevdads.com` (Step 3) |
| Yes | Fill in `cms/firebase-config.json` and deploy (Step 5) |
| No (later) | Firestore — comments, cloud saves, live CMS |
| No (later) | Storage — thumbnails / uploads |

**Important:** This site uses a **Google popup** to sign in (not a full-page redirect). Redirect sign-in does not work reliably on GitHub Pages + a custom domain. If sign-in fails, **allow popups** for criminallydevdads.com in your browser.

# What you are NOT setting up (for basic sign-in)

- Firebase Hosting (you use GitHub Pages)
- Cloud game ZIP hosting (games live in `games/` folder)

# What you ARE setting up

- **Firebase Auth** — Google sign-in
- **Firestore** — CMS edits, comments, saves, analytics, services
- **Storage** — thumbnails, preview videos, studio branding assets

See [`FIREBASE_MIGRATION.md`](FIREBASE_MIGRATION.md) for Firestore + Storage enable steps and deploying security rules.

Firebase = **website backend**. Games = **GitHub repo files**.
