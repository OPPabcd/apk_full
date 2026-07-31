import "@supabase/functions-js/edge-runtime.d.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

Deno.serve(async () => {
  const supabase = createClient(
    Deno.env.get("SUPABASE_URL")!,
    Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!,
  );

  const fiveMinutesAgo = new Date(Date.now() - 24 * 60 * 60 * 1000);

  const { data, error } = await supabase.auth.admin.listUsers();

  if (error) {
    return new Response(
      JSON.stringify({ error: error.message }),
      { status: 500 },
    );
  }

  const users = data.users;

  const targetUsers = users.filter((user) => {
    return (
      !user.email_confirmed_at &&
      new Date(user.created_at) < fiveMinutesAgo
    );
  });

  for (const user of targetUsers) {
    await supabase.auth.admin.deleteUser(user.id);
  }

  return new Response(
    JSON.stringify({
      deleted: targetUsers.length,
    }),
    { headers: { "Content-Type": "application/json" } },
  );
});
