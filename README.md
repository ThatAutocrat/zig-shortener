# ⚡ ZigLink — URL Shortener

A URL shortener built with a **raw Zig HTTP server** and **HTMX** frontend.
Zero npm. Zero frameworks. One binary.

---

## Run Locally

### Requirements
- [Zig 0.12.0](https://ziglang.org/download/) installed

### Steps
```bash
# Build and run
zig build run

# Server starts at http://localhost:8080
```

---

## Deploy to Render (free, no credit card)

### 1. Push to GitHub
```bash
git init
git add .
git commit -m "init ziglink"
git remote add origin https://github.com/YOUR_USERNAME/ziglink.git
git push -u origin main
```

### 2. Create a Render Web Service
1. Go to [render.com](https://render.com) and sign up
2. Click **New → Web Service**
3. Connect your GitHub repo
4. Set these settings:
   - **Environment:** `Docker`
   - **Instance Type:** Free

### 3. Set Environment Variables in Render
In your Render service → **Environment** tab, add:
```
HOST = your-app-name.onrender.com
PORT = 8080   (Render sets this automatically)
```

### 4. Deploy
Click **Deploy** — Render will build the Docker image and launch your server.
Your app will be live at `https://your-app-name.onrender.com` 🎉

---

## How It Works

```
User pastes URL → POST /shorten → Zig generates 6-char code → stores in memory
User visits /abc123 → Zig looks up code → 302 redirect to original URL
HTMX polls /stats every 3s → updates link count + redirect count live
```

## Stack
| | |
|---|---|
| Server | Zig 0.12 stdlib (`std.http.Server`) |
| Frontend | HTMX 1.9 via CDN |
| Styling | Pure CSS (glassmorphism) |
| Storage | In-memory (resets on restart) |
| Deploy | Docker → Render |

> **Note on free tier:** Render's free tier spins down after 15 mins of inactivity.
> The first request after sleep takes ~30s to wake up. Totally fine for personal use.
