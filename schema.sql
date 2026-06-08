-- ============================================================================
--  STEVEN'S STOCK SIMULATOR — Supabase schema
--  Paste this whole file into the Supabase SQL Editor and click "Run".
--  Safe to re-run: it preserves existing accounts, cash, and holdings while
--  migrating new stocks, renamed properties, the 12-hour summary, etc.
-- ============================================================================

-- ---------- Extensions ----------
create extension if not exists pg_cron;

-- ============================================================================
--  TABLES
-- ============================================================================
create table if not exists public.profiles (
  id           uuid primary key references auth.users(id) on delete cascade,
  display_name text not null,
  cash         numeric not null default 1000,
  home_tier    int not null default 0,
  created_at   timestamptz not null default now()
);

create table if not exists public.stocks (
  symbol     text primary key,
  name       text not null,
  price      numeric not null,
  prev_price numeric not null,
  vol        numeric not null,
  goofy      boolean not null default false,
  sort       int not null default 0
);

create table if not exists public.price_history (
  id     bigserial primary key,
  symbol text not null references public.stocks(symbol) on delete cascade,
  price  numeric not null,
  ts     timestamptz not null default now()
);
create index if not exists price_history_symbol_ts on public.price_history(symbol, ts);

create table if not exists public.holdings (
  user_id    uuid not null references public.profiles(id) on delete cascade,
  symbol     text not null references public.stocks(symbol) on delete cascade,
  shares     numeric not null,
  cost_basis numeric not null,
  primary key (user_id, symbol)
);

create table if not exists public.home_tiers (
  tier            int primary key,
  name            text not null,
  emoji           text not null,
  price           numeric not null,
  income_per_tick numeric not null default 0
);

-- Net-worth snapshots, written every market tick. Powers the 12-hour summary.
create table if not exists public.networth_snapshots (
  id        bigserial primary key,
  user_id   uuid not null references public.profiles(id) on delete cascade,
  net_worth numeric not null,
  ts        timestamptz not null default now()
);
create index if not exists nws_user_ts on public.networth_snapshots(user_id, ts);

-- Per-stock "news" ticker has been removed. Drop it from realtime, then drop it.
do $$ begin
  if exists (select 1 from pg_publication_tables
             where pubname='supabase_realtime' and schemaname='public' and tablename='market_news') then
    alter publication supabase_realtime drop table public.market_news;
  end if;
end $$;
drop table if exists public.market_news cascade;

-- Dramatic market-wide events (crash / boom / hype wave / rally) shown as a banner.
create table if not exists public.market_events (
  id    bigserial primary key,
  kind  text not null,
  title text not null,
  ts    timestamptz not null default now()
);

-- RNG ventures: high-risk startups & stable businesses that pay passive income.
create table if not exists public.ventures (
  id              bigserial primary key,
  user_id         uuid not null references public.profiles(id) on delete cascade,
  kind            text not null,        -- 'startup' | 'business'
  name            text not null,
  invested        numeric not null,
  value           numeric not null,     -- current value (counts toward net worth)
  income_per_tick numeric not null,
  created_at      timestamptz not null default now()
);
create index if not exists ventures_user on public.ventures(user_id);

-- Acquisition offers: a venture can occasionally get a buyout offer the player may accept.
alter table public.ventures add column if not exists offer_value   numeric;
alter table public.ventures add column if not exists offer_expires timestamptz;

-- Daily login streak + bonus.
alter table public.profiles add column if not exists streak     int  not null default 0;
alter table public.profiles add column if not exists last_bonus  date;

-- Dividends: real (non-goofy) stocks pay a small yield each tick to holders.
alter table public.stocks add column if not exists div_yield numeric not null default 0;

-- Short positions: sell-borrowed shares now, buy them back later. Tracked
-- separately from holdings so long-position logic stays untouched.
create table if not exists public.shorts (
  user_id  uuid not null references public.profiles(id) on delete cascade,
  symbol   text not null references public.stocks(symbol) on delete cascade,
  shares   numeric not null,   -- borrowed shares still open (positive)
  proceeds numeric not null,   -- cash received when the short was opened
  primary key (user_id, symbol)
);

-- Pending limit / stop orders, executed by the market tick when the trigger hits.
create table if not exists public.orders (
  id            bigserial primary key,
  user_id       uuid not null references public.profiles(id) on delete cascade,
  symbol        text not null references public.stocks(symbol) on delete cascade,
  side          text not null,            -- 'buy' | 'sell'
  kind          text not null,            -- 'limit' | 'stop'
  qty           int  not null,
  trigger_price numeric not null,
  created_at    timestamptz not null default now()
);
create index if not exists orders_pending on public.orders(symbol);

