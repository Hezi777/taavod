import {PracticeWorkspace} from '@/components/learning/practice-workspace';
import '@/components/learning/learning-workbench.css';
export default async function PracticePage({searchParams}:{searchParams:Promise<Record<string,string|string[]|undefined>>}){
 const params=await searchParams;
 return <PracticeWorkspace key={JSON.stringify(params)} initialExercise={typeof params.exercise==='string'?params.exercise:undefined} initialTrack={typeof params.track==='string'?params.track:undefined} assessment={params.mode==='assessment'} explore={params.mode==='explore'} review={params.review==='1'}/>;
}
