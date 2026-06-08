# 🤑 Stonk Empire — real-time multiplayer stock game

Trade the **same live market as your friends** and race to the biggest net worth.
Everyone is on one shared timeline: when a price moves, it moves for everybody.
No fast-forwarding — prices tick on a real clock every couple of minutes, so you
have to watch, wait, and make smart calls like a real trading app.

## Features

- **Shared live market** — one set of prices for all players, updated server-side every ~2 minutes.
- **Real accounts** — you and your friends sign in; the leaderboard is real people only.
- **Buy low, sell high** — 30+ stocks: real names (NVDA, TSLA, AAPL, …), named picks (Steven Inc., League of Legends, Labubu, Backrooms, …), and a pile of brainrot tickers (Skibidi Toilet, Rizz, Gyatt, Sigma, Ohio, …).
- **Real estate that pays you** — buy properties from a Studio Apartment up to a Beachfront Villa. Each adds to your net worth *and* earns passive income every market tick.
- **Daily 12-hour summary** — a recap of how your net worth moved, shown once a day when you open the app.
- **Achievements** — 12 unlockable milestones (First Trade, Millionaire, Top of the Board, …) with pop-ups and confetti.
- **Market drama** — random market-wide events (crashes, bull runs, brainrot hype waves) and large trades that nudge prices.
- **Live leaderboard** — net worth of every friend, ranked, updated in real time.
- **Polish** — your own net-worth chart, a top-movers ticker, sound effects (mutable), and count-up animations.

## How it's built

- **Frontend:** one static page (`index.html` + `config.js`) — no build step, no framework.
- **Backend:** [Supabase](https://supabase.com) (free) — a hosted Postgres database that holds the shared market, runs the trade logic, and ticks the market on a schedule. There's no server for you to run.

```
stock-simulator/
├── index.html          the app (login + trading UI)
├── config.js           ← paste your Supabase URL + key here
├── supabase/
│   └── schema.sql      ← paste into Supabase once; builds the whole backend
├── SETUP.md            step-by-step setup (≈10 min)
└── serve.ps1           optional local preview server
```

## Getting started

👉 **Follow [SETUP.md](SETUP.md).** Short version:

1. Create a free Supabase project and run [`supabase/schema.sql`](supabase/schema.sql) in its SQL editor.
2. Paste your Supabase URL + anon key into [`config.js`](config.js).
3. Open `index.html` to test, then drop the folder on [Netlify Drop](https://app.netlify.com/drop) to get a public link for your friends.

---
*Fictional market for entertainment. Company names are used parodically; prices are randomly simulated and are not investment advice.*
