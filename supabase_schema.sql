-- ============================================================
-- lending1system — Supabase Database Schema
-- Run this in Supabase → SQL Editor → New Query
-- ============================================================

-- Enable UUID extension
create extension if not exists "uuid-ossp";

-- ── users ────────────────────────────────────────────────────────────────────
create table if not exists public.users (
  id           uuid primary key references auth.users(id) on delete cascade,
  email        text unique not null,
  full_name    text,
  phone        text,
  role         text not null default 'rider'
                 check (role in ('admin','employee','rider','lender')),
  status       text not null default 'active'
                 check (status in ('active','inactive')),
  area         text,
  capital_amount numeric(14,2) default 0,
  avatar_url   text,
  created_at   timestamptz not null default now(),
  updated_at   timestamptz not null default now()
);

alter table public.users enable row level security;

create policy "Users can read own row"
  on public.users for select
  using (auth.uid() = id);

create policy "Admins and employees can read all users"
  on public.users for select
  using (
    exists (
      select 1 from public.users u
      where u.id = auth.uid()
        and u.role in ('admin','employee')
    )
  );

create policy "Admins and employees can insert users"
  on public.users for insert
  with check (
    exists (
      select 1 from public.users u
      where u.id = auth.uid()
        and u.role in ('admin','employee')
    )
  );

create policy "Admins and employees can update users"
  on public.users for update
  using (
    exists (
      select 1 from public.users u
      where u.id = auth.uid()
        and u.role in ('admin','employee')
    )
  );

create policy "Users can update own row"
  on public.users for update
  using (auth.uid() = id);

-- Trigger: auto-insert into users on sign-up
create or replace function public.handle_new_user()
returns trigger language plpgsql security definer as $$
begin
  insert into public.users (id, email, full_name, phone, role, status)
  values (
    new.id,
    new.email,
    new.raw_user_meta_data->>'full_name',
    new.raw_user_meta_data->>'phone',
    coalesce(new.raw_user_meta_data->>'role', 'lender'),
    'active'
  )
  on conflict (id) do nothing;
  return new;
end;
$$;

drop trigger if exists on_auth_user_created on auth.users;
create trigger on_auth_user_created
  after insert on auth.users
  for each row execute procedure public.handle_new_user();

-- ── loans ─────────────────────────────────────────────────────────────────────
create table if not exists public.loans (
  id                   uuid primary key default uuid_generate_v4(),
  loan_number          text unique not null,
  borrower_name        text not null,
  borrower_phone       text,
  borrower_address     text,
  borrower_age         int,
  borrower_gender      text default 'male' check (borrower_gender in ('male','female')),
  co_borrower_name     text,
  co_borrower_phone    text,
  co_borrower_relation text,
  amount               numeric(14,2) not null check (amount > 0),
  interest_rate        numeric(5,2) not null default 5.0,
  interest_amount      numeric(14,2) not null default 0,
  total_payable        numeric(14,2) not null default 0,
  term_days            int not null default 30,
  purpose              text,
  status               text not null default 'pending'
                         check (status in (
                           'pending','under_investigation','approved',
                           'active','overdue','paid','rejected'
                         )),
  lender_id            uuid references public.users(id),
  assigned_rider_id    uuid references public.users(id),
  approved_by          uuid references public.users(id),
  due_date             date,
  approved_at          timestamptz,
  rejected_at          timestamptz,
  rejection_reason     text,
  address              text,
  created_at           timestamptz not null default now(),
  updated_at           timestamptz not null default now()
);

alter table public.loans enable row level security;

create policy "Authenticated users can read loans"
  on public.loans for select
  using (auth.uid() is not null);

create policy "Lenders can insert loans"
  on public.loans for insert
  with check (auth.uid() = lender_id);

create policy "Admins and employees can update loans"
  on public.loans for update
  using (
    exists (
      select 1 from public.users u
      where u.id = auth.uid()
        and u.role in ('admin','employee')
    )
  );

create policy "Riders can update assigned loans"
  on public.loans for update
  using (auth.uid() = assigned_rider_id);

-- ── collections ───────────────────────────────────────────────────────────────
create table if not exists public.collections (
  id              uuid primary key default uuid_generate_v4(),
  loan_id         uuid not null references public.loans(id) on delete cascade,
  rider_id        uuid references public.users(id),
  amount          numeric(14,2) not null check (amount > 0),
  status          text not null default 'collected'
                    check (status in ('collected','partial','missed')),
  collection_date date not null default current_date,
  notes           text,
  created_at      timestamptz not null default now()
);

