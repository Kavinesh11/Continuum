"use client";

import Link from "next/link";
import { usePathname } from "next/navigation";
import { ReactNode, useState, useRef, useEffect } from "react";
import { createPortal } from "react-dom";
import { useDemo } from "./demo-provider";
import { EasterEggDetector } from "./easter-egg-detector";
import { Avatar, AvatarFallback } from "@/components/ui/avatar";
import { Badge } from "@/components/ui/badge";
import { Separator } from "@/components/ui/separator";
import { personas, PersonaKey } from "@/lib/demo-data";
import {
  LayoutDashboard,
  BarChart3,
  Server,
  ClipboardList,
  TrendingUp,
  Users,
  ShieldCheck,
  Bell,
  RefreshCw,
  ChevronDown,
} from "lucide-react";
import { cn } from "@/lib/utils";

// ── Per-persona nav config ────────────────────────────────────────────────────

const allNavItems = [
  { label: "Dashboard", href: "/", icon: LayoutDashboard },
  { label: "Executive View", href: "/executive", icon: TrendingUp },
  { label: "Operations", href: "/operations", icon: Server },
  { label: "Claims Queue", href: "/claims", icon: ClipboardList },
  { label: "Analytics", href: "/analytics", icon: BarChart3 },
  { label: "Driver Profiles", href: "/drivers", icon: Users },
  { label: "Risk Intelligence", href: "/risk-intelligence", icon: ShieldCheck },
];

const personaNavHrefs: Record<PersonaKey, string[]> = {
  executive: ["/", "/executive", "/analytics", "/risk-intelligence"],
  ops: ["/", "/operations", "/risk-intelligence"],
  adjuster: ["/claims", "/drivers", "/analytics", "/risk-intelligence"],
};

// Easter egg targets (one per persona)
const personaEasterEgg: Record<PersonaKey, string> = {
  executive: "/claims", // hidden: Claims Queue has the sudarshanRoadblock long-press
  ops: "/claims",
  adjuster: "/claims",
};

type AdminShellProps = {
  title: string;
  subtitle: string;
  children: ReactNode;
  badge?: string;
};

