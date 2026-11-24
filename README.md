# Mini Circles

This repository contains a responsive, accessible single-page website for The Mlungisi Mashinini Foundation.

## Deploy

The easiest no-server option is Supabase plus Netlify or GitHub Pages.

1. Create a Supabase project.
2. Run [`supabase.sql`](supabase.sql) in the Supabase SQL editor.
3. In **Authentication > URL Configuration**, add the final website URL to **Site URL** and **Redirect URLs**.
4. In **Authentication > Providers**, enable Email.
5. Create an editor account, then add it to `public.profiles`:

   ```sql
   insert into public.profiles (id, name, can_edit)
   select id, 'Foundation Editor', true
   from auth.users
   where email = 'your-editor@example.org';
   ```

6. Put the project URL and public publishable/anon key in `window.MINICIRCLES_CONFIG` in [`index.html`](index.html).
7. Deploy `index.html` to Netlify or GitHub Pages.

The Home page is the default landing page. From there, visitors can explore Circle portals and sign in with a Circle-specific email link. Signed-in members can follow Circles and other members, like posts, and set interests for their recommended feed. Site editors manage announcements and events from the Home page.

The SQL setup includes profile interests, follows, feed engagement, announcements/events, Circle slugs, role-aware moderation, member discovery, and private direct messages. Circle roles are Site Admin (`profiles.can_edit`), Circle Admin (Circle manager or `circle_members.role = 'admin'`), Moderator (`circle_members.role = 'moderator'`), and Member. Direct messages are visible only to their sender and recipient; the signed-in member directory exposes display names, not email addresses. The separate Site Admin account-management function returns account emails only to verified Site Admins.

Site Admins can schedule announcements and events, change the default theme, enable or pause Circle discovery, the feed, messages, and events, and manage member accounts. Account deletion is handled by the `admin-delete-user` Edge Function, not by browser-side service credentials. Deploy it and configure the service-role secret in Supabase:

```sh
supabase secrets set SUPABASE_SERVICE_ROLE_KEY=your-service-role-key
supabase functions deploy admin-delete-user
```

Never put the service-role key in `index.html` or expose it to clients. The function verifies the caller's Site Admin profile, lists accounts only for Site Admins, and prevents deleting the last Site Admin or the current account. A database trigger anonymises authored Circle posts during account deletion; linked memberships, comments and private messages are removed by their foreign-key rules.

For an existing Supabase project, apply the newly added schema definitions and policies from [`supabase.sql`](supabase.sql); do not rerun its original `create policy` statements. The SQL file is a first-install setup, not a fully idempotent migration.

The original `Mini Circles.html` file is preserved as a source copy. `index.html` is the launch file.

## Launch checks

- Never collect learner names or learner ID numbers.
- Require an adult contact for cricket teams and reading circles.
- Verify Supabase email confirmation and redirect URLs.
- Test public sign-ups, editor sign-in, profile setup, Circle entry and membership, Circle role assignment and moderation, share links, comments, direct messages, personalized feed actions, scheduled announcements/events, global settings, account deletion, press publishing, league updates, CSV downloads, and mobile layouts.
- Replace the sample league standings and press releases before launch.