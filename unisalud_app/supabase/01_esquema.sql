-- =====================================================================
--  UniSalud · Esquema de base de datos (Supabase / PostgreSQL)
--  Ejecutar COMPLETO en: Supabase → SQL Editor → New query → Run
--  Es idempotente en lo posible, pero está pensado para un proyecto nuevo.
-- =====================================================================

-- ---------------------------------------------------------------------
-- 0. Zona horaria de la universidad (cámbiala si no estás en Perú)
-- ---------------------------------------------------------------------
create or replace function public.ahora_local()
returns timestamp language sql stable as $$
  select (now() at time zone 'America/Lima')
$$;

create or replace function public.hoy_local()
returns date language sql stable as $$
  select public.ahora_local()::date
$$;

-- ---------------------------------------------------------------------
-- 1. Tipos
-- ---------------------------------------------------------------------
do $$ begin
  create type public.rol_usuario  as enum ('paciente', 'doctor', 'admin');
exception when duplicate_object then null; end $$;

do $$ begin
  create type public.estado_cita  as enum ('pendiente', 'confirmada', 'atendida', 'no_asistio', 'cancelada');
exception when duplicate_object then null; end $$;

do $$ begin
  create type public.tipo_usuario as enum ('estudiante', 'docente', 'administrativo', 'externo');
exception when duplicate_object then null; end $$;

-- ---------------------------------------------------------------------
-- 2. Tablas
-- ---------------------------------------------------------------------

-- Áreas de atención: medicina, enfermería, psicología, odontología...
create table if not exists public.especialidades (
  id          smallserial primary key,
  codigo      text not null unique,
  nombre      text not null,
  descripcion text,
  color       text not null default '#0E7C86',
  activo      boolean not null default true
);

-- Perfil de cada usuario (1 a 1 con auth.users)
create table if not exists public.perfiles (
  id                   uuid primary key references auth.users(id) on delete cascade,
  nombres              text not null default '',
  apellidos            text not null default '',
  email                text,
  dni                  text,
  codigo_universitario text,
  telefono             text,
  fecha_nacimiento     date,
  sexo                 text check (sexo in ('M', 'F', 'O')),
  tipo_usuario         public.tipo_usuario not null default 'estudiante',
  escuela              text,                       -- facultad / escuela profesional
  rol                  public.rol_usuario not null default 'paciente',
  especialidad_id      smallint references public.especialidades(id),  -- solo profesionales
  consultorio          text,                       -- p.ej. "Tópico 2 - Pabellón B"
  activo               boolean not null default true,
  created_at           timestamptz not null default now(),
  updated_at           timestamptz not null default now()
);

-- Horario semanal de atención de cada profesional
create table if not exists public.horarios_doctor (
  id               bigserial primary key,
  doctor_id        uuid not null references public.perfiles(id) on delete cascade,
  dia_semana       smallint not null check (dia_semana between 1 and 7),  -- 1 = lunes ... 7 = domingo
  hora_inicio      time not null,
  hora_fin         time not null,
  duracion_minutos smallint not null default 30 check (duracion_minutos between 10 and 120),
  activo           boolean not null default true,
  created_at       timestamptz not null default now(),
  check (hora_fin > hora_inicio)
);

-- Citas: el corazón de la app (y la fuente de todos los reportes)
create table if not exists public.citas (
  id                 bigserial primary key,
  paciente_id        uuid not null references public.perfiles(id),
  doctor_id          uuid not null references public.perfiles(id),
  especialidad_id    smallint not null references public.especialidades(id),
  fecha              date not null,
  hora_inicio        time not null,
  hora_fin           time not null,
  turno              text generated always as
                       (case when hora_inicio < time '13:00' then 'mañana' else 'tarde' end) stored,
  motivo             text,
  estado             public.estado_cita not null default 'pendiente',
  -- Asistencia y atención
  asistio            boolean,                      -- null = aún no se sabe
  hora_llegada       timestamptz,                  -- cuándo llegó el paciente
  atendida_en        timestamptz,                  -- día y hora exactos en que fue atendido
  diagnostico        text,
  indicaciones       text,
  observaciones      text,
  -- Derivación
  derivado_a         smallint references public.especialidades(id),  -- a otra área interna
  derivacion_externa text,                         -- p.ej. "Hospital Regional - Traumatología"
  motivo_derivacion  text,
  cita_origen_id     bigint references public.citas(id),  -- si esta cita nace de una derivación
  -- Cancelación
  motivo_cancelacion text,
  cancelada_por      uuid references public.perfiles(id),
  cancelada_en       timestamptz,
  created_at         timestamptz not null default now(),
  updated_at         timestamptz not null default now()
);

