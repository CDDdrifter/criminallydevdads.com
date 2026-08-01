# Firebase setup — exact click-by-click

Google sign-in for criminallydevdads.com. **Free.** No credit card needed for auth.

---

## Who can sign in?

| Who | What happens |
|-----|----------------|
| **Any Google account** | Can sign in to play, save progress, use `/account` |
| **`@criminallydevdads.com` Google email** | Same + **admin** at `/admin` |
| **Emails you add to `admin_emails`** | Same + **admin** at `/admin` |

Players are **not** blocked. Only `/admin` checks the allow list.

Extra admins → edit `cms/admin-config.json`:

```json
{
  "admin_emails": ["your.personal@gmail.com"],
  "admin_domains": ["criminallydevdads.com"]
}
```

Commit and push that file after editing.

---

# PART A — Firebase website (do this first)

## Step 1 — Create a project

1. Open **https://console.firebase.google.com** in Chrome/Edge.
2. Sign in with your Google account.
3. Click the **Add project** button (or **Create a project**).
4. **Project name:** type `criminallydevdads` (or any name you like).
5. Click **Continue**.
6. Google Analytics: **toggle OFF** if you want the fastest setup (optional either way).
7. Click **Create project**.
8. Wait until it says finished → click **Continue**.

You should land on **Project Overview** (big dashboard with your project name at the top).

---

## Step 2 — Turn on Google sign-in

1. Look at the **left sidebar**.
2. Click **Build** to expand it (if it is collapsed).
3. Click **Authentication**.
4. Click the blue **Get started** button (only the first time).
5. You are now on the **Sign-in method** tab.
6. In the list of providers, find **Google** → click the **Google** row (not the toggle yet).
7. Flip the **Enable** switch to **ON**.
8. **Project support email:** pick your email from the dropdown.
9. Click **Save**.

You should see **Google** with status **Enabled** in the list.

---

## Step 3 — Allow your website domain

Still on the **Authentication** page:

1. Click the **Settings** tab at the top (next to **Sign-in method** and **Users**).
2. Scroll down to the section **Authorized domains**.
3. You should already see `localhost` and something like `your-project.firebaseapp.com`.
4. Click **Add domain**.
5. Type: `criminallydevdads.com` → **Add**.
6. If you use www, click **Add domain** again → type `www.criminallydevdads.com` → **Add**.

Do **not** type `https://` — domain only.

---

## Step 4 — Register a Web app and copy your 4 keys

This is the step that connects Firebase to **your** website code.

### 4a — Open Project Overview

1. Click **Project Overview** at the top of the left sidebar (house icon / project name).
2. You should see the main dashboard.

### 4b — Add a Web app

**If you see icons in the middle of the page** (iOS, Android, **Web `</>`**, etc.):

1. Click the **Web** icon — it looks like **`</>`** and says **Web** underneath.

**If you already added an app before** and only see your project stats:

1. Near the top of Project Overview, click **Add app**.
2. Click the **Web** icon **`</>`**.

### 4c — Register the app

1. **App nickname:** type `criminallydevdads-hub`
2. **Firebase Hosting:** leave **unchecked** (you use GitHub Pages, not Firebase Hosting).
3. Click **Register app**.

### 4d — Copy the config (this is the important part)

Firebase shows a code block that starts with something like:

```javascript
const firebaseConfig = {
  apiKey: "AIzaSy...",
  authDomain: "something.firebaseapp.com",
  projectId: "something",
  appId: "1:123456789:web:abc123",
  ...
};
```

**You do NOT paste this whole block into the website.** Copy **only these four values**:

| What you see in Firebase | Copy this part |
|--------------------------|----------------|
| `apiKey:` | The text in quotes after `apiKey:` |
| `authDomain:` | The text in quotes after `authDomain:` |
| `projectId:` | The text in quotes after `projectId:` |
| `appId:` | The text in quotes after `appId:` |

Firebase may also show buttons like **npm**, **CDN**, **Config**. You want the **Config** view with the `firebaseConfig` object.

4. Click **Continue to console** (or **Next** until you can exit — our site already has Firebase installed in code).

### 4e — Find the config again later (if you closed the page)

1. Click the **gear icon** next to **Project Overview** at the top of the left sidebar.
2. Click **Project settings**.
3. Stay on the **General** tab.
4. Scroll down to **Your apps**.
5. You should see your web app `criminallydevdads-hub`.
6. Under **SDK setup and configuration**, choose **Config** (not npm).
7. The same `firebaseConfig` block appears — copy the four values again.

---

## Step 5 — Put the 4 keys in your computer (local testing)

### 5a — Create the file

1. Open your project folder in File Explorer:  
   `C:\Users\DELL\OneDrive\Documents\GitHub\criminallydevdads.com`
2. Right-click empty space → **New** → **Text Document**.
3. Name it exactly: `.env.local`  
   (Windows may warn about changing extension — click **Yes**.)