-- Cloud-synced achievements (replaces the old localStorage-only store).
create table if not exists public.user_achievements (
  user_id     uuid not null references public.profiles(id) on delete cascade,
  ach_id      text not null,
  unlocked_at timestamptz not null default now(),
  primary key (user_id, ach_id)
);

-- ============================================================================
--  SEED: STOCKS  (new symbols added; existing prices left untouched)
-- ============================================================================
insert into public.stocks (symbol, name, price, prev_price, vol, goofy, sort) values
  -- ⭐ featured
  ('STEVN', 'Steven Inc.',          420.69, 420.69, 0.050, true,  0),
  -- real-world (parody)
  ('NVDA',  'Nvidia',               135.00, 135.00, 0.032, false, 1),
  ('TSLA',  'Tesla',                242.00, 242.00, 0.045, false, 2),
  ('AAPL',  'Apple',                196.00, 196.00, 0.016, false, 3),
  ('AMZN',  'Amazon',               178.00, 178.00, 0.024, false, 4),
  ('AMD',   'AMD',                  118.00, 118.00, 0.035, false, 5),
  ('GME',   'GameStop',              24.00,  24.00, 0.075, false, 6),
  ('F',     'Ford Motor',            11.20,  11.20, 0.020, false, 7),
  -- named fun stocks
  ('LOL',   'League of Legends',     95.00,  95.00, 0.060, true,  8),
  ('SOPH',  'Sophia Corp',           88.00,  88.00, 0.040, true,  9),
  ('LABU',  'Labubu Holdings',       58.00,  58.00, 0.110, true, 10),
  ('OBSN',  'Obsession Co.',         33.00,  33.00, 0.090, true, 11),
  ('BCKR',  'The Backrooms',          6.20,   6.20, 0.130, true, 12),
  -- brainrot
  ('SKBD',  'Skibidi Toilet',        17.00,  17.00, 0.140, true, 13),
  ('RIZZ',  'Rizz Industries',       12.00,  12.00, 0.120, true, 14),
  ('GYATT', 'Gyatt Corp',             8.00,   8.00, 0.130, true, 15),
  ('SIGMA', 'Sigma Grindset',        45.00,  45.00, 0.070, true, 16),
  ('OHIO',  'Ohio Holdings',          3.33,   3.33, 0.160, true, 17),
  ('FANUM', 'Fanum Tax LLC',          6.66,   6.66, 0.120, true, 18),
  ('MEWING','Mewing Inc.',           21.00,  21.00, 0.090, true, 19),
  ('SUS',   'Sus Ventures',           4.20,   4.20, 0.150, true, 20),
  ('NOCAP', 'No Cap Capital',        14.00,  14.00, 0.100, true, 21),
  ('BUSSIN','Bussin Foods',           9.00,   9.00, 0.110, true, 22),
  ('SHEESH','Sheesh Co.',             7.77,   7.77, 0.130, true, 23),
  ('DELULU','Delulu Labs',           11.00,  11.00, 0.140, true, 24),
  ('MID',   'Mid Corp',               2.50,   2.50, 0.080, true, 25),
  ('AURA',  'Aura Points Inc.',     100.00, 100.00, 0.100, true, 26),
  ('NPC',   'NPC Industries',         5.00,   5.00, 0.060, true, 27),
  ('MOGGER','Mogger Maxx',           19.00,  19.00, 0.120, true, 28),
  ('GRMC',  'Grimace Shake Co.',     13.00,  13.00, 0.150, true, 29),
  ('YAP',   'Yapping Yards',          6.00,   6.00, 0.110, true, 30)
on conflict (symbol) do nothing;

-- Dividend yields: blue-chip "real" stocks pay a little every tick; meme stocks don't.
update public.stocks set div_yield = 0.0006 where symbol = 'AAPL';
update public.stocks set div_yield = 0.0005 where symbol = 'NVDA';
update public.stocks set div_yield = 0.0007 where symbol = 'AMD';
update public.stocks set div_yield = 0.0009 where symbol = 'F';
update public.stocks set div_yield = 0.0004 where symbol in ('TSLA','AMZN');
update public.stocks set div_yield = 0.0008 where symbol = 'GME';

