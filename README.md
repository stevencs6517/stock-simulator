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
- **Ventures** — gamble on high-risk **startups** (up to 10×) or stable **businesses** for passive income. Ventures occasionally get **acquisition offers** you can accept for a premium.
- **Short selling** — bet against a stock: sell borrowed shares now, buy them back cheaper later. Capped by a simple margin rule (total short exposure can't exceed your net worth).
- **Limit & stop orders** — queue **buy/sell limit** and **stop-loss / buy-stop** orders that the market tick fills automatically when the trigger price is hit.
- **Dividends** — blue-chip "real" stocks (AAPL, NVDA, F, …, marked 💰) pay holders a small payout every tick.
- **Daily login streak** — claim a bonus each day; the reward grows with your streak (caps at 7 days).
- **Achievements** — unlockable milestones with pop-ups and confetti, now **synced to your account** (carry across devices).
- **Daily 12-hour summary** — a recap of how your net worth moved, shown once a day when you open the app.
- **Market drama** — random market-wide events (crashes, bull runs, brainrot hype waves) and large trades that nudge prices.
- **Live leaderboard** — net worth of every friend, ranked, updated in real time, with a **shareable image** (📸 Share) for bragging rights.
- **Polish** — your own net-worth chart, a top-movers ticker, sound effects (mutable), count-up animations, and a 60-second fallback refresh if the live socket drops.

> ⚠️ **Upgrading an existing deployment?** Re-run [`schema.sql`](schema.sql) in your Supabase SQL editor to add the tables/functions for ventures, shorts, orders, dividends, the daily bonus, and synced achievements. It's safe to re-run — your accounts, cash, and holdings are preserved.

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
