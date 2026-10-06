-- =====================================================================
--  UniSalud · Datos iniciales
--  Ejecutar DESPUÉS de 01_esquema.sql
-- =====================================================================

insert into public.especialidades (codigo, nombre, descripcion, color) values
  ('medicina',    'Medicina General', 'Consultas médicas, chequeos, certificados de salud y malestares generales.', '#2563EB'),
  ('enfermeria',  'Enfermería',       'Curaciones, inyectables, control de presión, peso, talla y vacunas.',       '#DB2777'),
  ('psicologia',  'Psicología',       'Orientación, consejería, manejo del estrés y acompañamiento emocional.',     '#7C3AED'),
  ('odontologia', 'Odontología',      'Evaluación dental, limpieza, curaciones y orientación en salud bucal.',     '#0891B2')
on conflict (codigo) do update
  set nombre = excluded.nombre, descripcion = excluded.descripcion, color = excluded.color;

-- ---------------------------------------------------------------------
-- Convertir cuentas en ADMIN o PROFESIONAL
-- (primero la persona se registra desde la app, luego ejecutas esto)
-- ---------------------------------------------------------------------
-- Administrador (bienestar universitario / recepción):
--   update public.perfiles set rol = 'admin'
--    where email = 'admin@tu-universidad.edu.pe';
--
-- Profesional de salud (ejemplo: psicóloga en el consultorio 3):
--   update public.perfiles
--      set rol = 'doctor',
--          especialidad_id = (select id from public.especialidades where codigo = 'psicologia'),
--          consultorio = 'Consultorio 3 - Pabellón B'
--    where email = 'psicologa@tu-universidad.edu.pe';
--
-- Una vez que exista un admin, lo demás se hace desde la app
-- (pestaña "Usuarios" del administrador).
