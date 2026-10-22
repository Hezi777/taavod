import 'server-only';
export function cloudConfigured() { return Boolean(process.env.NEXT_PUBLIC_SUPABASE_URL && process.env.NEXT_PUBLIC_SUPABASE_PUBLISHABLE_KEY); }
export function localMode() { return process.env.LOCAL_DEV_MODE === '1' && process.env.NODE_ENV !== 'production' && !process.env.VERCEL; }
export function ownerAllowed(email?: string) { return process.env.MULTI_USER_ENABLED === 'true' || Boolean(email && email.toLowerCase() === process.env.OWNER_EMAIL?.toLowerCase()); }

export function localSupabase(){try{return ['127.0.0.1','localhost','[::1]'].includes(new URL(process.env.NEXT_PUBLIC_SUPABASE_URL||'').hostname);}catch{return false;}}
