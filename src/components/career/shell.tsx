"use client";

import Link from "next/link";
import Image from "next/image";
import { usePathname, useRouter } from "next/navigation";
import { useEffect, useMemo, useRef, useState, useSyncExternalStore } from "react";
import { useTheme } from "next-themes";
import { ArrowUpRight, BookOpen, BriefcaseBusiness, Check, ChevronDown, PanelLeftClose, PanelLeftOpen, CircleHelp, Code2, FolderKanban, Home, Menu, MessageCircle, Moon, Plus, Search, Settings2, Sparkles, Sun, X } from "lucide-react";
import { Button } from "@/components/ui/button";
import { Input } from "@/components/ui/input";
import { Dialog, DialogContent, DialogDescription, DialogHeader, DialogTitle } from "@/components/ui/dialog";
import { DropdownMenu, DropdownMenuContent, DropdownMenuItem, DropdownMenuTrigger } from "@/components/ui/dropdown-menu";
import { Sidebar, SidebarFooter, SidebarHeader, SidebarItem, SidebarNav, SidebarSection } from "@/components/ui/sidebar";
import { useCareer } from "@/lib/career-store";
import { openCareerCoach } from "@/components/career/coach-events";

const links = [
 {href:"/",label:"Today",icon:Home,group:"Workspace"},
 {href:"/learn",label:"Learn",icon:BookOpen,group:"Workspace"},
 {href:"/practice",label:"Practice",icon:Code2,group:"Workspace"},
 {href:"/jobs",label:"Jobs",icon:BriefcaseBusiness,group:"Your next role"},
 {href:"/portfolio",label:"Portfolio & profile",icon:FolderKanban,group:"Your next role"},
 {href:"/interviews",label:"Interview room",icon:MessageCircle,group:"Your next role"},
 {href:"/coach",label:"Career coach",icon:Sparkles,group:"Support"},
 {href:"/settings",label:"Settings",icon:Settings2,group:"Support"},
];

function subscribeHydration(){return()=>{}}
function subscribeViewport(callback:()=>void){const query=window.matchMedia("(max-width: 760px)");query.addEventListener("change",callback);return()=>query.removeEventListener("change",callback)}
function mobileSnapshot(){return window.matchMedia("(max-width: 760px)").matches}
const sidebarStorageKey="career-helper.sidebar.v1";
function subscribeSidebar(callback:()=>void){window.addEventListener("storage",callback);window.addEventListener("career-sidebar-change",callback);return()=>{window.removeEventListener("storage",callback);window.removeEventListener("career-sidebar-change",callback)}}
function sidebarSnapshot(){return window.localStorage.getItem(sidebarStorageKey)==="collapsed"}

