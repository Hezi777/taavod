"use client";

import Link from "next/link";
import { ArrowUpRight, Check, Inbox } from "lucide-react";
import { Button } from "@/components/ui/button";
import { Badge } from "@/components/ui/badge";
import { Card, CardContent, CardDescription, CardHeader, CardTitle } from "@/components/ui/card";
import type { ReactNode } from "react";

export function PageHeading({ title, description, action }: {title:string;description:string;action?:ReactNode}) {
  return <div className="page-heading"><div><h1>{title}</h1><p>{description}</p></div>{action}</div>;
}
export function SectionCard({ title, description, children, action, className="" }: {title:string;description?:string;children:ReactNode;action?:ReactNode;className?:string}) {
  return <Card className={`section-card ${className}`}><CardHeader className="section-card-header"><div><CardTitle>{title}</CardTitle>{description && <CardDescription>{description}</CardDescription>}</div>{action}</CardHeader><CardContent>{children}</CardContent></Card>;
}
export function EmptyState({title,description,href,label}: {title:string;description:string;href?:string;label?:string}) {
  return <div className="empty-state"><div className="empty-icon"><Inbox size={22}/></div><h3>{title}</h3><p>{description}</p>{href && <Button asChild variant="outline"><Link href={href}>{label ?? "Get started"}<ArrowUpRight size={15}/></Link></Button>}</div>;
}
export function StatusBadge({children,tone="neutral"}: {children:ReactNode;tone?:"neutral"|"blue"|"green"|"amber"}) {
 return <Badge variant="outline" className={`status-badge tone-${tone}`}>{tone === "green" && <Check size={11}/>} {children}</Badge>;
}
export function LoadingState(){return <div className="workspace-loading" role="status" aria-live="polite"><div className="loading-heading"/><div className="loading-subheading"/><div className="loading-focus"/><div className="loading-columns"><div/><div/></div><span className="sr-only">Loading your workspace…</span></div>}
export function FormMessage({message,error=false}:{message:string;error?:boolean}){return message ? <p role={error?"alert":"status"} className={`form-message ${error?"is-error":""}`}>{message}</p>:null}
