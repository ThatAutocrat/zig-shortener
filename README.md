# ⚡ ZigLink — URL Shortener

> *the internet has hundreds of these URL shorteners, but this one is written in Zig, so it's automatically 10x cooler than yours.*

---

## What Is This?

You paste a long URL. ZigLink gives you a short one. Revolutionary, I know. Someone should probably patent this.

Except this one doesn't have a Node.js `node_modules` folder the size of a small country, a React frontend that loads 4MB of JavaScript to render a single `<input>` tag, or a Kubernetes cluster to handle the thundering herd of 3 users.

Just a **single binary**. Written in **Zig**. You're welcome.

---

## How It Works

```
You paste URL → ZigLink generates a 6-char code → stores it in RAM (very cutting-edge)
Someone visits /abc123 → ZigLink looks it up → 302 redirect (wow, such database)
HTMX polls /stats every 3s → updates live → you feel like a hacker
```

Yes, it resets when the server restarts. No, this is not a bug. It's a **feature** called *ephemeral storage* and it sounds much better at conferences.

---

## Stack

| Layer | Choice | Why |
|---|---|---|
| Server | Zig 0.12 stdlib | Because suffering builds character |
| Frontend | HTMX 1.9 via CDN | JavaScript framework count: 0 |
| Styling | Pure CSS (glassmorphism) | It's 2026, we're still doing this |
| Storage | In-memory HashMap | Who needs a database anyway |
| Deploy | Docker | Because Render doesn't speak Zig (rude) |

---

## FAQ

**Q: Is this production-ready?**
A: Absolutely. Ship it.

**Q: What happens to my links when the server restarts?**
A: They ascend to a better place. Spiritually.

**Q: Why Zig?**
A: Why not? Go home, JavaScript.

**Q: Can I use this to shorten `https://google.com`?**
A: You could. You monster.

**Q: Where's the database?**
A: `std.HashMap`. It's in your heart.

## Non-Features (Roadmap: Never)
- ❌ Analytics dashboard (just grep the logs like a real engineer)
- ❌ Custom aliases (you get 6 random chars and you will be grateful)
- ❌ Link expiry (they expire when the server dies, which is soon enough)
- ❌ QR codes (paint it on a wall)
- ❌ REST API (it IS the API)
- ❌ Tests (the code compiles, what more do you want)
---

*Built with Zig, HTMX, and a concerning amount of confidence.*
*Zero npm. Zero frameworks. One binary. Infinite hubris.*