-- ============================================================================
--  SEED: PROPERTIES  (professional names; re-run updates names, keeps prices)
-- ============================================================================
insert into public.home_tiers (tier, name, emoji, price, income_per_tick) values
  (0, 'No Property',          '🏷️', 0,         0),
  (1, 'Studio Apartment',     '🏢', 750,       1),
  (2, 'One-Bed Condo',        '🏬', 4000,      5),
  (3, 'Suburban Townhouse',   '🏘️', 15000,     18),
  (4, 'Detached Family Home', '🏠', 60000,     75),
  (5, 'Luxury Loft',          '🏙️', 250000,    300),
  (6, 'Lakeside Estate',      '🏡', 900000,    1100),
  (7, 'Downtown Penthouse',   '🌆', 3500000,   4500),
  (8, 'Private Mansion',      '🏰', 12000000,  16000),
  (9, 'Beachfront Villa',     '🏝️', 50000000,  70000)
on conflict (tier) do update
  set name = excluded.name, emoji = excluded.emoji, income_per_tick = excluded.income_per_tick;

-- ============================================================================
--  NEW-USER TRIGGER
-- ============================================================================
create or replace function public.handle_new_user()
returns trigger language plpgsql security definer set search_path = public as $$
begin
  insert into public.profiles (id, display_name, cash, home_tier)
  values (new.id,
          coalesce(nullif(new.raw_user_meta_data->>'display_name',''), split_part(new.email,'@',1)),
          1000, 0)
  on conflict (id) do nothing;
  return new;
end; $$;

drop trigger if exists on_auth_user_created on auth.users;
create trigger on_auth_user_created
  after insert on auth.users for each row execute function public.handle_new_user();

-- ============================================================================
--  TRADING / REAL-ESTATE RPCs
-- ============================================================================
-- Single source of truth for net worth: cash + holdings + property + ventures
-- − open short liability. Used by the leaderboard, snapshots and seeds.
create or replace function public.user_net_worth(p_uid uuid)
returns numeric language sql stable security definer set search_path = public as $$
  select coalesce((select cash from public.profiles where id = p_uid), 0)
    + coalesce((select sum(h.shares * s.price) from public.holdings h
                join public.stocks s on s.symbol = h.symbol where h.user_id = p_uid), 0)
    + coalesce((select ht.price from public.profiles p
                join public.home_tiers ht on ht.tier = p.home_tier where p.id = p_uid), 0)
    + coalesce((select sum(v.value) from public.ventures v where v.user_id = p_uid), 0)
    - coalesce((select sum(sh.shares * s.price) from public.shorts sh
                join public.stocks s on s.symbol = sh.symbol where sh.user_id = p_uid), 0);
$$;

-- Internal trade primitives (no auth check) so the market tick can fill orders
-- on a player's behalf and the public RPCs can reuse the exact same logic.
create or replace function public._exec_buy(p_uid uuid, p_symbol text, p_qty int)
returns void language plpgsql security definer set search_path = public as $$
declare v_price numeric; v_cost numeric; v_cash numeric;
begin
  select price into v_price from public.stocks where symbol = p_symbol;
  if v_price is null then raise exception 'Unknown symbol %', p_symbol; end if;
  v_cost := v_price * p_qty;
  select cash into v_cash from public.profiles where id = p_uid for update;
  if v_cash < v_cost then raise exception 'Insufficient funds'; end if;
  update public.profiles set cash = cash - v_cost where id = p_uid;
  insert into public.holdings (user_id, symbol, shares, cost_basis)
  values (p_uid, p_symbol, p_qty, v_cost)
  on conflict (user_id, symbol)
  do update set shares = public.holdings.shares + excluded.shares,
                cost_basis = public.holdings.cost_basis + excluded.cost_basis;
  -- market impact: big buys nudge the price up (capped at +4%)
  update public.stocks
    set price = round((price * (1 + least(0.04, v_cost / 2000000.0)))::numeric, 2)
    where symbol = p_symbol;
end; $$;

create or replace function public._exec_sell(p_uid uuid, p_symbol text, p_qty int)
returns void language plpgsql security definer set search_path = public as $$
declare v_price numeric; v_shares numeric; v_basis numeric; v_avg numeric; v_proceeds numeric;
begin
  select shares, cost_basis into v_shares, v_basis
    from public.holdings where user_id = p_uid and symbol = p_symbol for update;
  if v_shares is null or v_shares < p_qty then raise exception 'You do not own that many shares'; end if;
  select price into v_price from public.stocks where symbol = p_symbol;
  v_proceeds := v_price * p_qty;
  v_avg := v_basis / v_shares;
  update public.profiles set cash = cash + v_proceeds where id = p_uid;
  if v_shares = p_qty then
    delete from public.holdings where user_id = p_uid and symbol = p_symbol;
  else
    update public.holdings set shares = shares - p_qty, cost_basis = cost_basis - v_avg * p_qty
      where user_id = p_uid and symbol = p_symbol;
  end if;
  -- market impact: big sells nudge the price down (capped at -4%)
  update public.stocks
    set price = greatest(0.05, round((price * (1 - least(0.04, v_proceeds / 2000000.0)))::numeric, 2))
    where symbol = p_symbol;