export function CareerShell({children}:{children:React.ReactNode}) {
 const mounted=useSyncExternalStore(subscribeHydration,()=>true,()=>false);
 const isMobile=useSyncExternalStore(subscribeViewport,mobileSnapshot,()=>false);const closeRef=useRef<HTMLButtonElement>(null),menuRef=useRef<HTMLButtonElement>(null),wasOpen=useRef(false);
 const pathname = usePathname(), router = useRouter();
 const {profile,jobs,projects,ready} = useCareer();
 const collapsed=useSyncExternalStore(subscribeSidebar,sidebarSnapshot,()=>false);
 function toggleSidebar(){window.localStorage.setItem(sidebarStorageKey,collapsed?"expanded":"collapsed");window.dispatchEvent(new Event("career-sidebar-change"))}
 const [mobile,setMobile]=useState(false),[search,setSearch]=useState(false),[query,setQuery]=useState("");
 const {resolvedTheme,setTheme}=useTheme();const dark=mounted&&resolvedTheme==="dark";
 useEffect(()=>{const onKey=(event:KeyboardEvent)=>{if((event.metaKey||event.ctrlKey)&&event.key==="k"){event.preventDefault();setSearch(value=>!value)}if(event.key==="Escape")setMobile(false)};window.addEventListener("keydown",onKey);return()=>window.removeEventListener("keydown",onKey)},[]);
 useEffect(()=>{if(mobile&&isMobile){wasOpen.current=true;closeRef.current?.focus()}else if(wasOpen.current){wasOpen.current=false;menuRef.current?.focus()}},[mobile,isMobile]);
 function toggleTheme(){setTheme(dark?"light":"dark")}
 const results=useMemo(()=>{
   const value=query.toLowerCase().trim();
   const pages=links.filter(item=>!value||item.label.toLowerCase().includes(value)).map(item=>({label:item.label,detail:"Open page",href:item.href}));
   if(!value)return pages;
   return [...pages,...jobs.filter(job=>`${job.title} ${job.company}`.toLowerCase().includes(value)).slice(0,5).map(job=>({label:job.title,detail:job.company,href:`/jobs?job=${job.id}`})),...projects.filter(project=>project.name.toLowerCase().includes(value)).map(project=>({label:project.name,detail:"Portfolio project",href:`/portfolio?project=${project.id}`}))];
 },[query,jobs,projects]);
 useEffect(()=>{if(ready&&!profile.onboardingComplete&&pathname!=="/onboarding")router.replace("/onboarding")},[ready,profile.onboardingComplete,pathname,router]);
 const current=links.find(link=>link.href===pathname)?.label ?? (pathname==="/onboarding"?"Your setup":"Workspace");
 const firstName=profile?.name?.split(" ")[0]||"";
 return <div className={`app-shell ${collapsed?"sidebar-collapsed":""} ${mobile?"mobile-sidebar-open":""}`}>
   <a className="skip-link" href="#main-content">Skip to content</a>
   {mobile&&<button tabIndex={-1} className="sidebar-scrim" aria-label="Close navigation" onClick={()=>setMobile(false)}/>}
   <Sidebar collapsed={collapsed} className="app-sidebar" aria-label="Main navigation" inert={isMobile&&!mobile} role={isMobile&&mobile?"dialog":undefined} aria-modal={isMobile&&mobile?true:undefined} onKeyDown={event=>{if(!isMobile||!mobile||event.key!=="Tab")return;const controls=Array.from(event.currentTarget.querySelectorAll<HTMLElement>("a[href],button:not([disabled]),input:not([disabled])")).filter(item=>item.offsetParent!==null);const first=controls[0],last=controls[controls.length-1];if(event.shiftKey&&document.activeElement===first){event.preventDefault();last?.focus()}else if(!event.shiftKey&&document.activeElement===last){event.preventDefault();first?.focus()}}}>
    <SidebarHeader className="sidebar-brand"><Link href="/" onClick={()=>setMobile(false)} aria-label="Taavod home"><span className="brand-symbol"><Image src="/brand/taavod-mark.png" alt="" width={44} height={44} unoptimized priority/></span><span className="brand-word">Taavod</span></Link><Button variant="ghost" size="icon" className="desktop-sidebar-toggle" aria-label={collapsed?"Expand sidebar":"Collapse sidebar"} aria-expanded={!collapsed} aria-controls="career-navigation" onClick={toggleSidebar}>{collapsed?<PanelLeftOpen size={19}/>:<PanelLeftClose size={19}/>}</Button><Button variant="ghost" size="icon" ref={closeRef} className="mobile-close" aria-label="Close navigation" onClick={()=>setMobile(false)}><X size={19}/></Button></SidebarHeader>
    <Button variant="ghost" className="sidebar-search" onClick={()=>setSearch(true)} title={collapsed?"Search workspace (⌘ K)":undefined}><Search size={18}/><span>Search</span><kbd>⌘ K</kbd></Button>
    <Button asChild variant="ghost" className="sidebar-new-chat" title={collapsed?"New coach conversation":undefined}><Link href="/coach" onClick={event=>{setMobile(false);if(!event.metaKey&&!event.ctrlKey&&!event.shiftKey&&!event.altKey)openCareerCoach({expanded:true,newConversation:true})}}><Plus size={18}/><span>New conversation</span></Link></Button>
    <SidebarNav id="career-navigation" className="sidebar-nav">{Array.from(new Set(links.map(link=>link.group))).map(group=><SidebarSection key={group} label={group}>{links.filter(link=>link.group===group).map(link=><SidebarItem key={link.href} href={link.href} label={link.label} active={pathname===link.href} icon={<link.icon size={19} strokeWidth={1.7}/>} onClick={()=>setMobile(false)}/>)}</SidebarSection>)}</SidebarNav>
    <SidebarFooter className="sidebar-bottom"><Link href="/settings#profile" className="sidebar-account" onClick={()=>setMobile(false)} title={collapsed?profile.name||"Your profile":undefined}><span className="avatar small">{firstName.charAt(0)||"C"}</span><span className="account-name"><strong>{profile?.name||"Your profile"}</strong><small>{ready?"Personal workspace":"Loading…"}</small></span><ChevronDown size={15} className="account-chevron"/></Link></SidebarFooter>
   </Sidebar>
   <div className="workspace-main" inert={isMobile&&mobile}><header className="workspace-topbar"><div className="topbar-location"><Button variant="ghost" size="icon" ref={menuRef} className="mobile-menu" aria-label="Open navigation" onClick={()=>setMobile(true)}><Menu size={20}/></Button><strong>{current}</strong></div><div className="topbar-actions"><span className="private-label"><span/>Personal workspace</span><Button variant="ghost" size="icon" aria-label={dark?"Use light theme":"Use dark theme"} onClick={toggleTheme}>{dark?<Sun size={17}/>:<Moon size={17}/>}</Button><DropdownMenu><DropdownMenuTrigger asChild><Button className="quick-add" size="sm"><Plus size={16}/><span>Quick add</span><ChevronDown size={13}/></Button></DropdownMenuTrigger><DropdownMenuContent align="end"><DropdownMenuItem asChild><Link href="/jobs?add=true"><BriefcaseBusiness size={15}/>Add a job</Link></DropdownMenuItem><DropdownMenuItem asChild><Link href="/?addTask=true"><Check size={15}/>Add a task</Link></DropdownMenuItem><DropdownMenuItem asChild><Link href="/settings#profile"><BookOpen size={15}/>Profile notes</Link></DropdownMenuItem></DropdownMenuContent></DropdownMenu></div></header>
   <main id="main-content" className={`workspace-content ${pathname==="/coach"?"coach-content":""}`}>{children}</main>
   <footer className="workspace-footer"><span>Taavod · Your next move</span><Link href="/onboarding"><CircleHelp size={13}/>Review your setup<ArrowUpRight size={12}/></Link></footer>
   </div>
   <Dialog open={search} onOpenChange={setSearch}><DialogContent className="search-dialog"><DialogHeader><DialogTitle>Search your workspace</DialogTitle><DialogDescription>Find a page, job, or portfolio project.</DialogDescription></DialogHeader><Input autoFocus aria-label="Search workspace" placeholder="What are you looking for?" value={query} onChange={event=>setQuery(event.target.value)}/><div className="search-results">{results.length?results.map((result,index)=><Link key={`${result.href}-${index}`} href={result.href} onClick={()=>{setSearch(false);setQuery("")}}><Search size={16}/><span><strong>{result.label}</strong><small>{result.detail}</small></span><ArrowUpRight size={14}/></Link>):<p>No results. Try a role, company, or page name.</p>}</div></DialogContent></Dialog>
 </div>;
}
