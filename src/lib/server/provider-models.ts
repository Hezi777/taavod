import 'server-only';import {HttpError} from './auth';import type {Provider} from './integrations';
export type ProviderModel={id:string;name:string};
export async function providerModels(provider:Provider,apiKey:string):Promise<ProviderModel[]>{
 const url=provider==='anthropic'?'https://api.anthropic.com/v1/models?limit=1000':provider==='groq'?'https://api.groq.com/openai/v1/models':'https://api.tavily.com/usage';
 const headers:Record<string,string>=provider==='anthropic'?{'x-api-key':apiKey,'anthropic-version':'2023-06-01'}:{Authorization:`Bearer ${apiKey}`};
 const response=await fetch(url,{headers,signal:AbortSignal.timeout(15000),cache:'no-store'});
 if(!response.ok)throw new HttpError(response.status===401||response.status===403?400:502,response.status===401||response.status===403?'That API key was not accepted.':`The provider could not be reached (${response.status}). Try again shortly.`);
 if(provider==='tavily')return [];
 const body=await response.json();return (Array.isArray(body.data)?body.data:[]).filter((m:{id?:string;active?:boolean})=>m.id&&m.active!==false&&(provider==='anthropic'||/llama|gpt-oss|qwen|gemma|mixtral|kimi/i.test(m.id))).map((m:{id:string;display_name?:string})=>({id:m.id,name:m.display_name||m.id}));
}