end; $$;

create or replace function public.buy_stock(p_symbol text, p_qty int)
returns void language plpgsql security definer set search_path = public as $$
declare v_uid uuid := auth.uid();
begin
  if v_uid is null then raise exception 'Not signed in'; end if;
  if p_qty is null or p_qty <= 0 then raise exception 'Quantity must be a positive whole number'; end if;
  perform public._exec_buy(v_uid, p_symbol, p_qty);
end; $$;

create or replace function public.sell_stock(p_symbol text, p_qty int)
returns void language plpgsql security definer set search_path = public as $$
declare v_uid uuid := auth.uid();
begin
  if v_uid is null then raise exception 'Not signed in'; end if;
  if p_qty is null or p_qty <= 0 then raise exception 'Quantity must be a positive whole number'; end if;
  perform public._exec_sell(v_uid, p_symbol, p_qty);
end; $$;

-- ---------- SHORT SELLING ----------
-- Open/extend a short: receive cash now, owe the shares later. Capped so a
-- player's total short liability can't exceed their net worth (simple margin).
create or replace function public.short_stock(p_symbol text, p_qty int)
returns void language plpgsql security definer set search_path = public as $$
declare v_uid uuid := auth.uid(); v_price numeric; v_proceeds numeric; v_nw numeric; v_liab numeric;
begin
  if v_uid is null then raise exception 'Not signed in'; end if;
  if p_qty is null or p_qty <= 0 then raise exception 'Quantity must be a positive whole number'; end if;
  select price into v_price from public.stocks where symbol = p_symbol;
  if v_price is null then raise exception 'Unknown symbol %', p_symbol; end if;
  v_proceeds := v_price * p_qty;
  -- margin check: existing liability + this new short must stay within net worth
  v_nw := public.user_net_worth(v_uid);
  v_liab := coalesce((select sum(sh.shares * s.price) from public.shorts sh
                      join public.stocks s on s.symbol = sh.symbol where sh.user_id = v_uid), 0);
  if v_liab + v_proceeds > v_nw then
    raise exception 'Not enough margin to short that much';
  end if;
  update public.profiles set cash = cash + v_proceeds where id = v_uid;
  insert into public.shorts (user_id, symbol, shares, proceeds)
  values (v_uid, p_symbol, p_qty, v_proceeds)
  on conflict (user_id, symbol)
  do update set shares = public.shorts.shares + excluded.shares,
                proceeds = public.shorts.proceeds + excluded.proceeds;
  update public.stocks
    set price = greatest(0.05, round((price * (1 - least(0.04, v_proceeds / 2000000.0)))::numeric, 2))
    where symbol = p_symbol;
end; $$;

-- Cover (buy back) a short, realising profit/loss vs. the current price.
create or replace function public.cover_short(p_symbol text, p_qty int)
returns void language plpgsql security definer set search_path = public as $$
declare v_uid uuid := auth.uid(); v_price numeric; v_shares numeric; v_proceeds numeric;
        v_cost numeric; v_cash numeric; v_avg numeric;
begin
  if v_uid is null then raise exception 'Not signed in'; end if;
  if p_qty is null or p_qty <= 0 then raise exception 'Quantity must be a positive whole number'; end if;
  select shares, proceeds into v_shares, v_proceeds
    from public.shorts where user_id = v_uid and symbol = p_symbol for update;
  if v_shares is null or v_shares < p_qty then raise exception 'You are not short that many shares'; end if;
  select price into v_price from public.stocks where symbol = p_symbol;
  v_cost := v_price * p_qty;
  select cash into v_cash from public.profiles where id = v_uid for update;
  if v_cash < v_cost then raise exception 'Insufficient funds to cover'; end if;
  v_avg := v_proceeds / v_shares;
  update public.profiles set cash = cash - v_cost where id = v_uid;
  if v_shares = p_qty then
    delete from public.shorts where user_id = v_uid and symbol = p_symbol;
  else
    update public.shorts set shares = shares - p_qty, proceeds = proceeds - v_avg * p_qty
      where user_id = v_uid and symbol = p_symbol;
  end if;
  update public.stocks
    set price = round((price * (1 + least(0.04, v_cost / 2000000.0)))::numeric, 2)
    where symbol = p_symbol;
