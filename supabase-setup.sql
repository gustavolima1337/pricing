-- ════════════════════════════════════════════════
-- Precificador de Marketplaces — Supabase Setup
-- Execute este script no SQL Editor do Supabase
-- ════════════════════════════════════════════════

-- 1. Empresas
create table public.companies (
  id          uuid primary key default gen_random_uuid(),
  name        text not null,
  created_at  timestamptz default now()
);

-- 2. Perfis de usuários (estende auth.users)
create table public.profiles (
  id          uuid primary key references auth.users(id) on delete cascade,
  company_id  uuid not null references public.companies(id),
  full_name   text,
  role        text not null default 'user' check (role in ('admin','user')),
  created_at  timestamptz default now()
);

-- 3. Uploads de XML
create table public.xml_uploads (
  id              uuid primary key default gen_random_uuid(),
  company_id      uuid not null references public.companies(id),
  uploaded_by     uuid references public.profiles(id),
  filename        text,
  nf_number       text,
  supplier_name   text,
  supplier_cnpj   text,
  emission_date   date,
  total_value     numeric(12,2),
  created_at      timestamptz default now()
);

-- 4. Produtos dos XMLs
create table public.products (
  id              uuid primary key default gen_random_uuid(),
  company_id      uuid not null references public.companies(id),
  xml_upload_id   uuid not null references public.xml_uploads(id) on delete cascade,
  product_code    text not null,
  product_name    text not null,
  ean             text,
  ncm             text,
  unit            text,
  quantity        numeric(12,3),
  unit_price      numeric(12,4) not null,
  total_price     numeric(12,2),
  lot_number      text,
  created_at      timestamptz default now()
);

-- ── Row Level Security ─────────────────────────

alter table public.companies   enable row level security;
alter table public.profiles    enable row level security;
alter table public.xml_uploads enable row level security;
alter table public.products    enable row level security;

-- Função auxiliar: retorna company_id do usuário logado
create or replace function public.my_company_id()
returns uuid language sql security definer stable as $$
  select company_id from public.profiles where id = auth.uid()
$$;

-- profiles: cada usuário acessa apenas o próprio perfil
create policy "profile_select" on public.profiles
  for select using (auth.uid() = id);

create policy "profile_update" on public.profiles
  for update using (auth.uid() = id);

-- companies: usuário acessa apenas sua empresa
create policy "company_select" on public.companies
  for select using (id = my_company_id());

-- xml_uploads: escopo por empresa
create policy "upload_select" on public.xml_uploads
  for select using (company_id = my_company_id());

create policy "upload_insert" on public.xml_uploads
  for insert with check (company_id = my_company_id());

-- products: escopo por empresa
create policy "product_select" on public.products
  for select using (company_id = my_company_id());

create policy "product_insert" on public.products
  for insert with check (company_id = my_company_id());

-- ── Como cadastrar empresa e usuário ──────────
--
-- Passo 1: Crie o usuário em Authentication > Users no painel Supabase
--
-- Passo 2: Crie a empresa
-- insert into public.companies (name) values ('Nome da Empresa');
--
-- Passo 3: Vincule o usuário à empresa
-- insert into public.profiles (id, company_id, full_name, role)
-- values (
--   '<UUID do usuário em auth.users>',
--   '<UUID da empresa criada acima>',
--   'Nome do Usuário',
--   'admin'   -- ou 'user'
-- );
