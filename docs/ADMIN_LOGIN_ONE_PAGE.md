# Log in to `/admin` (current setup)

This site uses **Firebase Google sign-in**, not Supabase. Do these in order.

1. **Firebase is already in the repo**  
   `cms/firebase-config.json` has the web keys. If sign-in is broken, refill that file — see [`FIREBASE_SETUP.md`](FIREBASE_SETUP.md).

2. **Open the real admin URL**  
   **https://criminallydevdads.com/admin**  
   (Not `/#/admin`. Allow popups for this domain.)

3. **Sign in with Google**

4. **You must be allow-listed**  
   - Google address ending in **`@criminallydevdads.com`**, or  
   - Exact email in **`cms/admin-config.json`** → `admin_emails`

   Example commit on GitHub:

   ```json
   {
     "admin_emails": ["you@gmail.com"],
     "admin_domains": ["criminallydevdads.com"]
   }
   ```

5. **To upload game ZIPs into `games/`**  
   Admin → **System** → paste a GitHub Personal Access Token with **`repo`** scope. Full steps: [`HOW_TO_UPDATE.md`](HOW_TO_UPDATE.md).

---

| What you see | What it means |
|--------------|----------------|
| Access denied / not on allow list | Step 4 — add your **exact** Google email, wait for Pages deploy |
| Sign-in button missing | `cms/firebase-config.json` empty or not deployed |
| Domain not authorized | Firebase → Authentication → Settings → Authorized domains → add `criminallydevdads.com` |
| Popup closes, still signed out | Allow popups; try again |
| ZIP upload asks for a token | Step 5 |

**Day-to-day publishing:** [`HOW_TO_UPDATE.md`](HOW_TO_UPDATE.md).
