# 🛠️ Setup — get Stonk Empire online for you and your friends

This version is **real multiplayer**: everyone trades the same live market and
shows up on one leaderboard. That needs a free **Supabase** project (a hosted
database) — no server for you to run or babysit. Total time: ~10 minutes, once.

There are two parts:
1. **Create the backend** (Supabase) — paste in one SQL file.
2. **Connect the app** to it, then host the page so friends can open it.

---

## Part 1 — Create the Supabase backend

1. Go to **https://supabase.com** and sign up (free). Click **New project**.
   - Give it a name (e.g. `stonk-empire`), set a database password (save it), pick a region near you, and create it. Wait ~2 min for it to finish setting up.

2. In your project, open the **SQL Editor** (left sidebar, the `</>` icon) → **New query**.

3. Open the file [`supabase/schema.sql`](supabase/schema.sql) from this project,
   copy **all** of it, paste it into the SQL editor, and click **Run**.
   - You should see "Success. No rows returned." This created every table, the
     trading logic, the leaderboard, and the **market heartbeat** that moves
     prices every 2 minutes.

   > If you get an error mentioning `pg_cron`, go to **Database → Extensions**,
   > search `pg_cron`, toggle it **on**, then run the SQL again.

4. Turn on accounts: go to **Authentication → Sign In / Providers → Email** and
   make sure **Email** is enabled.
   - For playing with friends quickly, you can turn **"Confirm email" OFF**
     (Authentication → Providers → Email) so accounts work instantly without a
     confirmation email. Leave it on if you prefer email verification.

5. Get your keys: **Project Settings → API**. You'll need two values:
   - **Project URL** (looks like `https://abcd1234.supabase.co`)
   - **anon public** key (a long string — this one is safe to share publicly)

---

## Part 2 — Connect and host the app

1. Open [`config.js`](config.js) in this folder and paste your two values:

   ```js
   window.SUPABASE_CONFIG = {
     url:     "https://abcd1234.supabase.co",
     anonKey: "eyJhbGci...your-anon-key...",
   };
   ```

2. **Test it locally first:** double-click `index.html`. The red "Not connected"
   banner should be gone. Create an account, and you should land in the app with
   $1,000. Wait ~2 minutes and prices should move on their own.

3. **Put it online so friends can join.** The app is just static files, so the
   easiest free option is **Netlify Drop**:
   - Go to **https://app.netlify.com/drop**
   - Drag the **`stock-simulator` folder** (the one containing `index.html`,
     `config.js`, and `supabase/`) onto the page.
   - It gives you a public URL — send that to your friends. Done.

   (Alternatives: GitHub Pages, Vercel, or Cloudflare Pages all work the same way.)

4. Each friend opens the URL, clicks **Create account**, picks a display name,
   and they're trading the same market and racing you on the leaderboard. 🏁

---

## Tuning the game (all optional)

Everything is editable in [`supabase/schema.sql`](supabase/schema.sql) — change a
value and re-run that part in the SQL editor:

| Want to change… | Where |
|---|---|
| How often prices move | The `cron.schedule(... '*/2 * * * *' ...)` line (`*/1` = every minute, `*/5` = every 5). |
| Starting cash | `handle_new_user()` and the `profiles.cash` default (currently 1000). |
| Stocks / prices / volatility | The `insert into public.stocks ...` block. |
| Houses & passive income | The `insert into public.home_tiers ...` block (`income_per_tick`). |
| How wild the market is | `v_drift` and the shock math inside `tick_market()`. |

## Troubleshooting

- **Prices never move:** the cron job isn't running. Check **Database → Extensions →
  pg_cron** is on, then re-run the last section of `schema.sql`. You can also run
  `select public.tick_market();` once in the SQL editor to force a move and confirm it works.
- **"Insufficient funds" when you clearly have cash:** you're seeing another
  player's view — refresh; balances are per-account.
- **Friend doesn't appear on the leaderboard:** they need to create an account and
  make at least one move (or just wait one tick).
