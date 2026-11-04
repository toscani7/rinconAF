-- =====================================================================
-- rinconAF · esquema de Supabase
-- Pegá todo este archivo en Supabase → SQL Editor → "Run".
-- Crea: perfiles, amistades, solicitudes, posteos, likes, comentarios,
-- firmas, likes a perfiles, notificaciones, el bucket "media" y la seguridad (RLS).
-- =====================================================================

-- ---------- Perfiles ----------
create sequence if not exists public.npc_seq;

create table if not exists public.profiles (
  id       uuid primary key references auth.users on delete cascade,
  numero   int  unique not null,                    -- npc1, npc2, npc3...
  apodo    text not null,
  datos    jsonb not null default '{}'::jsonb,       -- personalización, bio, fotos del día, etc.
  visitas  int  not null default 0,
  creado   timestamptz not null default now()
);

-- Al registrarse, se crea el perfil con apodo "npc" + número de registro
create or replace function public.nuevo_perfil() returns trigger
language plpgsql security definer set search_path = public as $$
declare n int := nextval('public.npc_seq');
begin
  insert into public.profiles (id, numero, apodo) values (new.id, n, 'npc' || n);
  return new;
end $$;

drop trigger if exists al_registrarse on auth.users;
create trigger al_registrarse after insert on auth.users
  for each row execute function public.nuevo_perfil();

-- ---------- Amistades y solicitudes ----------
create table if not exists public.solicitudes (
  de     uuid not null references public.profiles on delete cascade default auth.uid(),
  para   uuid not null references public.profiles on delete cascade,
  creado timestamptz not null default now(),
  primary key (de, para),
  check (de <> para)
);

create table if not exists public.amistades (
  a      uuid not null references public.profiles on delete cascade,
  b      uuid not null references public.profiles on delete cascade,
  creado timestamptz not null default now(),
  primary key (a, b),
  check (a < b)                                     -- cada amistad se guarda una sola vez
);

create or replace function public.son_amigos(x uuid, y uuid) returns boolean
language sql stable security definer set search_path = public as $$
  select exists (select 1 from public.amistades where a = least(x, y) and b = greatest(x, y));
$$;

-- ---------- Posteos del inicio ----------
create table if not exists public.posteos (
  id         bigint generated always as identity primary key,
  autor      uuid not null references public.profiles on delete cascade default auth.uid(),
  tipo       text not null check (tipo in ('texto', 'imagen', 'video')),
  texto      text,
  media_path text,                                  -- archivo en el bucket "media"
  video_url  text,                                  -- o link de YouTube, TikTok, etc.
  creado     timestamptz not null default now()
);

create table if not exists public.likes (
  posteo  bigint not null references public.posteos on delete cascade,
  usuario uuid   not null references public.profiles on delete cascade default auth.uid(),
  primary key (posteo, usuario)
);

create table if not exists public.comentarios (
  id     bigint generated always as identity primary key,
  posteo bigint not null references public.posteos on delete cascade,
  autor  uuid   not null references public.profiles on delete cascade default auth.uid(),
  texto  text   not null check (char_length(texto) <= 300),
  creado timestamptz not null default now()
);

-- ---------- Perfil: firmas del libro de visitas y likes al perfil ----------
create table if not exists public.firmas (
  id     bigint generated always as identity primary key,
  perfil uuid   not null references public.profiles on delete cascade,
  foto   bigint not null,                           -- momento (ms) en que se subió la foto firmada
  autor  uuid   not null references public.profiles on delete cascade default auth.uid(),
  texto  text   not null check (char_length(texto) <= 300),
  creado timestamptz not null default now()
);

create table if not exists public.likes_perfil (
  perfil  uuid not null references public.profiles on delete cascade,
  usuario uuid not null references public.profiles on delete cascade default auth.uid(),
  primary key (perfil, usuario),
  check (perfil <> usuario)
);

-- ---------- Notificaciones ----------
create table if not exists public.notificaciones (
  id     bigint generated always as identity primary key,
  para   uuid not null references public.profiles on delete cascade,
  de     uuid not null references public.profiles on delete cascade default auth.uid(),
  tipo   text not null,                             -- aceptada, like, comentario, like-perfil, grupo, admin
  datos  jsonb not null default '{}'::jsonb,
  leida  boolean not null default false,
  creado timestamptz not null default now()
);

-- ---------- Funciones que tocan datos de otra persona ----------
create or replace function public.aceptar_solicitud(de_id uuid) returns void
language plpgsql security definer set search_path = public as $$
begin
  delete from public.solicitudes where de = de_id and para = auth.uid();
  if not found then raise exception 'no hay solicitud'; end if;
  insert into public.amistades (a, b) values (least(de_id, auth.uid()), greatest(de_id, auth.uid()))
    on conflict do nothing;
  insert into public.notificaciones (para, de, tipo) values (de_id, auth.uid(), 'aceptada');
