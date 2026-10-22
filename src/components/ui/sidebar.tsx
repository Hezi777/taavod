"use client";

import * as React from "react";
import Link from "next/link";

type SidebarContextValue = { collapsed: boolean };
const SidebarContext = React.createContext<SidebarContextValue | null>(null);

function useSidebarContext() {
  const value = React.useContext(SidebarContext);
  if (!value) throw new Error("Sidebar parts must be rendered inside Sidebar.");
  return value;
}

type SidebarProps = React.ComponentPropsWithoutRef<"aside"> & {
  collapsed: boolean;
};

export function Sidebar({ collapsed, children, ...props }: SidebarProps) {
  return (
    <SidebarContext.Provider value={{ collapsed }}>
      <aside data-slot="sidebar" data-collapsed={collapsed} {...props}>
        {children}
      </aside>
    </SidebarContext.Provider>
  );
}

export function SidebarHeader(props: React.ComponentPropsWithoutRef<"div">) {
  useSidebarContext();
  return <div data-slot="sidebar-header" {...props} />;
}

export function SidebarNav(props: React.ComponentPropsWithoutRef<"nav">) {
  useSidebarContext();
  return <nav data-slot="sidebar-nav" {...props} />;
}

export function SidebarSection({
  label,
  children,
  ...props
}: React.ComponentPropsWithoutRef<"div"> & { label: string }) {
  useSidebarContext();
  return (
    <div data-slot="sidebar-section" role="group" aria-label={label} {...props}>
      <p className="nav-group">{label}</p>
      {children}
    </div>
  );
}

export function SidebarItem({
  href,
  label,
  active,
  icon,
  onClick,
}: {
  href: string;
  label: string;
  active: boolean;
  icon: React.ReactNode;
  onClick?: React.MouseEventHandler<HTMLAnchorElement>;
}) {
  const { collapsed } = useSidebarContext();
  return (
    <Link
      aria-current={active ? "page" : undefined}
      aria-label={label}
      className={`nav-link ${active ? "active" : ""}`}
      data-slot="sidebar-item"
      href={href}
      onClick={onClick}
      title={collapsed ? label : undefined}
    >
      {icon}
      <span>{label}</span>
    </Link>
  );
}

export function SidebarFooter(props: React.ComponentPropsWithoutRef<"div">) {
  useSidebarContext();
  return <div data-slot="sidebar-footer" {...props} />;
}
