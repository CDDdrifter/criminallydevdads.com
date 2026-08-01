# Firebase setup (simple)

Google sign-in for your site. **Free.** No credit card for basic auth.

---

## Who can sign in?

| Who | What they get |
|-----|----------------|
| **Anyone with a Google account** | Can sign in to play, save progress, use `/account` |
| **@criminallydevdads.com email** | Same + **admin** access at `/admin` |
| **Emails you add to the list** | Same + **admin** access at `/admin` |

Players are **not** restricted. Only `/admin` checks the allow list.

To add extra admins, edit `cms/admin-config.json`:

```json
{
  "admin_emails": ["friend@gmail.com", "other@gmail.com"],
  "admin_domains": ["criminallydevdads.com"]
}
```

---

## Setup (one time, ~10 minutes)

### Step 1 — Create Firebase project

1. Open **[console.firebase.google.com](https://console.firebase.google.com)**
2. Click **Add project**
3. Name it (e.g. `criminallydevdads`) → Continue → Create project

### Step 2 — Turn on Google sign-in

1. Left menu: **Build → Authentication**
2. Click **Get started**
3. Tab **Sign-in method** → click **Google** → flip **Enable** → pick a support email → **Save**

That’s it for auth rules — Google accepts **any** Google account by default.

### Step 3 — Add your website domain

Still under **Authentication**:

1. Click **Settings** (top of Authentication page)
2. Scroll to **Authorized domains**
3. Make sure these are listed (add if missing):
   - `localhost` (usually there already)
   - `criminallydevdads.com`
   - `www.criminallydevdads.com` (if you use www)
   - Your GitHub Pages domain if you use it (e.g. `cdddrifter.github.io`)

### Step 4 — Copy 4 values for the website

1. Click the **gear** next to “Project Overview” → **Project settings**
2. Scroll to **Your apps** → click the **`</>` Web** icon
3. App nickname: `criminallydevdads-hub` → **Register app**
4. You’ll see a `firebaseConfig` block. Copy these four:

| Firebase shows | Put in `.env.local` as |
|----------------|-------------------------|
| `apiKey` | `VITE_FIREBASE_API_KEY` |
| `authDomain` | `VITE_FIREBASE_AUTH_DOMAIN` |
| `projectId` | `VITE_FIREBASE_PROJECT_ID` |
| `appId` | `VITE_FIREBASE_APP_ID` |

Example `.env.local` (create this file in the repo root, next to `package.json`):

```env
VITE_FIREBASE_API_KEY=AIzaSyAbc123...
VITE_FIREBASE_AUTH_DOMAIN=criminallydevdads.firebaseapp.com
VITE_FIREBASE_PROJECT_ID=criminallydevdads
VITE_FIREBASE_APP_ID=1:123456789012:web:abc123def456
```

5. Run locally: `npm run dev` → open `http://localhost:5173` → click **Sign in with Google**

### Step 5 — Live site (GitHub Pages)

Same four values go in GitHub as **secrets** (not in the repo):

1. Your repo on GitHub → **Settings → Secrets and variables → Actions**
2. **New repository secret** for each:
   - `VITE_FIREBASE_API_KEY`
   - `VITE_FIREBASE_AUTH_DOMAIN`
   - `VITE_FIREBASE_PROJECT_ID`
   - `VITE_FIREBASE_APP_ID`
3. **Actions** tab → **Deploy to GitHub Pages** → **Run workflow**
4. Wait for green checkmark → hard-refresh your site → try **Sign in with Google**

---

## Quick test

| Test | Expected |
|------|----------|
| Random Gmail signs in on homepage | Works — shows account name |
| `@criminallydevdads.com` goes to `/admin` | Admin panel loads |
| Random Gmail goes to `/admin` | “Access denied” (not an admin) |
| Your Gmail in `admin_emails` → `/admin` | Admin panel loads |

---

## If sign-in fails

**“This domain is not authorized”**  
→ Add your exact domain under Authentication → Settings → Authorized domains.

**Sign-in button missing**  
→ Firebase secrets missing from the build. Check GitHub Actions secrets and redeploy.

**Admin says “Access denied” but you should be admin**  
→ Add your exact Google email to `admin_emails` in `cms/admin-config.json`, commit, redeploy.

**Popup blocked**  
→ Allow popups for your site, or sign-in will fall back to a full-page redirect automatically.

---

## Compared to Supabase (what you had before)

| Supabase | Firebase |
|----------|----------|
| Project URL + anon key (2 values) | 4 values from web app config |
| Redirect URLs in dashboard | Authorized domains list |
| Admin emails in SQL | `cms/admin-config.json` |

Firebase does **not** host your games or database — you only use it for “Sign in with Google.” Games stay in `games.json` + `games/` folder.
