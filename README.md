# CRIMINALLYDEV DADS - Game Distribution Hub

## Quick Start

Your website is now a fully functional game distribution platform. Here's how to manage it:

---

## 📋 How to Add a New Game or Asset

### Step 1: Create a Game Folder (IMPORTANT)
1. Go to the `games` folder in your repo.
2. Create a folder for each game using the game id:
   - `games/terracraft/`
   - `games/infinit-orbit/`
3. Put each game's exported web files inside its own folder.
4. Each folder must contain its own `index.html`.

> Do **not** upload games as `index.html.zip` at the root of `games/`.
> This causes collisions because every web export has the same `index.html` filename.

### Step 2: Upload Your Game Files
1. Go to your GitHub repo: https://github.com/CDDdrifter/criminallydevdads.com
2. Click on the game folder you created in Step 1
3. Click "Add file" → "Upload files"
4. Upload all exported web files (`index.html`, `.js`, `.wasm`, assets, etc.)
5. Commit the changes

### Step 3: Edit `games.json`
1. Open `games.json` file in your repo
2. Click the edit (pencil) icon
3. Add a new game entry:

```json
{
  "id": "unique-game-id",
  "title": "My Awesome Game",
  "type": "game",
  "description": "Short one-line description of your game",
  "details": "Longer description with more details about gameplay, features, etc.",
  "thumbnail": "https://image-url.png",
  "filename": "mygame.zip",
  "url": "https://youritch.io/link-optional"
}
```

### Step 4: Commit Your Changes
1. Add a commit message like: "Add My Awesome Game"
2. Click "Commit changes"
3. Done! Your game now appears on the website

---

## 📌 Field Explanation

| Field | Required | Description |
|-------|----------|-------------|
| `id` | ✅ Yes | Unique identifier (no spaces, use hyphens) |
| `title` | ✅ Yes | Game/asset name |
| `type` | ✅ Yes | Either `"game"` or `"asset"` |
| `description` | ✅ Yes | One-line description (shows on card) |
| `details` | ❌ Optional | Longer description (shows in modal) |
| `thumbnail` | ❌ Optional | Image URL (will show placeholder if empty) |
| `filename` | ✅ Yes | Name of your `.zip` file in `/games` folder |
| `url` | ❌ Optional | Link to itch.io or external site |

---

## 🎮 Making Games Playable in Browser

### Option 1: HTML5 Games (Recommended)
If your game is built with HTML5/JavaScript:
1. Export/build for Web/HTML5
2. Make sure output includes `index.html`
3. Create `games/<your-game-id>/`
4. Upload the full exported web build into that folder
5. Set `filename` in `games.json` to `<your-game-id>.zip` (used as folder key)
6. The site will load from `games/<your-game-id>/index.html`

### Option 2: Link to itch.io
If hosting on itch.io:
1. Get the itch.io URL for your game
2. Add it as `"url"` in `games.json`
3. When someone clicks "Play", they go to itch.io

### Option 3: External Hosting
Host games on a CDN or game hosting service and link them in `url` field.

---

## 📝 Example Entry

```json
{
  "id": "space-shooter",
  "title": "Space Shooter Alpha",
  "type": "game",
  "description": "Blast through waves of alien invaders in this retro arcade shooter.",
  "details": "Classic arcade-style space shooter with power-ups, boss battles, and leaderboards. Built with HTML5 canvas.",
  "thumbnail": "https://example.com/space-shooter-banner.png",
  "filename": "space-shooter.zip",
  "url": ""
}
```

---

## 🎨 Customizing the Website

### Change Colors
Edit `index.html` - Look for these color variables in the `<style>` section:
- `#00ff88` = Green accent color
- `#00ffff` = Cyan accent color
- `#ff6b35` = Orange (coming soon buttons)
- `#0a0e27` = Dark background

### Change the Title/Description
Edit the `<h1>` and description text in `index.html`

### Add More Filter Categories
Edit the `.filter-buttons` section and add new JavaScript functions

---

## 💾 File Structure

```
criminallydevdads.com/
├── index.html           (Main website - don't need to edit)
├── game-player.html     (Game viewer - auto-generated)
├── games.json           (YOUR GAME DATABASE - EDIT THIS)
└── games/               (YOUR GAME FOLDERS)
    ├── terracraft/
    │   ├── index.html
    │   ├── index.js
    │   └── ...
    ├── infinit-orbit/
    │   ├── index.html
    │   └── ...
    └── ...
```

---

## 🚀 Deploying Changes

Everything is automatic! When you:
1. Edit `games.json`
2. Upload `.zip` files to `/games` folder
3. The changes appear on your live website within seconds

No rebuild needed. No complicated deployment. Just edit and save.

---

## 💬 Support/Donations (Future)

When you're ready to add payment processing:

1. **For Donations:**
   - Sign up for Stripe or PayPal
   - Get your payment link
   - Replace the "Support the Devs" button in `index.html`

2. **For Paid Games:**
   - Add `"price": 9.99` to game entries in `games.json`
   - Integrate with Gumroad, Stripe, or similar

---

## 🔧 Troubleshooting

**Game doesn't show up:**
- Check `games.json` syntax (copy the example format exactly)
- Make sure the `id` field is unique
- Make sure `.zip` filename matches the `filename` field

**Website looks broken:**
- Clear your browser cache (Ctrl+Shift+Delete)
- Check that `games.json` is valid JSON (use jsonlint.com)

**Still need help?**
- Check the example in `games.json`
- Visit: https://github.com/CDDdrifter/criminallydevdads.com/

---

**Your website is now 100% customizable and ready to scale! 🚀**