export function AdminShell({
  title,
  subtitle,
  children,
  badge,
}: AdminShellProps) {
  const pathname = usePathname();
  const {
    activePersona,
    setPersona,
    seedDemoNotifications,
    resetAll,
    killSwitchTrip,
    sudarshanRoadblock,
    notifications,
  } = useDemo();
  const persona = personas[activePersona];

  const [personaMenuOpen, setPersonaMenuOpen] = useState(false);
  const menuRef = useRef<HTMLDivElement>(null);
  const dropdownRef = useRef<HTMLDivElement>(null);
  const buttonRef = useRef<HTMLButtonElement>(null);
  const [buttonRect, setButtonRect] = useState<DOMRect | null>(null);

  // Update button position when menu opens
  useEffect(() => {
    if (personaMenuOpen && buttonRef.current) {
      setButtonRect(buttonRef.current.getBoundingClientRect());
    }
  }, [personaMenuOpen]);

  // Close dropdown on outside click
  useEffect(() => {
    function onClickOutside(e: MouseEvent) {
      if (
        menuRef.current &&
        !menuRef.current.contains(e.target as Node) &&
        dropdownRef.current &&
        !dropdownRef.current.contains(e.target as Node)
      ) {
        setPersonaMenuOpen(false);
      }
    }
    document.addEventListener("mousedown", onClickOutside);
    return () => document.removeEventListener("mousedown", onClickOutside);
  }, []);

  const navItems = allNavItems.filter((item) =>
    personaNavHrefs[activePersona].includes(item.href),
  );

  return (
    <div className="min-h-screen flex bg-background">
      {/* ── Sidebar ────────────────────────────────────────────────────── */}
      <aside className="w-56 shrink-0 flex flex-col border-r border-border/50 relative overflow-hidden sticky top-0 h-screen">
        {/* Background gradient */}
        <div className="absolute inset-0 bg-gradient-to-b from-[#0F172A] via-[#111827] to-[#0F172A]" />
        <div
          className="absolute inset-0 opacity-[0.03]"
          style={{
            backgroundImage:
              "linear-gradient(rgba(0,191,166,0.5) 1px, transparent 1px), linear-gradient(90deg, rgba(0,191,166,0.5) 1px, transparent 1px)",
            backgroundSize: "32px 32px",
          }}
        />
        <div className="absolute top-0 left-0 right-0 h-px bg-gradient-to-r from-transparent via-[#00BFA6]/30 to-transparent" />

        <div className="relative flex flex-col h-full p-4">
          {/* Logo */}
          <div className="mb-5">
            <div className="flex items-center gap-2.5">
              <div
                className="w-7 h-7 rounded-lg flex items-center justify-center glow-pulse shrink-0"
                style={{
                  background: "linear-gradient(135deg, #008A8A, #00BFA6)",
                }}
              >
                <ShieldCheck className="w-4 h-4 text-white" strokeWidth={2.5} />
              </div>
              <div>
                <p className="text-sm font-bold text-white tracking-tight leading-none">
                  Continuum
                </p>
                <p
                  className="text-[9px] mt-0.5 font-medium tracking-wider"
                  style={{ color: "#00BFA6" }}
                >
                  OPERATIONS CONTROL
                </p>
              </div>
            </div>
          </div>

          {/* ── Active user display ────────────────────────────────────── */}
          {/*<div className="mb-5 p-3 rounded-xl" style={{
            background: "rgba(255,255,255,0.03)",
            border: "1px solid rgba(255,255,255,0.06)",
          }}>
            <p className="text-[9px] uppercase tracking-widest mb-2 px-0.5" style={{ color: "#334155" }}>
              Signed In As
            </p>
            <div className="flex items-center gap-2.5">
              <Avatar className="h-8 w-8 shrink-0">
                <AvatarFallback className="text-[11px] font-bold" style={{ background: `${persona.color}25`, color: persona.color }}>
                  {persona.initials}
                </AvatarFallback>
              </Avatar>
              <div className="min-w-0">
                <p className="text-xs font-semibold text-white truncate leading-none">{persona.name}</p>
                <p className="text-[9px] mt-0.5 truncate" style={{ color: "#475569" }}>{persona.role}</p>
              </div>
            </div>
          </div>*/}

          <Separator className="mb-4 opacity-20" />

          {/* ── Nav ──────────────────────────────────────────────────── */}
          <nav className="flex flex-col gap-0.5 flex-1">
            {navItems.map((item) => {
              const Icon = item.icon;
              const isActive = pathname === item.href;
              if (item.href === "/claims") {
                return (
                  <EasterEggDetector
                    key={item.href}
                    taps={99}
                    onLongPress={sudarshanRoadblock}
                    longPressMs={600}
                  >
                    <NavLink item={item} Icon={Icon} isActive={isActive} />
                  </EasterEggDetector>
                );
              }
              return (
                <NavLink
                  key={item.href}
                  item={item}
                  Icon={Icon}
                  isActive={isActive}
                />
              );
            })}
          </nav>

          {/* ── Footer ───────────────────────────────────────────────── */}
          <div className="pt-3 border-t border-white/5">
            <EasterEggDetector taps={5} windowMs={2000} onTrigger={resetAll}>
              <div className="flex items-center gap-2 px-1 cursor-pointer select-none">
                <RefreshCw className="w-3 h-3 text-[#334155]" />
                <span className="text-[10px] text-[#334155]">v4.0.0</span>
                <Badge
                  variant="outline"
                  className="text-[9px] h-4 px-1.5 border-[#334155] text-[#008A8A]"
                >
                  DEMO
                </Badge>
              </div>
            </EasterEggDetector>
          </div>
        </div>
      </aside>

      {/* ── Main area ────────────────────────────────────────────────── */}
      <div className="flex-1 flex flex-col min-w-0">
        {/* Top bar */}
        <header
          className="h-14 flex items-center justify-between px-6 border-b border-border/50 shrink-0 sticky top-0 z-40"
          style={{
            background: "rgba(15,23,42,0.9)",
            backdropFilter: "blur(12px)",
          }}
        >
          <div className="flex items-center gap-3">
            <div>
              <div className="flex items-center gap-2">
                <h2 className="text-sm font-semibold text-foreground">
                  {title}
                </h2>
                {badge && (
                  <Badge className="text-[9px] h-4 px-1.5 bg-[#008A8A]/20 text-[#00BFA6] border-[#008A8A]/30 hover:bg-[#008A8A]/20">
                    {badge}
                  </Badge>
                )}
              </div>
              <p className="text-xs text-muted-foreground">{subtitle}</p>
            </div>
          </div>

          <div className="flex items-center gap-4">
            {/* Live indicator */}
            <div className="flex items-center gap-1.5 text-xs text-muted-foreground">
              <span className="live-dot w-1.5 h-1.5 rounded-full bg-[#22C55E]" />
              <span>Live</span>
            </div>

            {/* Bell */}
            <EasterEggDetector
              taps={3}
              windowMs={1500}
              onTrigger={seedDemoNotifications}
            >
              <button className="relative p-2 rounded-lg text-muted-foreground hover:text-foreground hover:bg-white/5 transition-colors">
                <Bell className="w-4 h-4" />
                {notifications.length > 0 && (
                  <span className="absolute top-1 right-1 w-3.5 h-3.5 flex items-center justify-center rounded-full bg-red-500 text-[8px] font-bold text-white">
                    {notifications.length > 9 ? "9+" : notifications.length}
                  </span>
                )}
              </button>
            </EasterEggDetector>

            {/* ── Persona card — click to switch ──────────────────────── */}
            <div ref={menuRef}>
              <button
                ref={buttonRef}
                onClick={() => setPersonaMenuOpen((o) => !o)}
                className="flex items-center gap-2.5 rounded-xl px-3 py-1.5 transition-colors hover:bg-white/5"
                style={{
                  border: personaMenuOpen
                    ? "1px solid rgba(0,191,166,0.3)"
                    : "1px solid transparent",
                }}
              >
                <div className="text-right">
                  <p className="text-xs font-semibold text-foreground leading-none">
                    {persona.name}
                  </p>
                  <p className="text-[10px] text-muted-foreground mt-0.5">
                    {persona.role}
                  </p>
                </div>
                <Avatar className="h-7 w-7">
                  <AvatarFallback
                    className="text-[10px] font-bold"
                    style={{
                      background: `${persona.color}25`,
                      color: persona.color,
                    }}
                  >
                    {persona.initials}
                  </AvatarFallback>
                </Avatar>
                <ChevronDown
                  className={cn(
                    "w-3 h-3 text-muted-foreground transition-transform",
                    personaMenuOpen && "rotate-180",
                  )}
                />
              </button>
            </div>
          </div>
        </header>

        {/* Page content */}
        <main className="flex-1 overflow-auto p-6">{children}</main>
      </div>

      {/* Dropdown Portal */}
      {personaMenuOpen &&
        buttonRect &&
        createPortal(
          <div
            ref={dropdownRef}
            onMouseDown={(e) => e.stopPropagation()}
            className="fixed w-56 rounded-xl shadow-2xl z-[9999] overflow-hidden"
            style={{
              background: "#1E293B",
              border: "1px solid rgba(51,65,85,0.6)",
              backdropFilter: "blur(12px)",
              left: `${buttonRect.right - 224}px`,
              top: `${buttonRect.bottom + 8}px`,
            }}
          >
            <div
              className="px-4 py-2.5 border-b"
              style={{ borderColor: "rgba(51,65,85,0.4)" }}
            >
              <p
                className="text-[9px] uppercase tracking-widest font-semibold"
                style={{ color: "#475569" }}
              >
                Switch Persona
              </p>
            </div>
            {(Object.keys(personas) as PersonaKey[]).map((key) => {
              const p = personas[key];
              const isActive = activePersona === key;
              return (
                <button
                  key={key}
                  onClick={() => {
                    setPersona(key);
                    setPersonaMenuOpen(false);
                  }}
                  onMouseDown={(e) => e.stopPropagation()}
                  className="w-full flex items-center gap-3 px-4 py-3 transition-colors text-left"
                  style={{
                    background: isActive
                      ? "rgba(0,138,138,0.1)"
                      : "transparent",
                    borderBottom: "1px solid rgba(51,65,85,0.3)",
                  }}
                  onMouseEnter={(e) => {
                    if (!isActive)
                      e.currentTarget.style.background =
                        "rgba(255,255,255,0.03)";
                  }}
                  onMouseLeave={(e) => {
                    if (!isActive)
                      e.currentTarget.style.background = "transparent";
                  }}
                >
                  <Avatar className="h-8 w-8 shrink-0">
                    <AvatarFallback
                      className="text-[11px] font-bold"
                      style={{
                        background: `${p.color}25`,
                        color: p.color,
                      }}
                    >
                      {p.initials}
                    </AvatarFallback>
                  </Avatar>
                  <div className="min-w-0">
                    <p className="text-xs font-semibold text-white">{p.name}</p>
                    <p
                      className="text-[10px] truncate"
                      style={{ color: "#64748B" }}
                    >
                      {p.role}
                    </p>
                  </div>
                  {isActive && (
                    <span
                      className="ml-auto w-1.5 h-1.5 rounded-full shrink-0"
                      style={{ background: "#00BFA6" }}
                    />
                  )}
                </button>
              );
            })}
          </div>,
          document.body,
        )}
    </div>
  );
}

function NavLink({
  item,
  Icon,
  isActive,
}: {
  item: { label: string; href: string };
  Icon: React.ElementType;
  isActive: boolean;
}) {
  return (
    <Link
      href={item.href}
      className={cn(
        "flex items-center gap-2.5 px-3 py-2 rounded-lg text-xs font-medium transition-all duration-150 group relative",
        isActive
          ? "bg-[#008A8A]/15 text-white"
          : "text-[#475569] hover:text-[#94A3B8] hover:bg-white/5",
      )}
    >
      {isActive && (
        <span className="absolute left-0 top-1/2 -translate-y-1/2 w-0.5 h-4 rounded-full bg-[#00BFA6]" />
      )}
      <Icon
        className={cn(
          "w-4 h-4 shrink-0",
          isActive ? "text-[#00BFA6]" : "opacity-60 group-hover:opacity-80",
        )}
      />
      <span>{item.label}</span>
    </Link>
  );
}