alter table public.collections enable row level security;

create policy "Authenticated users can read collections"
  on public.collections for select
  using (auth.uid() is not null);

create policy "Riders can insert collections"
  on public.collections for insert
  with check (auth.uid() = rider_id);

create policy "Admins and employees can insert any collection"
  on public.collections for insert
  with check (
    exists (
      select 1 from public.users u
      where u.id = auth.uid()
        and u.role in ('admin','employee')
    )
  );

-- ── credit_investigations ─────────────────────────────────────────────────────
create table if not exists public.credit_investigations (
  id           uuid primary key default uuid_generate_v4(),
  loan_id      uuid not null references public.loans(id) on delete cascade,
  rider_id     uuid references public.users(id),
  status       text not null default 'pending'
                 check (status in ('pending','ongoing','completed','failed')),
  findings     text,
  notes        text,
  created_at   timestamptz not null default now(),
  completed_at timestamptz
);

alter table public.credit_investigations enable row level security;

create policy "Authenticated users can read CI"
  on public.credit_investigations for select
  using (auth.uid() is not null);

create policy "Admins and employees can insert CI"
  on public.credit_investigations for insert
  with check (
    exists (
      select 1 from public.users u
      where u.id = auth.uid()
        and u.role in ('admin','employee')
    )
  );

create policy "Riders can update assigned CI"
  on public.credit_investigations for update
  using (auth.uid() = rider_id);

create policy "Admins and employees can update any CI"
  on public.credit_investigations for update
  using (
    exists (
      select 1 from public.users u
      where u.id = auth.uid()
        and u.role in ('admin','employee')
    )
  );

-- ── notifications ─────────────────────────────────────────────────────────────
create table if not exists public.notifications (
  id         uuid primary key default uuid_generate_v4(),
  user_id    uuid not null references public.users(id) on delete cascade,
  type       text not null default 'info',
  title      text not null,
  body       text,
  is_read    boolean not null default false,
  data       jsonb,
  created_at timestamptz not null default now()
);

alter table public.notifications enable row level security;

create policy "Users can read own notifications"
  on public.notifications for select
  using (auth.uid() = user_id);

create policy "Users can update own notifications"
  on public.notifications for update
  using (auth.uid() = user_id);

create policy "Users can delete own notifications"
  on public.notifications for delete
  using (auth.uid() = user_id);

create policy "Admins and system can insert notifications"
  on public.notifications for insert
  with check (true);

-- ── audit_logs ────────────────────────────────────────────────────────────────
create table if not exists public.audit_logs (
  id          uuid primary key default uuid_generate_v4(),
  user_id     uuid references public.users(id),
  action      text not null,
  description text,
  ip_address  text,
  created_at  timestamptz not null default now()
);

alter table public.audit_logs enable row level security;

create policy "Admins can read audit logs"
  on public.audit_logs for select
  using (
    exists (
      select 1 from public.users u
      where u.id = auth.uid()
        and u.role = 'admin'
    )
  );

create policy "Authenticated users can insert audit logs"
  on public.audit_logs for insert
  with check (auth.uid() is not null);

-- ── Indexes ───────────────────────────────────────────────────────────────────
create index if not exists idx_loans_status on public.loans(status);
create index if not exists idx_loans_lender_id on public.loans(lender_id);
create index if not exists idx_loans_rider_id on public.loans(assigned_rider_id);
create index if not exists idx_collections_loan_id on public.collections(loan_id);
create index if not exists idx_collections_rider_id on public.collections(rider_id);
create index if not exists idx_collections_date on public.collections(collection_date);
create index if not exists idx_ci_rider_id on public.credit_investigations(rider_id);
create index if not exists idx_ci_status on public.credit_investigations(status);
create index if not exists idx_notifications_user_id on public.notifications(user_id);
create index if not exists idx_audit_created_at on public.audit_logs(created_at desc);

-- ── Helper: auto-update updated_at ───────────────────────────────────────────
create or replace function public.set_updated_at()
returns trigger language plpgsql as $$
begin
  new.updated_at = now();
  return new;
end;
$$;

create trigger set_loans_updated_at
  before update on public.loans
  for each row execute procedure public.set_updated_at();

create trigger set_users_updated_at
  before update on public.users
  for each row execute procedure public.set_updated_at();

-- ── Seed: default admin user ──────────────────────────────────────────────────
-- After running this schema, create an admin via the Supabase dashboard:
-- Authentication → Users → Invite / Add User
-- Then run:
--   update public.users set role = 'admin' where email = 'your@admin.email';