-- Un profesional no puede tener dos citas activas a la misma hora
create unique index if not exists citas_slot_doctor_unico
  on public.citas (doctor_id, fecha, hora_inicio) where estado <> 'cancelada';
-- Un paciente tampoco puede estar en dos sitios a la vez
create unique index if not exists citas_slot_paciente_unico
  on public.citas (paciente_id, fecha, hora_inicio) where estado <> 'cancelada';
create index if not exists citas_fecha_idx       on public.citas (fecha);
create index if not exists citas_paciente_idx    on public.citas (paciente_id);
create index if not exists citas_doctor_idx      on public.citas (doctor_id, fecha);

-- Avisos dentro de la app
create table if not exists public.notificaciones (
  id         bigserial primary key,
  usuario_id uuid not null references public.perfiles(id) on delete cascade,
  titulo     text not null,
  mensaje    text not null,
  cita_id    bigint references public.citas(id) on delete set null,
  leida      boolean not null default false,
  created_at timestamptz not null default now()
);
create index if not exists notificaciones_usuario_idx on public.notificaciones (usuario_id, created_at desc);

-- ---------------------------------------------------------------------
-- 3. Funciones auxiliares de seguridad
-- ---------------------------------------------------------------------
create or replace function public.rol_actual()
returns public.rol_usuario language sql stable security definer set search_path = public as $$
  select rol from public.perfiles where id = auth.uid()
$$;

create or replace function public.es_admin()
returns boolean language sql stable security definer set search_path = public as $$
  select coalesce(public.rol_actual() = 'admin', false)
$$;

-- updated_at automático
create or replace function public.tocar_updated_at()
returns trigger language plpgsql as $$
begin
  new.updated_at := now();
  return new;
end $$;

drop trigger if exists perfiles_updated_at on public.perfiles;
create trigger perfiles_updated_at before update on public.perfiles
  for each row execute function public.tocar_updated_at();

drop trigger if exists citas_updated_at on public.citas;
create trigger citas_updated_at before update on public.citas
  for each row execute function public.tocar_updated_at();

-- Crear el perfil automáticamente cuando alguien se registra
create or replace function public.crear_perfil_nuevo_usuario()
returns trigger language plpgsql security definer set search_path = public as $$
declare
  v_meta jsonb := coalesce(new.raw_user_meta_data, '{}'::jsonb);
  v_tipo text  := v_meta->>'tipo_usuario';
begin
  insert into public.perfiles (id, email, nombres, apellidos, dni, codigo_universitario, telefono, escuela, tipo_usuario)
  values (
    new.id,
    new.email,
    coalesce(v_meta->>'nombres', ''),
    coalesce(v_meta->>'apellidos', ''),
    nullif(v_meta->>'dni', ''),
    nullif(v_meta->>'codigo_universitario', ''),
    nullif(v_meta->>'telefono', ''),
    nullif(v_meta->>'escuela', ''),
    case when v_tipo in ('estudiante', 'docente', 'administrativo', 'externo')
         then v_tipo::public.tipo_usuario else 'estudiante' end
  )
  on conflict (id) do nothing;
  return new;
end $$;

drop trigger if exists on_auth_user_created on auth.users;
create trigger on_auth_user_created after insert on auth.users
  for each row execute function public.crear_perfil_nuevo_usuario();

-- Nadie puede auto-ascenderse a doctor/admin: solo un admin cambia rol,
-- especialidad o estado activo. (Desde el SQL Editor sí se permite.)
create or replace function public.proteger_campos_perfil()
returns trigger language plpgsql security definer set search_path = public as $$
begin
  if auth.uid() is not null and not public.es_admin() then
    if new.rol is distinct from old.rol
       or new.especialidad_id is distinct from old.especialidad_id
       or new.activo is distinct from old.activo then
      raise exception 'Solo un administrador puede cambiar el rol, la especialidad o el estado de una cuenta';
    end if;
  end if;
  return new;
