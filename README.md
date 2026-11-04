# rinconAF

Red social privada para la banda, estilo Fotolog. Es una página estática (sin build): la interfaz se publica en **Vercel** y las cuentas, los datos y los archivos viven en **Supabase**.

```
rinconaf/
├── index.html          la aplicación
├── config.js           tus credenciales de Supabase (URL + anon key)
└── supabase/
    └── schema.sql      tablas, seguridad (RLS) y bucket de archivos
```

## Qué está conectado a Supabase

| Parte | Dónde se guarda |
| --- | --- |
| Registro, entrar, salir, recuperar contraseña | Supabase Auth (correo + contraseña) |
| Perfil y personalización (colores, letras, fondo, fotos del día) | tabla `profiles` (campo `datos`) |
| Apodo `npc` + número de registro | lo pone la base de datos al registrarse |
| Solicitudes y amistades | `solicitudes`, `amistades` |
| Inicio: posteos, likes, comentarios | `posteos`, `likes`, `comentarios` |
| Firmas del libro de visitas, likes a perfiles, visitas | `firmas`, `likes_perfil`, `profiles.visitas` |
| Notificaciones | `notificaciones` |
| Fotos (achicadas en el celu) y videos de hasta 25 MB | Supabase Storage, bucket `media` |

**Todavía locales (solo en cada navegador):** chat privado, grupos, y la sección rincón. Funcionan, pero no se comparten entre dispositivos hasta pasarlos a Supabase.

## 1. Crear el proyecto en Supabase

1. Entrá a <https://supabase.com>, creá una cuenta y un proyecto nuevo (plan Free).
2. Andá a **SQL Editor → New query**, pegá todo `supabase/schema.sql` y tocá **Run**. Crea las tablas, las reglas de seguridad y el bucket `media`.
3. Andá a **Project Settings → API** y copiá:
   - **Project URL** (algo como `https://abcd1234.supabase.co`)
   - **anon public key**
4. Pegalas en `config.js`:

```js
window.RINCON_CONFIG = window.RINCON_CONFIG || {
  supabaseUrl: 'https://abcd1234.supabase.co',
  supabaseAnonKey: 'eyJhbGciOi...'
};
```

> La *anon key* está hecha para ir en la página: lo que protege los datos son las reglas RLS del `schema.sql`. **Nunca** pongas la `service_role` key en `config.js`.

## 2. Publicar en Vercel

**Opción A, con GitHub (recomendada):**
1. Subí la carpeta `rinconaf` a un repositorio de GitHub.
2. En <https://vercel.com> → **Add New → Project** → importá el repositorio.
3. Framework Preset: **Other**. Build Command: vacío. Output Directory: `.` (la raíz).
4. **Deploy**. Te da una dirección tipo `https://rinconaf.vercel.app`.

**Opción B, desde la compu:** con Node instalado, dentro de la carpeta corré `npx vercel` y seguí las preguntas.

## 3. Avisarle a Supabase cuál es tu dirección

En Supabase → **Authentication → URL Configuration**:
- **Site URL:** `https://rinconaf.vercel.app` (la que te dio Vercel)
- **Redirect URLs:** agregá la misma dirección.

Así funcionan los mails de confirmación de cuenta y de "me olvidé la contraseña".

**Confirmación por mail:** por defecto Supabase pide confirmar el correo antes de entrar. Si para la banda preferís que entren directo, desactivala en **Authentication → Sign In / Providers → Email → Confirm email**. El servicio de mails gratis de Supabase manda pocos mails por hora; para más, configurá un SMTP propio (por ejemplo Resend) en **Authentication → Emails**.

## 4. Probar

1. Abrí la dirección de Vercel, registrate (correo + contraseña dos veces) y personalizá tu perfil.
2. Desde otro celu o navegador, registrá una segunda cuenta, buscá la primera con la lupa y mandale solicitud.
3. Aceptala desde la primera cuenta: ya se ven los posteos, se pueden likear, comentar y firmar.

## Peso de los archivos

- Fotos: se achican antes de subir (máx. 1280 px, JPEG), quedan en ~100–300 KB.
- Videos: máximo 25 MB (el bucket también lo limita del lado del servidor).
- Plan Free de Supabase: 1 GB de archivos y 5 GB de descarga por mes. Si se queda corto: Supabase Pro (US$ 25/mes) o mover los archivos a Cloudflare R2.

**Privacidad de los archivos:** el bucket `media` es público para que las fotos carguen rápido; las direcciones son largas y no se pueden adivinar, pero quien tenga el link exacto puede abrir la foto. Si más adelante querés que solo los usuarios registrados puedan verlas, se cambia a bucket privado con links firmados.

## Próximos pasos sugeridos

- Pasar chat, grupos y rincón a Supabase (con Realtime para que los mensajes lleguen al instante).
- Actualización automática del inicio y las notificaciones con Supabase Realtime.
- Borrar automáticamente videos viejos del chat para cuidar el espacio.