end; $$;

-- ---------- LIMIT / STOP ORDERS ----------
create or replace function public.place_order(p_symbol text, p_side text, p_kind text, p_qty int, p_trigger numeric)
returns bigint language plpgsql security definer set search_path = public as $$
declare v_uid uuid := auth.uid(); v_id bigint;
begin
  if v_uid is null then raise exception 'Not signed in'; end if;
  if p_side not in ('buy','sell') then raise exception 'Side must be buy or sell'; end if;
  if p_kind not in ('limit','stop') then raise exception 'Kind must be limit or stop'; end if;
  if p_qty is null or p_qty <= 0 then raise exception 'Quantity must be a positive whole number'; end if;
  if p_trigger is null or p_trigger <= 0 then raise exception 'Trigger price must be positive'; end if;
  if not exists (select 1 from public.stocks where symbol = p_symbol) then
    raise exception 'Unknown symbol %', p_symbol; end if;
  insert into public.orders (user_id, symbol, side, kind, qty, trigger_price)
  values (v_uid, p_symbol, p_side, p_kind, p_qty, p_trigger) returning id into v_id;
  return v_id;
end; $$;

create or replace function public.cancel_order(p_id bigint)
returns void language plpgsql security definer set search_path = public as $$
declare v_uid uuid := auth.uid();
begin
  if v_uid is null then raise exception 'Not signed in'; end if;
  delete from public.orders where id = p_id and user_id = v_uid;
end; $$;

-- ---------- ACHIEVEMENTS (cloud synced) ----------
create or replace function public.unlock_achievement(p_id text)
returns void language plpgsql security definer set search_path = public as $$
declare v_uid uuid := auth.uid();
begin
  if v_uid is null then raise exception 'Not signed in'; end if;
  insert into public.user_achievements (user_id, ach_id)
  values (v_uid, p_id) on conflict do nothing;
end; $$;

-- ---------- DAILY LOGIN BONUS ----------
create or replace function public.claim_daily_bonus()
returns json language plpgsql security definer set search_path = public as $$
declare v_uid uuid := auth.uid(); v_last date; v_streak int; v_bonus numeric;
begin
  if v_uid is null then raise exception 'Not signed in'; end if;
  select last_bonus, streak into v_last, v_streak from public.profiles where id = v_uid for update;
  if v_last = current_date then
    return json_build_object('claimed', false, 'streak', v_streak, 'bonus', 0);
  end if;
  if v_last = current_date - 1 then v_streak := coalesce(v_streak,0) + 1; else v_streak := 1; end if;
  v_bonus := 100 * least(v_streak, 7);   -- grows with the streak, caps at 7 days
  update public.profiles set cash = cash + v_bonus, streak = v_streak, last_bonus = current_date
    where id = v_uid;
  return json_build_object('claimed', true, 'streak', v_streak, 'bonus', v_bonus);
end; $$;

-- ---------- VENTURE ACQUISITION OFFERS ----------
create or replace function public.accept_venture_offer(p_id bigint)
returns numeric language plpgsql security definer set search_path = public as $$
declare v_uid uuid := auth.uid(); v_offer numeric; v_exp timestamptz;
begin
  if v_uid is null then raise exception 'Not signed in'; end if;
  select offer_value, offer_expires into v_offer, v_exp
    from public.ventures where id = p_id and user_id = v_uid for update;
  if v_offer is null then raise exception 'No active offer'; end if;
  if v_exp is null or v_exp < now() then raise exception 'That offer has expired'; end if;
  update public.profiles set cash = cash + v_offer where id = v_uid;
  delete from public.ventures where id = p_id and user_id = v_uid;
  return v_offer;
end; $$;

create or replace function public.buy_home(p_tier int)
returns void language plpgsql security definer set search_path = public as $$
declare v_uid uuid := auth.uid(); v_cur int; v_cur_price numeric; v_new_price numeric;
        v_cost numeric; v_cash numeric;
begin
  if v_uid is null then raise exception 'Not signed in'; end if;
  select home_tier, cash into v_cur, v_cash from public.profiles where id = v_uid for update;
  if p_tier <= v_cur then raise exception 'You already own that property (or better)'; end if;
  select price into v_new_price from public.home_tiers where tier = p_tier;
  if v_new_price is null then raise exception 'Unknown property'; end if;
  select price into v_cur_price from public.home_tiers where tier = v_cur;
  v_cost := v_new_price - coalesce(v_cur_price, 0);
  if v_cash < v_cost then raise exception 'Insufficient funds'; end if;
  update public.profiles set cash = cash - v_cost, home_tier = p_tier where id = v_uid;
