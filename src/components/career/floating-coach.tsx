"use client";

import { useEffect, useRef, useState } from "react";
import Image from "next/image";
import { Maximize2, Minimize2, X } from "lucide-react";
import { Button } from "@/components/ui/button";
import { Dialog, DialogContent, DialogDescription, DialogTitle, DialogTrigger } from "@/components/ui/dialog";
import { CoachChat, useCoachSession } from "@/components/career/coach-chat";
import { coachOpenEvent, type CoachOpenRequest } from "@/components/career/coach-events";

export function FloatingCoach() {
  const session = useCoachSession();
  const [open, setOpen] = useState(false);
  const [expanded, setExpanded] = useState(false);
  const trigger = useRef<HTMLButtonElement>(null);
  const close = useRef<HTMLButtonElement>(null);

  useEffect(() => {
    function receive(event: Event) {
      const request = (event as CustomEvent<CoachOpenRequest>).detail;
      setExpanded(request?.expanded === true);
      setOpen(true);
    }
    window.addEventListener(coachOpenEvent, receive);
    return () => window.removeEventListener(coachOpenEvent, receive);
  }, []);

  return <Dialog modal={false} open={open} onOpenChange={setOpen}>
    <DialogTrigger asChild>
      <Button ref={trigger} className={`floating-coach-launcher ${open ? "coach-is-open" : ""}`} disabled={!session.ready} aria-label={open ? "Close career coach" : "Open career coach"} title="Your career coach" onClick={() => { if (!open) setExpanded(false); }}>
        <Image src="/companion/hen-fade-neutral.png" width={43} height={48} alt="" />
        <span>Ask your coach</span>
      </Button>
    </DialogTrigger>
    <DialogContent centered={false} showOverlay={false} showCloseButton={false} className={`floating-coach-panel ${expanded ? "coach-window-expanded" : "coach-window-compact"}`} onOpenAutoFocus={event => { event.preventDefault(); close.current?.focus(); }} onCloseAutoFocus={event => { event.preventDefault(); trigger.current?.focus(); }} onInteractOutside={event => event.preventDefault()} onClickCapture={event => { const target = event.target instanceof Element ? event.target.closest("a[href]") : null; if (target?.getAttribute("href")?.startsWith("/settings")) setOpen(false); }}>
      <div className="floating-coach-chrome">
        <div><DialogTitle>Career coach</DialogTitle><DialogDescription className="sr-only">Your conversation stays open when you resize or browse your workspace.</DialogDescription></div>
        <div className="coach-window-controls">
          <Button variant="ghost" size="icon" aria-label={expanded ? "Minimize coach window" : "Expand coach window"} onClick={() => setExpanded(value => !value)}>{expanded ? <Minimize2 size={16} /> : <Maximize2 size={16} />}</Button>
          <Button ref={close} variant="ghost" size="icon" aria-label="Close coach window" onClick={() => setOpen(false)}><X size={18} /></Button>
        </div>
      </div>
      <CoachChat session={session} />
    </DialogContent>
  </Dialog>;
}
