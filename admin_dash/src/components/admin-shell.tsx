"use client";

import Link from "next/link";
import { usePathname } from "next/navigation";
import { ReactNode } from "react";
import { useDemo } from "./demo-provider";
import { EasterEggDetector } from "./easter-egg-detector";

type NavItem = {
  label: string;
  href: string;
  icon: string;
};

const NAV_ICONS: Record<string, string> = {
  Dashboard:
    "M3 12l2-2m0 0l7-7 7 7M5 10v10a1 1 0 001 1h3m10-11l2 2m-2-2v10a1 1 0 01-1 1h-3m-6 0a1 1 0 001-1v-4a1 1 0 011-1h2a1 1 0 011 1v4a1 1 0 001 1m-6 0h6",
  "Claims Queue":
    "M9 5H7a2 2 0 00-2 2v12a2 2 0 002 2h10a2 2 0 002-2V7a2 2 0 00-2-2h-2M9 5a2 2 0 002 2h2a2 2 0 002-2M9 5a2 2 0 012-2h2a2 2 0 012 2m-6 9l2 2 4-4",
  Analytics:
    "M9 19v-6a2 2 0 00-2-2H5a2 2 0 00-2 2v6a2 2 0 002 2h2a2 2 0 002-2zm0 0V9a2 2 0 012-2h2a2 2 0 012 2v10m-6 0a2 2 0 002 2h2a2 2 0 002-2m0 0V5a2 2 0 012-2h2a2 2 0 012 2v14a2 2 0 01-2 2h-2a2 2 0 01-2-2z",
  "Driver Profiles":
    "M17 20h5v-2a3 3 0 00-5.356-1.857M17 20H7m10 0v-2c0-.656-.126-1.283-.356-1.857M7 20H2v-2a3 3 0 015.356-1.857M7 20v-2c0-.656.126-1.283.356-1.857m0 0a5.002 5.002 0 019.288 0M15 7a3 3 0 11-6 0 3 3 0 016 0z",
};

const navItems: NavItem[] = [
  { label: "Dashboard", href: "/", icon: NAV_ICONS["Dashboard"] },
  { label: "Claims Queue", href: "/claims", icon: NAV_ICONS["Claims Queue"] },
  { label: "Analytics", href: "/analytics", icon: NAV_ICONS["Analytics"] },
  { label: "Driver Profiles", href: "/drivers", icon: NAV_ICONS["Driver Profiles"] },
];

type AdminShellProps = {
  title: string;
  subtitle: string;
  children: ReactNode;
};

export function AdminShell({ title, subtitle, children }: AdminShellProps) {
  const pathname = usePathname();
  const { seedDemoNotifications, resetAll, killSwitchTrip, notifications } = useDemo();

  return (
    <div className="min-h-screen bg-slate-50 text-slate-900">
      <div className="mx-auto flex min-h-screen max-w-7xl gap-6 p-6">
        {/* Sidebar */}
        <aside className="w-60 shrink-0 rounded-2xl bg-teal-900 p-5 text-teal-50 flex flex-col">
          <div>
            {/* Logo + tagline */}
            <div className="mb-6">
              <h1 className="text-lg font-bold tracking-tight">Continuum</h1>
              <p className="mt-0.5 text-xs text-teal-400">Operations Control</p>
            </div>

            {/* Nav */}
            <nav className="space-y-1 text-sm">
              {navItems.map((item) => {
                const isActive = pathname === item.href;
                return (
                  <Link
                    key={item.href}
                    href={item.href}
                    className={`flex items-center gap-3 rounded-lg px-3 py-2.5 transition-colors ${
                      isActive
                        ? "border-l-2 border-teal-300 bg-teal-800 pl-[10px] font-medium text-white"
                        : "text-teal-200 hover:bg-teal-800 hover:text-white"
                    }`}
                  >
                    <svg
                      xmlns="http://www.w3.org/2000/svg"
                      width="16"
                      height="16"
                      viewBox="0 0 24 24"
                      fill="none"
                      stroke="currentColor"
                      strokeWidth="2"
                      strokeLinecap="round"
                      strokeLinejoin="round"
                      className="shrink-0 opacity-80"
                    >
                      <path d={item.icon} />
                    </svg>
                    {item.label}
                  </Link>
                );
              })}
            </nav>
          </div>

          {/* Footer */}
          <div className="mt-auto pt-6 border-t border-teal-800">
            <EasterEggDetector taps={5} windowMs={2000} onTrigger={resetAll}>
              <div className="flex items-center gap-2 cursor-pointer select-none">
                <span className="text-xs text-teal-500">v4.0.0</span>
                <span className="rounded bg-teal-700 px-1.5 py-0.5 text-[10px] font-semibold uppercase tracking-wider text-teal-200">
                  DEMO
                </span>
              </div>
            </EasterEggDetector>
          </div>
        </aside>

        {/* Main content */}
        <main className="flex-1 flex flex-col space-y-6 min-w-0">
          <header className="rounded-2xl bg-white p-5 shadow-sm ring-1 ring-slate-100 flex justify-between items-center">
            <div>
              <h2 className="text-xl font-semibold text-slate-900">{title}</h2>
              <p className="mt-0.5 text-sm text-slate-500">{subtitle}</p>
            </div>

            <div className="flex items-center gap-4">
              {/* Notification bell — 3-tap seeds demo notifications */}
              <EasterEggDetector taps={3} windowMs={1500} onTrigger={seedDemoNotifications}>
                <div className="relative cursor-pointer rounded-full p-2 text-slate-500 hover:bg-slate-100 transition-colors">
                  <svg
                    xmlns="http://www.w3.org/2000/svg"
                    width="20"
                    height="20"
                    viewBox="0 0 24 24"
                    fill="none"
                    stroke="currentColor"
                    strokeWidth="2"
                    strokeLinecap="round"
                    strokeLinejoin="round"
                  >
                    <path d="M6 8a6 6 0 0 1 12 0c0 7 3 9 3 9H3s3-2 3-9" />
                    <path d="M10.3 21a1.94 1.94 0 0 0 3.4 0" />
                  </svg>
                  {notifications.length > 0 && (
                    <span className="absolute top-1.5 right-1.5 flex h-3.5 w-3.5 items-center justify-center rounded-full bg-red-500 text-[8px] font-bold text-white">
                      {notifications.length}
                    </span>
                  )}
                </div>
              </EasterEggDetector>

              {/* User identity — 5-tap kills switch */}
              <div className="flex items-center gap-2.5">
                <div className="text-right">
                  <EasterEggDetector taps={5} windowMs={2000} onTrigger={killSwitchTrip}>
                    <p className="text-sm font-medium text-slate-800 cursor-pointer select-none leading-tight">
                      Preethi Nair
                    </p>
                  </EasterEggDetector>
                  <p className="text-xs text-slate-400">Claims Reviewer</p>
                </div>
                <div className="h-9 w-9 rounded-full bg-teal-100 flex items-center justify-center text-teal-700 text-sm font-bold ring-2 ring-teal-200">
                  PN
                </div>
              </div>
            </div>
          </header>

          {children}
        </main>
      </div>
    </div>
  );
}
