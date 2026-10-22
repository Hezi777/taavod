import {describe,it,expect,vi,beforeEach} from 'vitest';
const otp=vi.hoisted(()=>vi.fn(async()=>({error:null})));
vi.mock('@/lib/server/auth',()=>({sessionClient:async()=>({auth:{signInWithOtp:otp}}),assertSameOrigin:async()=>{},apiError:()=>new Response(null,{status:500}),HttpError:class extends Error{constructor(public status:number,message:string){super(message)}}}));
vi.mock('@/lib/server/config',()=>({ownerAllowed:()=>true,cloudConfigured:()=>true}));
import {POST} from '@/app/api/auth/signin/route';
describe('Local magic-link redirect',()=>{
 beforeEach(()=>otp.mockClear());
 it('keeps the browser origin when the framework request URL uses localhost',async()=>{
  const response=await POST(new Request('http://localhost:3100/api/auth/signin',{method:'POST',headers:{origin:'http://127.0.0.1:3100','content-type':'application/json'},body:JSON.stringify({email:'owner@example.com'})}));
  expect(response.status).toBe(200);expect(otp).toHaveBeenCalledWith({email:'owner@example.com',options:{shouldCreateUser:false,emailRedirectTo:'http://127.0.0.1:3100/auth/callback'}});
 });
});
