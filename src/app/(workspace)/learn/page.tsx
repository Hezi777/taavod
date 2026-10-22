import {LearnWorkspace} from '@/components/learning/learn-workspace';
import '@/components/learning/learning-workbench.css';
export default async function LearnPage({searchParams}:{searchParams:Promise<Record<string,string|string[]|undefined>>}){
 const params=await searchParams;
 return <LearnWorkspace key={JSON.stringify(params)} initialTrack={typeof params.track==='string'?params.track:undefined} initialLesson={typeof params.lesson==='string'?params.lesson:undefined}/>;
}
