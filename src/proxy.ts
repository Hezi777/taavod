import {createServerClient} from '@supabase/ssr';
import {NextResponse,type NextRequest} from 'next/server';
export async function proxy(request:NextRequest){
 let response=NextResponse.next({request});response.headers.set('Cache-Control','private, no-store');
 if(process.env.LOCAL_DEV_MODE==='1'&&process.env.NODE_ENV!=='production'&&!process.env.VERCEL)return response;
 const publicRoute=request.nextUrl.pathname.startsWith('/login')||request.nextUrl.pathname.startsWith('/auth')||request.nextUrl.pathname.startsWith('/api/');
 if(!process.env.NEXT_PUBLIC_SUPABASE_URL||!process.env.NEXT_PUBLIC_SUPABASE_PUBLISHABLE_KEY){if(!publicRoute)return NextResponse.redirect(new URL('/login?setup=1',request.url));return response;}
 const supabase=createServerClient(process.env.NEXT_PUBLIC_SUPABASE_URL,process.env.NEXT_PUBLIC_SUPABASE_PUBLISHABLE_KEY,{cookies:{getAll:()=>request.cookies.getAll(),setAll(values){values.forEach(({name,value})=>request.cookies.set(name,value));response=NextResponse.next({request});values.forEach(({name,value,options})=>response.cookies.set(name,value,options));response.headers.set('Cache-Control','private, no-store');}}});
 const {data}=await supabase.auth.getClaims();
 if(!data?.claims&&!publicRoute)return NextResponse.redirect(new URL('/login',request.url));return response;
}
export const config={matcher:['/((?!_next/static|_next/image|favicon.ico|practice/runtime|practice/data|.*\\.(?:svg|png|jpg|webp|wasm|csv)$).*)']};
