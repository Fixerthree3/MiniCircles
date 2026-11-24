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

The SQL setup includes profile interests, follows, feed engagement, and site updates. For an existing Supabase project, apply the newly added schema definitions and policies from [`supabase.sql`](supabase.sql); do not rerun its original `create policy` statements.

The original `Mini Circles.html` file is preserved as a source copy. `index.html` is the launch file.

## Launch checks

- Never collect learner names or learner ID numbers.
- Require an adult contact for cricket teams and reading circles.
- Verify Supabase email confirmation and redirect URLs.
- Test public sign-ups, editor sign-in, profile setup, Circle entry and membership, personalized feed actions, announcement/event publishing, press publishing, league updates, CSV downloads, and mobile layouts.
- Replace the sample league standings and press releases before launch.