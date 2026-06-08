-- 팀 테이블
create table public.teams (
  id          uuid primary key default gen_random_uuid(),
  user_id     uuid references auth.users not null,
  name        text not null,
  created_at  timestamptz default now()
);

-- 선수 테이블 (stats를 JSONB로 단순화)
create table public.players (
  id          uuid primary key default gen_random_uuid(),
  team_id     uuid references public.teams on delete cascade not null,
  name        text not null,
  position    text not null,
  nationality text not null,
  rating      numeric(4,1) not null,
  tier        text not null,
  age         integer not null default 25,
  stats       jsonb not null default '{}'
);

-- 경기 기록
create table public.matches (
  id               uuid primary key default gen_random_uuid(),
  team_id          uuid references public.teams on delete cascade not null,
  away_team_name   text not null,
  home_score       integer not null,
  away_score       integer not null,
  home_possession  numeric(4,1),
  played_at        timestamptz default now()
);

-- 경기 이벤트
create table public.match_events (
  id          uuid primary key default gen_random_uuid(),
  match_id    uuid references public.matches on delete cascade not null,
  minute      integer not null,
  event_type  text not null,
  description text not null
);

-- 스쿼드 슬롯 (팀당 1개)
create table public.squad_slots (
  id        uuid primary key default gen_random_uuid(),
  team_id   uuid references public.teams on delete cascade not null unique,
  formation text not null default '4-3-3',
  slots     jsonb not null default '[]'
);

-- RLS 활성화
alter table public.teams        enable row level security;
alter table public.players      enable row level security;
alter table public.matches      enable row level security;
alter table public.match_events enable row level security;
alter table public.squad_slots  enable row level security;

-- RLS 정책: 본인 데이터만 접근
create policy "teams_own" on public.teams
  for all using (auth.uid() = user_id);

create policy "players_own" on public.players
  for all using (
    team_id in (select id from public.teams where user_id = auth.uid())
  );

create policy "matches_own" on public.matches
  for all using (
    team_id in (select id from public.teams where user_id = auth.uid())
  );

create policy "match_events_own" on public.match_events
  for all using (
    match_id in (
      select id from public.matches
      where team_id in (select id from public.teams where user_id = auth.uid())
    )
  );

create policy "squad_slots_own" on public.squad_slots
  for all using (
    team_id in (select id from public.teams where user_id = auth.uid())
  );
