import type {Metadata} from 'next';
import {ThemeProvider} from 'next-themes';
import {TooltipProvider} from '@/components/ui/tooltip';
import {Toaster} from '@/components/ui/sonner';
import {CareerProvider} from '@/lib/career-store';
import './globals.css';
import './career-design.css';
export const metadata:Metadata={title:{default:'Taavod — Your next move',template:'%s · Taavod'},description:'Learn, practice, and prepare for your next BI role.',icons:{icon:'/brand/taavod-mark.png',apple:'/brand/taavod-mark.png'},robots:{index:false,follow:false}};
export default function RootLayout({children}:{children:React.ReactNode}){return <html lang="en" suppressHydrationWarning><body><ThemeProvider attribute="class" defaultTheme="light" enableSystem><TooltipProvider><CareerProvider>{children}</CareerProvider><Toaster richColors position="bottom-right"/></TooltipProvider></ThemeProvider></body></html>;}
