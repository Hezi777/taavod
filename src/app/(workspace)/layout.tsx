import { CareerShell } from "@/components/career/shell";
import { FloatingCoach } from "@/components/career/floating-coach";
import "@/app/coach-widget.css";
export default function WorkspaceLayout({children}:{children:React.ReactNode}){return <><CareerShell>{children}</CareerShell><FloatingCoach/></>}
