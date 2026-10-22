import { JobsWorkspace } from "@/components/jobs/jobs-workspace";
export default async function JobsPage({searchParams}:{searchParams:Promise<Record<string,string|string[]|undefined>>}) {
  const params=await searchParams;
  const value=(key:string)=>typeof params[key] === "string" ? params[key] as string : "";
  return <JobsWorkspace key={JSON.stringify(params)} initialJob={value("job")||null} initialAdd={!!params.add} initialUrl={value("url")} initialTitle={value("title")}/>;
}
