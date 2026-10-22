begin;
create table if not exists public.career_records (
  user_id uuid not null references auth.users(id) on delete cascade,
  kind text not null check (kind in ('profile','jobs','projects','attempts','tasks','conversations','files')),
  id text not null check (length(id) between 1 and 120),
  payload jsonb not null check (jsonb_typeof(payload) = 'object'),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  primary key (user_id, kind, id)
);
create index if not exists career_records_owner_kind on public.career_records(user_id,kind);
alter table public.career_records enable row level security;
grant select,insert,update,delete on public.career_records to authenticated;
revoke all on public.career_records from anon;
create policy records_select on public.career_records for select to authenticated using ((select auth.uid()) = user_id);
create policy records_insert on public.career_records for insert to authenticated with check ((select auth.uid()) = user_id);
create policy records_update on public.career_records for update to authenticated using ((select auth.uid()) = user_id) with check ((select auth.uid()) = user_id);
create policy records_delete on public.career_records for delete to authenticated using ((select auth.uid()) = user_id);
create or replace function public.upsert_career_record(record_kind text, record_id text, record_patch jsonb)
returns void language sql security invoker set search_path = '' as $$
 insert into public.career_records(user_id,kind,id,payload)
 values ((select auth.uid()),record_kind,record_id,record_patch)
 on conflict (user_id,kind,id) do update set payload=public.career_records.payload || excluded.payload,updated_at=now();
$$;
revoke all on function public.upsert_career_record(text,text,jsonb) from public,anon;
grant execute on function public.upsert_career_record(text,text,jsonb) to authenticated;
create table if not exists public.integration_secrets (
 user_id uuid not null references auth.users(id) on delete cascade,
 provider text not null check (provider in ('anthropic','groq','tavily')),
 ciphertext text not null,
 model text,
 updated_at timestamptz not null default now(),
 primary key(user_id,provider)
);
alter table public.integration_secrets enable row level security;
revoke all on public.integration_secrets from anon,authenticated;
grant all on public.integration_secrets to service_role;
insert into storage.buckets(id,name,public,file_size_limit) values ('career-evidence','career-evidence',false,20000000) on conflict(id) do nothing;
create policy evidence_select on storage.objects for select to authenticated using (bucket_id='career-evidence' and (storage.foldername(name))[1]=(select auth.uid())::text);
create policy evidence_insert on storage.objects for insert to authenticated with check (bucket_id='career-evidence' and (storage.foldername(name))[1]=(select auth.uid())::text);
create policy evidence_delete on storage.objects for delete to authenticated using (bucket_id='career-evidence' and (storage.foldername(name))[1]=(select auth.uid())::text);
create table if not exists public.ai_usage (
 user_id uuid primary key references auth.users(id) on delete cascade,
 requests bigint not null default 0,
 input_tokens bigint not null default 0,
 output_tokens bigint not null default 0
);
alter table public.ai_usage enable row level security;
revoke all on public.ai_usage from anon,authenticated;
grant all on public.ai_usage to service_role;
create or replace function public.record_ai_usage(p_user_id uuid,p_input bigint,p_output bigint)
returns void language sql security invoker set search_path='' as $$
 insert into public.ai_usage(user_id,requests,input_tokens,output_tokens) values(p_user_id,1,greatest(p_input,0),greatest(p_output,0))
 on conflict(user_id) do update set requests=public.ai_usage.requests+1,input_tokens=public.ai_usage.input_tokens+excluded.input_tokens,output_tokens=public.ai_usage.output_tokens+excluded.output_tokens;
$$;
revoke all on function public.record_ai_usage(uuid,bigint,bigint) from public,anon,authenticated;
grant execute on function public.record_ai_usage(uuid,bigint,bigint) to service_role;
commit;
