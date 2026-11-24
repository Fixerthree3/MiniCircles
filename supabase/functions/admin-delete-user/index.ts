import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
};

function reply(status: number, body: Record<string, unknown>) {
  return new Response(JSON.stringify(body), {
    status,
    headers: { ...corsHeaders, "Content-Type": "application/json" },
  });
}

Deno.serve(async (request: Request) => {
  if (request.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }
  if (request.method !== "POST") {
    return reply(405, { error: "Method not allowed." });
  }

  const supabaseUrl = Deno.env.get("SUPABASE_URL");
  const anonKey = Deno.env.get("SUPABASE_ANON_KEY");
  const serviceRoleKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY");
  const authorization = request.headers.get("Authorization");
  if (!supabaseUrl || !anonKey || !serviceRoleKey) {
    console.error("Required Supabase function environment variables are missing.");
    return reply(500, { error: "Account management is not configured." });
  }
  if (!authorization?.startsWith("Bearer ")) {
    return reply(401, { error: "Sign in is required." });
  }

  const userClient = createClient(supabaseUrl, anonKey, {
    global: { headers: { Authorization: authorization } },
  });
  const { data: userData, error: userError } = await userClient.auth.getUser();
  if (userError || !userData.user) {
    return reply(401, { error: "Your session is invalid or expired." });
  }
  const { data: callerProfile, error: profileError } = await userClient
    .from("profiles")
    .select("can_edit")
    .eq("id", userData.user.id)
    .maybeSingle();
  if (profileError) {
    console.error("Could not verify the caller's Site Admin role.", profileError);
    return reply(500, { error: "Could not verify Site Admin access." });
  }
  if (!callerProfile?.can_edit) {
    return reply(403, { error: "Site Admin access is required." });
  }

  let payload: { action?: unknown; page?: unknown; userId?: unknown; enabled?: unknown };
  try {
    payload = await request.json();
  } catch {
    return reply(400, { error: "A valid request body is required." });
  }
  if (!payload || typeof payload !== "object" || Array.isArray(payload)) {
    return reply(400, { error: "A valid request body is required." });
  }

  const adminClient = createClient(supabaseUrl, serviceRoleKey);
  const action = payload.action ?? "delete";
  if (action === "list") {
    const page = Number(payload.page ?? 1);
    if (!Number.isInteger(page) || page < 1 || page > 10000) {
      return reply(400, { error: "A valid account page is required." });
    }
    const pageSize = 500;
    const { data: accountPage, error: listError } = await adminClient.auth.admin.listUsers({
      page,
      perPage: pageSize,
    });
    if (listError) {
      console.error("Could not list accounts for Site Admin.", listError);
      return reply(500, { error: "Could not load the account list." });
    }
    const users = accountPage.users;
    const { data: profiles, error: usersProfileError } = users.length
      ? await adminClient      .from("profiles").select("id,name,can_edit,circle_manager").in("id", users.map((user) => user.id))
      : { data: [], error: null };
    if (usersProfileError) {
      console.error("Could not load account profile details.", usersProfileError);
      return reply(500, { error: "Could not load account profile details." });
    }
    const profileById = new Map((profiles ?? []).map((profile) => [profile.id, profile]));
    return reply(200, {
      users: users.map((user) => {
        const profile = profileById.get(user.id);
        return {
          id: user.id,
          email: user.email ?? null,
          name: profile?.name ?? null,
          canEdit: !!profile?.can_edit,
          circleManager: !!profile?.circle_manager,
        };
      }),
      hasMore: users.length === pageSize,
    });
  }
  if (action === "set-circle-manager") {
    const userId = payload.userId;
    const enabled = payload.enabled;
    if (typeof userId !== "string" || !/^[0-9a-f]{8}-[0-9a-f]{4}-[1-8][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i.test(userId)) {
      return reply(400, { error: "A valid userId is required." });
    }
    if (typeof enabled !== "boolean") {
      return reply(400, { error: "A boolean enabled value is required." });
    }
    if (userId === userData.user.id) {
      return reply(400, { error: "Site Admins do not need Circle Manager access." });
    }

    const { data: target, error: targetError } = await adminClient.auth.admin.getUserById(userId);
    if (targetError || !target.user) {
      return reply(404, { error: "That account could not be found." });
    }
    const { data: targetProfile, error: targetProfileError } = await adminClient
      .from("profiles")
      .select("can_edit")
      .eq("id", userId)
      .maybeSingle();
    if (targetProfileError) {
      console.error("Could not load the target account's role.", targetProfileError);
      return reply(500, { error: "Could not verify the target account." });
    }
    if (targetProfile?.can_edit) {
      return reply(400, { error: "Site Admins do not need Circle Manager access." });
    }

    const { error: updateError } = await adminClient
      .from("profiles")
      .upsert({ id: userId, circle_manager: enabled });
    if (updateError) {
      console.error("Could not update Circle Manager access.", updateError);
      return reply(500, { error: "Circle Manager access could not be updated." });
    }
    return reply(200, { success: true, circleManager: enabled });
  }
  if (action !== "delete") {
    return reply(400, { error: "Unknown account management action." });
  }

  const userId = payload.userId;
  if (typeof userId !== "string" || !/^[0-9a-f]{8}-[0-9a-f]{4}-[1-8][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i.test(userId)) {
    return reply(400, { error: "A valid userId is required." });
  }
  if (userId === userData.user.id) {
    return reply(400, { error: "You cannot delete your own signed-in account." });
  }

  const { data: target, error: targetError } = await adminClient.auth.admin.getUserById(userId);
  if (targetError || !target.user) {
    return reply(404, { error: "That account could not be found." });
  }
  const { data: targetProfile, error: targetProfileError } = await adminClient
    .from("profiles")
    .select("can_edit")
    .eq("id", userId)
    .maybeSingle();
  if (targetProfileError) {
    console.error("Could not load the target account's role.", targetProfileError);
    return reply(500, { error: "Could not verify the target account." });
  }
  if (targetProfile?.can_edit) {
    const { count, error: adminCountError } = await adminClient
      .from("profiles")
      .select("id", { count: "exact", head: true })
      .eq("can_edit", true);
    if (adminCountError) {
      console.error("Could not verify remaining Site Admins.", adminCountError);
      return reply(500, { error: "Could not verify remaining Site Admin access." });
    }
    if ((count ?? 0) <= 1) {
      return reply(409, { error: "The last Site Admin account cannot be deleted." });
    }
  }

  const { error: deleteError } = await adminClient.auth.admin.deleteUser(userId);
  if (deleteError) {
    console.error("Account deletion failed.", deleteError);
    return reply(500, { error: "The account could not be deleted." });
  }
  return reply(200, { success: true });
});