end $$;

create or replace function public.sumar_visita(p uuid) returns void
language sql security definer set search_path = public as $$
  update public.profiles set visitas = visitas + 1 where id = p and p <> auth.uid();
$$;

-- ---------- Seguridad: solo usuarios registrados, cada uno con lo suyo ----------
alter table public.profiles       enable row level security;
alter table public.solicitudes    enable row level security;
alter table public.amistades      enable row level security;
alter table public.posteos        enable row level security;
alter table public.likes          enable row level security;
alter table public.comentarios    enable row level security;
alter table public.firmas         enable row level security;
alter table public.likes_perfil   enable row level security;
alter table public.notificaciones enable row level security;

-- Perfiles: los ven todos los registrados; cada uno edita el suyo
create policy "perfiles visibles" on public.profiles for select to authenticated using (true);
create policy "editar mi perfil"  on public.profiles for update to authenticated using (id = auth.uid()) with check (id = auth.uid());

-- Solicitudes: las ven quien manda y quien recibe
create policy "ver mis solicitudes"   on public.solicitudes for select to authenticated using (auth.uid() in (de, para));
create policy "mandar solicitud"      on public.solicitudes for insert to authenticated with check (de = auth.uid());
create policy "cancelar o rechazar"   on public.solicitudes for delete to authenticated using (auth.uid() in (de, para));

-- Amistades: visibles para los F/F; se crean solo con aceptar_solicitud
create policy "ver amistades"         on public.amistades for select to authenticated using (true);
create policy "eliminar amistad"      on public.amistades for delete to authenticated using (auth.uid() in (a, b));

-- Posteos: los ves si son tuyos o de un amigo
create policy "ver posteos de amigos" on public.posteos for select to authenticated
  using (autor = auth.uid() or public.son_amigos(autor, auth.uid()));
create policy "postear"               on public.posteos for insert to authenticated with check (autor = auth.uid());
create policy "borrar mi posteo"      on public.posteos for delete to authenticated using (autor = auth.uid());

-- Likes y comentarios: solo en posteos que podés ver
create policy "ver likes"     on public.likes for select to authenticated using (exists (select 1 from public.posteos p where p.id = posteo));
create policy "dar like"      on public.likes for insert to authenticated with check (usuario = auth.uid() and exists (select 1 from public.posteos p where p.id = posteo));
create policy "sacar like"    on public.likes for delete to authenticated using (usuario = auth.uid());
create policy "ver comentarios" on public.comentarios for select to authenticated using (exists (select 1 from public.posteos p where p.id = posteo));
create policy "comentar"        on public.comentarios for insert to authenticated with check (autor = auth.uid() and exists (select 1 from public.posteos p where p.id = posteo));
create policy "borrar mi comentario" on public.comentarios for delete to authenticated using (autor = auth.uid());

-- Firmas y likes a perfiles
create policy "ver firmas"     on public.firmas for select to authenticated using (true);
create policy "firmar"         on public.firmas for insert to authenticated with check (autor = auth.uid());
create policy "borrar firma"   on public.firmas for delete to authenticated using (auth.uid() in (autor, perfil));
create policy "ver likes perfil"   on public.likes_perfil for select to authenticated using (true);
create policy "like a un perfil"   on public.likes_perfil for insert to authenticated with check (usuario = auth.uid());
create policy "sacar like perfil"  on public.likes_perfil for delete to authenticated using (usuario = auth.uid());

-- Notificaciones: ves las tuyas; cualquiera puede avisarte algo firmando con su nombre
create policy "ver mis notificaciones" on public.notificaciones for select to authenticated using (para = auth.uid());
create policy "avisar"                 on public.notificaciones for insert to authenticated with check (de = auth.uid() and para <> auth.uid());
create policy "marcar leidas"          on public.notificaciones for update to authenticated using (para = auth.uid());

-- ---------- Archivos: bucket "media" ----------
-- Fotos (ya achicadas en el celu) y videos de hasta 25 MB. Cada usuario sube solo a su carpeta.
insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values ('media', 'media', true, 26214400, array['image/jpeg','image/png','image/webp','image/gif','video/mp4','video/webm','video/quicktime'])
on conflict (id) do nothing;

create policy "subir a mi carpeta" on storage.objects for insert to authenticated
  with check (bucket_id = 'media' and (storage.foldername(name))[1] = auth.uid()::text);
create policy "borrar mis archivos" on storage.objects for delete to authenticated
  using (bucket_id = 'media' and (storage.foldername(name))[1] = auth.uid()::text);
