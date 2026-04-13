import { serve } from "https://deno.land/std@0.168.0/http/server.ts"
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2'

const SUPABASE_URL = Deno.env.get('SUPABASE_URL')
const SUPABASE_SERVICE_ROLE_KEY = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')

const supabase = createClient(SUPABASE_URL!, SUPABASE_SERVICE_ROLE_KEY!)

serve(async (req) => {
  const { email, password } = await req.json()

  // 1. Find user by email
  const { data: { users }, error: listError } = await supabase.auth.admin.listUsers()
  
  if (listError) {
    return new Response(JSON.stringify({ error: listError.message }), { status: 400 })
  }

  const user = users.find(u => u.email === email)
  
  if (!user) {
    return new Response(JSON.stringify({ error: 'User not found' }), { status: 404 })
  }

  // 2. Update password
  const { error: updateError } = await supabase.auth.admin.updateUserById(user.id, {
    password: password,
  })

  if (updateError) {
    return new Response(JSON.stringify({ error: updateError.message }), { status: 400 })
  }

  return new Response(JSON.stringify({ success: true }), { status: 200 })
})