end $$;

drop trigger if exists perfiles_proteger on public.perfiles;
create trigger perfiles_proteger before update on public.perfiles
  for each row execute function public.proteger_campos_perfil();

-- ---------------------------------------------------------------------
-- 4. Lógica de negocio (RPC que llama la app)
-- ---------------------------------------------------------------------

-- Bloques de atención de un profesional en una fecha, con disponibilidad
create or replace function public.horarios_disponibles(p_doctor_id uuid, p_fecha date)
returns table (slot_inicio time, slot_fin time, turno text, disponible boolean)
language sql stable security definer set search_path = public as $$
  with bloques as (
    select gs::time as ini,
           (gs + make_interval(mins => h.duracion_minutos))::time as fin
    from public.horarios_doctor h
    cross join lateral generate_series(
      p_fecha + h.hora_inicio,
      p_fecha + h.hora_fin - make_interval(mins => h.duracion_minutos),
      make_interval(mins => h.duracion_minutos)
    ) as gs
    where h.doctor_id = p_doctor_id
      and h.activo
      and h.dia_semana = extract(isodow from p_fecha)
  )
  select distinct on (b.ini)
    b.ini,
    b.fin,
    case when b.ini < time '13:00' then 'mañana' else 'tarde' end,
    not exists (
      select 1 from public.citas c
      where c.doctor_id = p_doctor_id and c.fecha = p_fecha
        and c.hora_inicio = b.ini and c.estado <> 'cancelada'
    )
    and (p_fecha > public.hoy_local()
         or (p_fecha = public.hoy_local() and b.ini > public.ahora_local()::time))
  from bloques b
  order by b.ini
$$;

-- Reservar una cita (valida todo en el servidor)
create or replace function public.reservar_cita(
  p_doctor_id      uuid,
  p_fecha          date,
  p_hora           time,
  p_motivo         text default null,
  p_cita_origen_id bigint default null,
  p_paciente_id    uuid default null          -- solo admin puede reservar para otro
)
returns public.citas language plpgsql security definer set search_path = public as $$
declare
  v_paciente uuid := coalesce(p_paciente_id, auth.uid());
  v_doctor   public.perfiles;
  v_slot     record;
  v_cita     public.citas;
begin
  if auth.uid() is null then
    raise exception 'Debes iniciar sesión';
  end if;
  if v_paciente <> auth.uid() and not public.es_admin() then
    raise exception 'No puedes reservar citas para otra persona';
  end if;
  if p_fecha < public.hoy_local() or p_fecha > public.hoy_local() + 60 then
    raise exception 'Solo puedes reservar desde hoy hasta 60 días adelante';
  end if;

  if p_cita_origen_id is not null and not exists (
    select 1 from public.citas where id = p_cita_origen_id and paciente_id = v_paciente
  ) then
    raise exception 'La cita de origen de la derivación no es válida';
  end if;

  select * into v_doctor from public.perfiles
   where id = p_doctor_id and rol = 'doctor' and activo;
  if not found or v_doctor.especialidad_id is null then
    raise exception 'El profesional seleccionado no está disponible';
  end if;

  select * into v_slot from public.horarios_disponibles(p_doctor_id, p_fecha)
   where slot_inicio = p_hora;
  if not found then
    raise exception 'Ese horario no pertenece a la agenda del profesional';
  end if;
  if not v_slot.disponible then
    raise exception 'Ese horario ya no está disponible, elige otro';
  end if;

  if exists (
    select 1 from public.citas
     where paciente_id = v_paciente and especialidad_id = v_doctor.especialidad_id
       and fecha = p_fecha and estado in ('pendiente', 'confirmada')
  ) then
    raise exception 'Ya tienes una cita de esta área ese mismo día';
  end if;

  insert into public.citas (paciente_id, doctor_id, especialidad_id, fecha, hora_inicio, hora_fin, motivo, cita_origen_id)
  values (v_paciente, p_doctor_id, v_doctor.especialidad_id, p_fecha, p_hora, v_slot.slot_fin,
          nullif(trim(p_motivo), ''), p_cita_origen_id)
  returning * into v_cita;

  return v_cita;