end; $$;

-- Invest in a startup (high risk) or a business (stable). Rolls the dice server-side.
create or replace function public.invest_venture(p_kind text, p_amount numeric)
returns json language plpgsql security definer set search_path = public as $$
declare v_uid uuid := auth.uid(); v_cash numeric; v_success boolean; v_mult numeric;
        v_value numeric := 0; v_income numeric := 0; v_name text;
        v_adj text[] := array['Quantum','Hyper','Neuro','Pixel','Nano','Turbo','Vertex','Lunar','Echo','Cyber','Apex','Solar'];
        v_noun text[] := array['AI','Labs','Dynamics','Systems','Works','Cloud','Tech','Genomics','Robotics','Networks','Logic','Forge'];
        v_biz text[] := array['Main Street Diner','Corner Laundromat','City Parking Garage','Sunny Car Wash','Family Bakery','Downtown Gym','Pizza Palace','Auto Repair Shop','Coffee Kiosk','Hardware Store','Flower Shop','Bowling Alley'];
begin
  if v_uid is null then raise exception 'Not signed in'; end if;
  if p_kind not in ('startup','business') then raise exception 'Unknown venture type'; end if;
  if p_amount is null or p_amount < 1 then raise exception 'Enter an amount of at least $1'; end if;
  select cash into v_cash from public.profiles where id = v_uid for update;
  if v_cash < p_amount then raise exception 'Insufficient funds'; end if;
  update public.profiles set cash = cash - p_amount where id = v_uid;

  if p_kind = 'startup' then
    v_success := random() >= 0.60;                       -- 60% fail
    if v_success then
      if random() < 0.15 then v_mult := 3 + random()*7;  -- moonshot: up to 10x
      else v_mult := 1 + random()*2; end if;             -- modest: 1-3x
      v_value  := round((p_amount * v_mult)::numeric, 2);
      v_income := round((v_value * 0.005)::numeric, 2);   -- high income (~0.5%/tick)
      v_name   := v_adj[1+floor(random()*array_length(v_adj,1))::int] || ' ' ||
                  v_noun[1+floor(random()*array_length(v_noun,1))::int];
    end if;
  else
    v_success := random() >= 0.30;                        -- 30% fail
    if v_success then
      v_value  := round((p_amount * (0.9 + random()*0.3))::numeric, 2);  -- ~1x, stable
      v_income := round((p_amount * 0.003)::numeric, 2);  -- steady income (~0.3%/tick)
      v_name   := v_biz[1+floor(random()*array_length(v_biz,1))::int];
    end if;
  end if;

  if v_success then
    insert into public.ventures (user_id, kind, name, invested, value, income_per_tick)
    values (v_uid, p_kind, v_name, p_amount, v_value, v_income);
  end if;

  return json_build_object('success', v_success, 'kind', p_kind, 'invested', p_amount,
                           'name', v_name, 'value', v_value, 'income', v_income);
end; $$;

-- Cash out a venture for its current value.
create or replace function public.sell_venture(p_id bigint)
returns void language plpgsql security definer set search_path = public as $$
declare v_uid uuid := auth.uid(); v_value numeric;
begin
  if v_uid is null then raise exception 'Not signed in'; end if;
  select value into v_value from public.ventures where id = p_id and user_id = v_uid for update;
  if v_value is null then raise exception 'Venture not found'; end if;
  update public.profiles set cash = cash + v_value where id = v_uid;
  delete from public.ventures where id = p_id and user_id = v_uid;
end; $$;

-- Return shape changed (added `streak`), so the old version must be dropped first.
drop function if exists public.get_leaderboard();
create or replace function public.get_leaderboard()
returns table(display_name text, net_worth numeric, home_tier int, is_me boolean, streak int)
language sql security definer set search_path = public as $$
  select p.display_name,
    public.user_net_worth(p.id) as net_worth,
    p.home_tier,
    (p.id = auth.uid()) as is_me,
    p.streak
  from public.profiles p
  order by net_worth desc;
$$;

-- ============================================================================
--  THE MARKET TICK  (moves prices, pays passive income, records net-worth)
-- ============================================================================
create or replace function public.tick_market()
returns void language plpgsql security definer set search_path = public as $$
declare r record; v_shock numeric; v_drift numeric := 0.0008; v_evt numeric; v_kind text; v_title text;
        o record; v_px numeric; v_fill boolean;
