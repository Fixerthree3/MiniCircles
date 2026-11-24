# Mini Circles

This repository contains a responsive, accessible single-page website for The Mlungisi Mashinini Foundation.

## Deploy

The easiest no-server option is Supabase plus Netlify or GitHub Pages.

1. Create a Supabase project.
2. Run [`supabase.sql`](supabase.sql) in the Supabase SQL editor.
3. In **Authentication > URL Configuration**, add the final website URL to **Site URL** and **Redirect URLs**.
4. In **Authentication > Providers**, enable Email and password sign-in. Configure the confirmation and password-reset redirect URLs in **Authentication > URL Configuration**.
5. Create an editor account, then add it to `public.profiles`:

   ```sql
   insert into public.profiles (id, name, can_edit)
   select id, 'Foundation Editor', true
   from auth.users
   where email = 'your-editor@example.org'
   on conflict (id) do update set name = excluded.name, can_edit = true;
   ```

6. Put the project URL and public publishable/anon key in `window.MINICIRCLES_CONFIG` in [`index.html`](index.html).
7. Deploy `index.html` to Netlify or GitHub Pages.

For an existing Supabase project, do not rerun the full setup script; apply only the required schema additions and policies described below.

The Home page is the default landing page, with an **About** page for the Foundation relationship, vision, mission, impact areas, and participation journeys. It has quick paths for common tasks and dedicated sections for news, programmes, and partner organisations. Primary journeys are surfaced in three clicks or fewer. Reading circles and youth cricket are the active programmes; Circle topics also support Education, Sport & wellbeing, Skills & employment, and Other for approved partner-led communities. Visitors can explore Circle portals. New accounts use a username, email and password, and confirm their email address once if email confirmation is enabled in Supabase; subsequent sign-ins use email and password without sending an email. Existing passwordless accounts can use **Forgot your password?** once to set a password. Signed-in members can follow Circles and other members, like, comment on, share, and save posts, and set interests for their recommended feed. Adults can request Circle Manager access; Site Admins review those requests and grant or revoke access in the Users area. Circle Admins can add images or videos to Circle updates and upload a Circle profile picture. Site editors manage announcements and events from the Home page.

The SQL setup includes profile interests, follows, feed engagement and saved posts, announcements/events, Circle slugs and profile pictures, role-aware moderation, member discovery, private direct messages, and competition logs for Cricket and Sport & wellbeing Circles. Site Admins (`profiles.can_edit`) can edit the Foundation league from the Cricket page. Circle Admins can create a league or tournament, add teams and record dated match results in their sports Circle; standings and match logs are public, while database policies restrict edits to that Circle's Admins and Site Admins. Circle post comments are visible on public posts and may be added by signed-in users; Circle moderation permissions still control removals. Circle roles are Site Admin, Circle Admin (Circle manager or `circle_members.role = 'admin'`), Moderator (`circle_members.role = 'moderator'`), and Member. Direct messages are visible only to their sender and recipient; the signed-in member directory exposes display names, not email addresses. The separate Site Admin account-management function returns account emails only to verified Site Admins.

Circle post media and profile pictures use the public-read `circle-media` Supabase Storage bucket. The schema configures a 20 MB file limit and restricts uploads/removals to Circle Admins for their own Circle. Run the updated [`supabase.sql`](supabase.sql) setup or apply its dedicated feed/media section to an existing project before enabling uploads and saved posts.

Site Admins can schedule announcements and events, change the default theme, enable or pause Circle discovery, the feed, messages, and events, manage member accounts, and grant or revoke Circle Manager access. These privileged account actions are handled by the `admin-delete-user` Edge Function, not by browser-side service credentials. Deploy it and configure the service-role secret in Supabase:

```sh
supabase secrets set SUPABASE_SERVICE_ROLE_KEY=your-service-role-key
supabase functions deploy admin-delete-user
```

Never put the service-role key in `index.html` or expose it to clients. The function verifies the caller's Site Admin profile, lists accounts only for Site Admins, and prevents deleting the last Site Admin or the current account. A database trigger anonymises authored Circle posts during account deletion; linked memberships, comments and private messages are removed by their foreign-key rules.

## Site translation

The language selector supports English and the other ten written official South African languages: Afrikaans, isiNdebele, isiXhosa, isiZulu, Sepedi, Sesotho, Setswana, siSwati, Tshivenda, and Xitsonga. It translates rendered public interface text, public Circle and feed content, supported text attributes, and page descriptions. The visitor's selection is stored in their browser. South African Sign Language needs video interpretation and is not part of this text translator.

Translation uses Google Cloud Translation. To enable it:

1. Enable the Cloud Translation API in a Google Cloud project and create an API key restricted to that API. Set conservative Translation quotas and billing alerts; the browser-callable translation function is public and the key's quota is the cost-control boundary.
2. Set the key as a Supabase secret and deploy the public function:

   ```sh
   supabase secrets set GOOGLE_TRANSLATE_API_KEY=your-google-api-key
   supabase functions deploy translate-site --no-verify-jwt
   ```

3. Confirm translation works on the deployed site in each supported language. If the key, API, or quota is unavailable, the original English text remains and the selector reports that translation could not be completed.

When a visitor selects a non-English language, public site text and public Circle/feed content are sent to Google for translation. Private direct messages, sign-up records, account details, and member-directory/account selectors are excluded. Sign-up contact tables are also excluded; the surrounding admin interface remains translatable. Machine translation can be inaccurate: review important safeguarding, health, legal, or programme instructions with fluent speakers before relying on them.

For an existing Supabase project, apply the newly added schema definitions and policies from [`supabase.sql`](supabase.sql), including the `circle_competitions` table and its two policies, and the `circles_type_allowed_check` constraint update that permits the expanded Circle topics; do not rerun its original `create policy` statements. The SQL file is a first-install setup, not a fully idempotent migration.

The original `Mini Circles.html` file is preserved as a source copy. `index.html` is the launch file.

## Launch checks

- Never collect learner names or learner ID numbers.
- Require an adult contact for cricket teams and reading circles.
- Review partner requests before granting Circle Manager access.
- Verify Supabase email confirmation and redirect URLs.
- Test public sign-ups, Site Admin sign-in and the Foundation league editor on desktop, profile setup, Circle entry and membership, Circle role assignment and moderation, sports Circle competition creation and administration, share links, image/video uploads and profile pictures, comments, direct messages, feed like/share/save actions, scheduled announcements/events, global settings, account deletion, press publishing, league updates, CSV downloads, and mobile layouts.
- Replace the sample league standings and press releases before launch.