exception
  when unique_violation then
    raise exception 'Alguien acaba de tomar ese horario o ya tienes otra cita a esa hora';
end $$;

-- Verifica que quien opera la cita sea su profesional o un admin
create or replace function public._cita_para_profesional(p_cita_id bigint)
returns public.citas language plpgsql security definer set search_path = public as $$
declare v_cita public.citas;
begin
  select * into v_cita from public.citas where id = p_cita_id for update;
  if not found then
    raise exception 'La cita no existe';
  end if;
  if v_cita.doctor_id <> auth.uid() and not public.es_admin() then
    raise exception 'No tienes permiso sobre esta cita';
  end if;
  return v_cita;
end $$;

-- Cancelar (paciente dueño, su profesional o admin)
create or replace function public.cancelar_cita(p_cita_id bigint, p_motivo text default null)
returns public.citas language plpgsql security definer set search_path = public as $$
declare v_cita public.citas;
begin
  select * into v_cita from public.citas where id = p_cita_id for update;
  if not found then
    raise exception 'La cita no existe';
  end if;
  if auth.uid() not in (v_cita.paciente_id, v_cita.doctor_id) and not public.es_admin() then
    raise exception 'No tienes permiso sobre esta cita';
  end if;
  if v_cita.estado not in ('pendiente', 'confirmada') then
    raise exception 'Solo se pueden cancelar citas pendientes o confirmadas';
  end if;

  update public.citas
     set estado = 'cancelada', motivo_cancelacion = nullif(trim(p_motivo), ''),
         cancelada_por = auth.uid(), cancelada_en = now()
   where id = p_cita_id
  returning * into v_cita;
  return v_cita;
end $$;

-- El profesional confirma la cita
create or replace function public.confirmar_cita(p_cita_id bigint)
returns public.citas language plpgsql security definer set search_path = public as $$
declare v_cita public.citas;
begin
  v_cita := public._cita_para_profesional(p_cita_id);
  if v_cita.estado <> 'pendiente' then
    raise exception 'Solo se confirman citas pendientes';
  end if;
  update public.citas set estado = 'confirmada' where id = p_cita_id returning * into v_cita;
  return v_cita;
end $$;

-- Registrar que el paciente llegó (marca asistencia y hora de llegada)
create or replace function public.registrar_llegada(p_cita_id bigint)
returns public.citas language plpgsql security definer set search_path = public as $$
declare v_cita public.citas;
begin
  v_cita := public._cita_para_profesional(p_cita_id);
  if v_cita.estado not in ('pendiente', 'confirmada') then
    raise exception 'La cita ya fue cerrada';
  end if;
  update public.citas
     set asistio = true, hora_llegada = coalesce(hora_llegada, now()),
         estado = 'confirmada'
   where id = p_cita_id returning * into v_cita;
  return v_cita;
end $$;

-- Marcar inasistencia
create or replace function public.marcar_no_asistio(p_cita_id bigint)
returns public.citas language plpgsql security definer set search_path = public as $$
declare v_cita public.citas;
begin
  v_cita := public._cita_para_profesional(p_cita_id);
  if v_cita.estado not in ('pendiente', 'confirmada') then
    raise exception 'La cita ya fue cerrada';
  end if;
  update public.citas
     set asistio = false, estado = 'no_asistio', hora_llegada = null
   where id = p_cita_id returning * into v_cita;
  return v_cita;
end $$;

