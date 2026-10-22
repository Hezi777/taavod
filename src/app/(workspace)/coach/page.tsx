"use client";

import { Suspense, useEffect } from "react";
import { useSearchParams } from "next/navigation";
import { ArrowUpRight, MessageCircle } from "lucide-react";
import { Button } from "@/components/ui/button";
import { PageHeading } from "@/components/career/shared";
import { openCareerCoach } from "@/components/career/coach-events";

export default function CoachPage() {
  return <Suspense><CoachWorkspace /></Suspense>;
}

function CoachWorkspace() {
  const params = useSearchParams();
  const prompt = params.get("prompt") || undefined;
  const type = params.get("type") || undefined;
  const id = params.get("id") || undefined;
  useEffect(() => {
    const frame = requestAnimationFrame(() => openCareerCoach({ expanded: true, prompt, type, id }));
    return () => cancelAnimationFrame(frame);
  }, [prompt, type, id]);

  return <><PageHeading title="Career coach" description="A thinking partner for your learning, projects, and next role." />
    <section className="coach-page-entry"><MessageCircle size={30} strokeWidth={1.5} /><h2>Keep the conversation close.</h2><p>Your coach is available from every screen. Open a small window while you work, or expand it when you want to focus. Your conversation stays with you.</p><Button onClick={() => openCareerCoach({ expanded: true })}>Open your coach<ArrowUpRight size={16} /></Button></section>
  </>;
}