begin
  for r in select * from public.stocks loop
    v_shock := r.vol * (random() - random()) * 1.6;
    if random() < 0.08 then
      v_shock := v_shock + (case when random() < 0.5 then 1 else -1 end) * (0.04 + random() * 0.10);
    end if;
    update public.stocks
      set prev_price = price,
          price = greatest(0.05, round((price * (1 + v_drift + v_shock))::numeric, 2))
      where symbol = r.symbol;
  end loop;

  -- ~6% chance of a dramatic market-wide event
  if random() < 0.06 then
    v_evt := random();
    if v_evt < 0.30 then
      v_kind := 'crash';
      update public.stocks set price = greatest(0.05, round((price * (0.88 - random()*0.06))::numeric,2));
      v_title := '📉 MARKET CRASH! Everything is tanking — buy the dip?';
    elsif v_evt < 0.60 then
      v_kind := 'boom';
      update public.stocks set price = round((price * (1.06 + random()*0.09))::numeric,2);
      v_title := '📈 BULL RUN! The whole market is pumping.';
    elsif v_evt < 0.82 then
      v_kind := 'hype';
      update public.stocks set price = round((price * (1.10 + random()*0.20))::numeric,2) where goofy = true;
      v_title := '🧠 BRAINROT HYPE WAVE! Meme stocks going parabolic.';
    else
      v_kind := 'rally';
      update public.stocks set price = round((price * (1.05 + random()*0.10))::numeric,2) where goofy = false;
      v_title := '💼 TECH RALLY! Blue chips surge.';
    end if;
    insert into public.market_events (kind, title) values (v_kind, v_title);
  end if;

  insert into public.price_history (symbol, price) select symbol, price from public.stocks;

  -- fill any pending limit / stop orders whose trigger the new prices crossed
  for o in select * from public.orders loop
    select price into v_px from public.stocks where symbol = o.symbol;
    if v_px is null then delete from public.orders where id = o.id; continue; end if;
    v_fill := (o.side='buy'  and o.kind='limit' and v_px <= o.trigger_price)
           or (o.side='sell' and o.kind='limit' and v_px >= o.trigger_price)
           or (o.side='buy'  and o.kind='stop'  and v_px >= o.trigger_price)
           or (o.side='sell' and o.kind='stop'  and v_px <= o.trigger_price);
    if v_fill then
      begin
        if o.side='buy' then perform public._exec_buy(o.user_id, o.symbol, o.qty);
        else perform public._exec_sell(o.user_id, o.symbol, o.qty); end if;
      exception when others then null;   -- couldn't fill (funds/shares) → just cancel it
      end;
      delete from public.orders where id = o.id;
    end if;
  end loop;

  update public.profiles p
    set cash = cash + ht.income_per_tick
    from public.home_tiers ht
    where ht.tier = p.home_tier and ht.income_per_tick > 0;

  -- dividends: blue-chip holders earn a small payout each tick
  update public.profiles p
    set cash = cash + d.total
    from (select h.user_id, sum(h.shares * s.price * s.div_yield) total
          from public.holdings h join public.stocks s on s.symbol = h.symbol
          where s.div_yield > 0 group by h.user_id) d
    where d.user_id = p.id;

  -- venture passive income
  update public.profiles p
    set cash = cash + v.total
    from (select user_id, sum(income_per_tick) total from public.ventures group by user_id) v
    where v.user_id = p.id;

  -- startups stay volatile: their value swings, income tracks the new value
  update public.ventures
    set value = greatest(0, round((value * (1 + (random()-random())*0.12))::numeric, 2))
    where kind = 'startup';
  update public.ventures
    set income_per_tick = round((value * 0.005)::numeric, 2)
    where kind = 'startup';

  -- businesses are stable but not frozen: tiny drift, income tracks value
  update public.ventures
    set value = greatest(0, round((value * (1 + (random()-0.5)*0.02))::numeric, 2))
    where kind = 'business';
  update public.ventures
    set income_per_tick = round((value * 0.003)::numeric, 2)
    where kind = 'business';

  -- acquisition offers: expire stale ones, then occasionally float a new buyout
  update public.ventures set offer_value = null, offer_expires = null
    where offer_expires is not null and offer_expires < now();
  update public.ventures
    set offer_value = round((value * (1.3 + random()*0.7))::numeric, 2),
        offer_expires = now() + interval '10 minutes'
    where offer_value is null and value > 0 and random() < 0.04;

  -- record each player's net worth for the 12-hour summary
  insert into public.networth_snapshots (user_id, net_worth)
  select p.id, public.user_net_worth(p.id) from public.profiles p;

  delete from public.price_history where ts < now() - interval '2 days';
  delete from public.networth_snapshots where ts < now() - interval '3 days';
  delete from public.market_events where id not in (select id from public.market_events order by ts desc limit 30);