-- Registrar la atención: guarda día/hora exactos, diagnóstico y derivación
create or replace function public.registrar_atencion(
  p_cita_id            bigint,
  p_diagnostico        text default null,
  p_indicaciones       text default null,
  p_observaciones      text default null,
  p_derivado_a         smallint default null,
  p_derivacion_externa text default null,
  p_motivo_derivacion  text default null
)
returns public.citas language plpgsql security definer set search_path = public as $$
declare v_cita public.citas;
begin
  v_cita := public._cita_para_profesional(p_cita_id);
  if v_cita.estado in ('cancelada', 'no_asistio') then
    raise exception 'No se puede atender una cita cancelada o con inasistencia';
  end if;
  update public.citas
     set estado             = 'atendida',
         asistio            = true,
         hora_llegada       = coalesce(hora_llegada, now()),
         atendida_en        = coalesce(atendida_en, now()),
         diagnostico        = nullif(trim(p_diagnostico), ''),
         indicaciones       = nullif(trim(p_indicaciones), ''),
         observaciones      = nullif(trim(p_observaciones), ''),
         derivado_a         = p_derivado_a,
         derivacion_externa = nullif(trim(p_derivacion_externa), ''),
         motivo_derivacion  = nullif(trim(p_motivo_derivacion), '')
   where id = p_cita_id returning * into v_cita;
  return v_cita;
end $$;

-- ---------------------------------------------------------------------
-- 5. Notificaciones automáticas
-- ---------------------------------------------------------------------
create or replace function public.notificar_cambio_cita()
returns trigger language plpgsql security definer set search_path = public as $$
declare
  v_area     text;
  v_doctor   text;
  v_paciente text;
  v_cuando   text := to_char(new.fecha, 'DD/MM/YYYY') || ' a las ' || to_char(new.hora_inicio, 'HH24:MI');
  v_derivada text;
begin
  select nombre into v_area from public.especialidades where id = new.especialidad_id;
  select trim(nombres || ' ' || apellidos) into v_doctor   from public.perfiles where id = new.doctor_id;
  select trim(nombres || ' ' || apellidos) into v_paciente from public.perfiles where id = new.paciente_id;

  if tg_op = 'INSERT' then
    insert into public.notificaciones (usuario_id, titulo, mensaje, cita_id) values
      (new.paciente_id, 'Cita reservada',
       format('Tu cita de %s con %s es el %s.', v_area, v_doctor, v_cuando), new.id),
      (new.doctor_id, 'Nueva cita en tu agenda',
       format('%s reservó una cita para el %s.', v_paciente, v_cuando), new.id);

  elsif new.estado is distinct from old.estado then
    if new.estado = 'confirmada' and old.estado = 'pendiente' then
      insert into public.notificaciones (usuario_id, titulo, mensaje, cita_id) values
        (new.paciente_id, 'Cita confirmada',
         format('Tu cita de %s del %s fue confirmada.', v_area, v_cuando), new.id);
    elsif new.estado = 'cancelada' then
      insert into public.notificaciones (usuario_id, titulo, mensaje, cita_id)
      select u, 'Cita cancelada',
             format('La cita de %s del %s fue cancelada.%s', v_area, v_cuando,
                    coalesce(' Motivo: ' || new.motivo_cancelacion, '')), new.id
        from unnest(array[new.paciente_id, new.doctor_id]) as u
       where u is distinct from new.cancelada_por;
    elsif new.estado = 'atendida' then
      if new.derivado_a is not null then
        select nombre into v_derivada from public.especialidades where id = new.derivado_a;
      end if;
      insert into public.notificaciones (usuario_id, titulo, mensaje, cita_id) values
        (new.paciente_id, 'Atención registrada',
         format('Fuiste atendido en %s.%s', v_area,
                case
                  when v_derivada is not null then ' Te derivaron a ' || v_derivada || ': reserva tu cita desde la app.'
                  when new.derivacion_externa is not null then ' Derivación: ' || new.derivacion_externa || '.'
                  else ''
                end), new.id);
    elsif new.estado = 'no_asistio' then
      insert into public.notificaciones (usuario_id, titulo, mensaje, cita_id) values
        (new.paciente_id, 'Inasistencia registrada',
         format('No asististe a tu cita de %s del %s. Puedes reservar una nueva.', v_area, v_cuando), new.id);
    end if;
  end if;
  return new;
end $$;

drop trigger if exists citas_notificar on public.citas;
create trigger citas_notificar after insert or update on public.citas
  for each row execute function public.notificar_cambio_cita();