4. If you cannot create a dot-file, open **Notepad**, paste the content below, then **Save As** → file name `.env.local` → **Save as type: All Files**.

### 5b — Paste this (replace with YOUR four values from Step 4)

```env
VITE_FIREBASE_API_KEY=paste-your-apiKey-here
VITE_FIREBASE_AUTH_DOMAIN=paste-your-authDomain-here
VITE_FIREBASE_PROJECT_ID=paste-your-projectId-here
VITE_FIREBASE_APP_ID=paste-your-appId-here
```

**Example** (yours will be different):

```env
VITE_FIREBASE_API_KEY=AIzaSyBxxxxxxxxxxxxxxxxxxxxxxxxxxxx
VITE_FIREBASE_AUTH_DOMAIN=criminallydevdads.firebaseapp.com
VITE_FIREBASE_PROJECT_ID=criminallydevdads
VITE_FIREBASE_APP_ID=1:987654321012:web:a1b2c3d4e5f6g7h8
```

Rules:
- No quotes around values
- No spaces around the `=`
- One variable per line
- This file must **not** be committed to GitHub (it is already in `.gitignore`)

### 5c — Test on your computer

1. Open a terminal in the project folder.
2. Run: `npm run dev`
3. Open: **http://localhost:5173**
4. Click **Sign in with Google** in the header.
5. Pick a Google account → you should be signed in.

If that works, Firebase is connected locally. Next: live site.

---

# PART B — Live website on GitHub Pages

Your live site is built by **GitHub Actions**. Those builds need the same 4 values as **secrets** (not in the repo).

## Step 6 — Add secrets on GitHub

1. Open: **https://github.com/CDDdrifter/criminallydevdads.com**
2. Click the **Settings** tab (top of the repo — not your profile Settings).
3. Left sidebar → **Secrets and variables** → click **Actions**.
4. Click the green **New repository secret** button.

Create **four separate secrets** — one at a time:

| Secret name (type exactly) | Secret value |
|----------------------------|--------------|
| `VITE_FIREBASE_API_KEY` | your `apiKey` from Firebase |
| `VITE_FIREBASE_AUTH_DOMAIN` | your `authDomain` from Firebase |
| `VITE_FIREBASE_PROJECT_ID` | your `projectId` from Firebase |
| `VITE_FIREBASE_APP_ID` | your `appId` from Firebase |

For each one:
1. **Name:** copy from the table exactly (case-sensitive).
2. **Secret:** paste the value from Firebase.
3. Click **Add secret**.
4. Repeat until all four exist.

You should see four secrets listed under **Repository secrets**.

## Step 7 — Redeploy the live site

Pushing code auto-deploys, but after adding secrets you should run a fresh deploy:

1. In the same GitHub repo, click the **Actions** tab.
2. Left sidebar → click **Deploy to GitHub Pages**.
3. Click **Run workflow** (right side).
4. Branch: **main** → click the green **Run workflow** button.
5. Wait ~2–5 minutes until the run shows a **green checkmark**.
6. Open **https://criminallydevdads.com** (or your Pages URL).
7. Hard refresh: **Ctrl + Shift + R**.
8. Click **Sign in with Google**.

---

# Quick tests

| What you do | What should happen |
|-------------|-------------------|
| Any Gmail → Sign in on homepage | Signed in, name shows in header |
| Your `@criminallydevdads.com` → go to `/admin` | Admin panel opens |
| Random Gmail → go to `/admin` | “Access denied” |
| Personal Gmail in `admin_emails` → `/admin` | Admin panel opens |

---

# Troubleshooting

### “This domain is not authorized”
→ Authentication → **Settings** tab → **Authorized domains** → add the exact domain you are visiting (no `https://`).

### Sign-in button does not appear on live site
→ GitHub secrets missing or deploy ran before secrets were added. Do Step 6 + Step 7 again.

### Sign-in works locally but not on live site
→ Secrets not set on GitHub, or deploy did not finish. Check **Actions** tab for green checkmark.

### Admin says “Access denied”
→ Add your exact Google email to `admin_emails` in `cms/admin-config.json`, commit, push, wait for deploy.

### Popup blocked
→ Allow popups for the site, or try again (the site falls back to full-page redirect).

### I cannot find “Build → Authentication”
→ Try clicking **Authentication** directly in the left sidebar (Firebase sometimes shows it without the Build group).

### I cannot find the Web `</>` icon
→ Go to **Project Overview** → look for **Add app** near the top → click it → choose **Web** `</>`.

---

# What you are NOT setting up

You do **not** need:
- Firebase Hosting (you use GitHub Pages)
- Firestore / Realtime Database
- Firebase Storage (games are in `games/` folder)
- Google Cloud Console OAuth setup (Firebase does this when you enable Google)

Firebase is **only** for “Sign in with Google.”