end; $$;

-- ============================================================================
--  ROW LEVEL SECURITY
-- ============================================================================
alter table public.profiles            enable row level security;
alter table public.holdings            enable row level security;
alter table public.stocks              enable row level security;
alter table public.price_history       enable row level security;
alter table public.home_tiers          enable row level security;
alter table public.networth_snapshots  enable row level security;
alter table public.market_events       enable row level security;
alter table public.ventures            enable row level security;
alter table public.shorts              enable row level security;
alter table public.orders              enable row level security;
alter table public.user_achievements   enable row level security;

drop policy if exists profiles_select_own on public.profiles;
create policy profiles_select_own on public.profiles for select to authenticated using (id = auth.uid());

drop policy if exists holdings_select_own on public.holdings;
create policy holdings_select_own on public.holdings for select to authenticated using (user_id = auth.uid());

drop policy if exists nws_select_own on public.networth_snapshots;
create policy nws_select_own on public.networth_snapshots for select to authenticated using (user_id = auth.uid());

drop policy if exists stocks_read on public.stocks;
create policy stocks_read on public.stocks for select to authenticated using (true);

drop policy if exists history_read on public.price_history;
create policy history_read on public.price_history for select to authenticated using (true);

drop policy if exists hometiers_read on public.home_tiers;
create policy hometiers_read on public.home_tiers for select to authenticated using (true);

drop policy if exists events_read on public.market_events;
create policy events_read on public.market_events for select to authenticated using (true);

drop policy if exists ventures_select_own on public.ventures;
create policy ventures_select_own on public.ventures for select to authenticated using (user_id = auth.uid());

drop policy if exists shorts_select_own on public.shorts;
create policy shorts_select_own on public.shorts for select to authenticated using (user_id = auth.uid());

drop policy if exists orders_select_own on public.orders;
create policy orders_select_own on public.orders for select to authenticated using (user_id = auth.uid());

drop policy if exists ach_select_own on public.user_achievements;
create policy ach_select_own on public.user_achievements for select to authenticated using (user_id = auth.uid());

grant select on public.profiles, public.holdings, public.stocks,
                 public.price_history, public.home_tiers, public.networth_snapshots,
                 public.market_events, public.ventures,
                 public.shorts, public.orders, public.user_achievements
  to authenticated;
grant execute on function public.buy_stock(text,int)            to authenticated;
grant execute on function public.sell_stock(text,int)           to authenticated;
grant execute on function public.buy_home(int)                  to authenticated;
grant execute on function public.get_leaderboard()              to authenticated;
grant execute on function public.invest_venture(text,numeric)   to authenticated;
grant execute on function public.sell_venture(bigint)           to authenticated;
grant execute on function public.short_stock(text,int)          to authenticated;
grant execute on function public.cover_short(text,int)          to authenticated;
grant execute on function public.place_order(text,text,text,int,numeric) to authenticated;
grant execute on function public.cancel_order(bigint)           to authenticated;
grant execute on function public.unlock_achievement(text)       to authenticated;
grant execute on function public.claim_daily_bonus()            to authenticated;
grant execute on function public.accept_venture_offer(bigint)   to authenticated;
grant execute on function public.user_net_worth(uuid)           to authenticated;

-- ============================================================================
--  REALTIME  (push live prices to every connected player)
-- ============================================================================
do $$ begin
  if not exists (select 1 from pg_publication_tables
                 where pubname='supabase_realtime' and schemaname='public' and tablename='stocks') then
    alter publication supabase_realtime add table public.stocks;
  end if;
  if not exists (select 1 from pg_publication_tables
                 where pubname='supabase_realtime' and schemaname='public' and tablename='market_events') then
    alter publication supabase_realtime add table public.market_events;
  end if;
end $$;

-- ============================================================================
--  SCHEDULE THE HEARTBEAT  (every 2 minutes)
-- ============================================================================
select cron.unschedule('stonk-market-tick')
  where exists (select 1 from cron.job where jobname = 'stonk-market-tick');
select cron.schedule('stonk-market-tick', '*/2 * * * *', $$ select public.tick_market(); $$);

-- Seed one history point + one snapshot so charts/summary aren't empty.
insert into public.price_history (symbol, price) select symbol, price from public.stocks;
insert into public.networth_snapshots (user_id, net_worth)
select p.id, public.user_net_worth(p.id) from public.profiles p;