-- ---------------------------------------------------------------------
-- 6. Vista para listas y reportes (respeta RLS del usuario que consulta)
-- ---------------------------------------------------------------------
create or replace view public.v_citas with (security_invoker = true) as
select
  c.*,
  e.nombre                                as especialidad_nombre,
  e.codigo                                as especialidad_codigo,
  e.color                                 as especialidad_color,
  trim(p.nombres || ' ' || p.apellidos)   as paciente_nombre,
  p.dni                                   as paciente_dni,
  p.codigo_universitario                  as paciente_codigo,
  p.tipo_usuario                          as paciente_tipo,
  p.telefono                              as paciente_telefono,
  p.escuela                               as paciente_escuela,
  trim(d.nombres || ' ' || d.apellidos)   as doctor_nombre,
  d.consultorio                           as consultorio,
  ed.nombre                               as derivado_a_nombre,
  trim(cp.nombres || ' ' || cp.apellidos) as cancelada_por_nombre
from public.citas c
join public.especialidades e  on e.id  = c.especialidad_id
join public.perfiles       p  on p.id  = c.paciente_id
join public.perfiles       d  on d.id  = c.doctor_id
left join public.especialidades ed on ed.id = c.derivado_a
left join public.perfiles       cp on cp.id = c.cancelada_por;

-- ---------------------------------------------------------------------
-- 7. Seguridad a nivel de fila (RLS)
-- ---------------------------------------------------------------------
alter table public.especialidades  enable row level security;
alter table public.perfiles        enable row level security;
alter table public.horarios_doctor enable row level security;
alter table public.citas           enable row level security;
alter table public.notificaciones  enable row level security;

-- Especialidades: todos leen, solo admin edita
drop policy if exists "especialidades_leer"  on public.especialidades;
drop policy if exists "especialidades_admin" on public.especialidades;
create policy "especialidades_leer"  on public.especialidades for select to authenticated using (true);
create policy "especialidades_admin" on public.especialidades for all    to authenticated
  using (public.es_admin()) with check (public.es_admin());

-- Perfiles
drop policy if exists "perfiles_leer"       on public.perfiles;
drop policy if exists "perfiles_actualizar" on public.perfiles;
create policy "perfiles_leer" on public.perfiles for select to authenticated using (
  id = auth.uid()
  or rol = 'doctor'                                  -- los profesionales son visibles para reservar
  or public.es_admin()
  or exists (select 1 from public.citas c            -- el profesional ve a sus pacientes
              where c.paciente_id = perfiles.id and c.doctor_id = auth.uid())
);
create policy "perfiles_actualizar" on public.perfiles for update to authenticated
  using (id = auth.uid() or public.es_admin())
  with check (id = auth.uid() or public.es_admin());

-- Horarios: todos leen; cada profesional gestiona los suyos; admin todos
drop policy if exists "horarios_leer"    on public.horarios_doctor;
drop policy if exists "horarios_editar"  on public.horarios_doctor;
create policy "horarios_leer"   on public.horarios_doctor for select to authenticated using (true);
create policy "horarios_editar" on public.horarios_doctor for all    to authenticated
  using      ((doctor_id = auth.uid() and public.rol_actual() = 'doctor') or public.es_admin())
  with check ((doctor_id = auth.uid() and public.rol_actual() = 'doctor') or public.es_admin());

-- Citas: cada quien ve las suyas; los cambios pasan por las funciones RPC
drop policy if exists "citas_leer"  on public.citas;
drop policy if exists "citas_admin" on public.citas;
create policy "citas_leer"  on public.citas for select to authenticated
  using (paciente_id = auth.uid() or doctor_id = auth.uid() or public.es_admin());
create policy "citas_admin" on public.citas for update to authenticated
  using (public.es_admin()) with check (public.es_admin());

-- Notificaciones: solo las propias
drop policy if exists "notificaciones_propias" on public.notificaciones;
create policy "notificaciones_propias" on public.notificaciones for select to authenticated
  using (usuario_id = auth.uid());
drop policy if exists "notificaciones_marcar" on public.notificaciones;
create policy "notificaciones_marcar" on public.notificaciones for update to authenticated
  using (usuario_id = auth.uid()) with check (usuario_id = auth.uid());

-- Las funciones internas no deben llamarse desde fuera
revoke execute on function public._cita_para_profesional(bigint) from public, anon, authenticated;
revoke execute on function public.crear_perfil_nuevo_usuario()  from public, anon, authenticated;
