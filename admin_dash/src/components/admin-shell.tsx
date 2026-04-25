"use client";

import Link from "next/link";
import { usePathname } from "next/navigation";
import { ReactNode } from "react";
import { useDemo } from "./demo-provider";
import { EasterEggDetector } from "./easter-egg-detector";

type NavItem = {
  label: string;
  href: string;
};

const navItems: NavItem[] = [
  { label: "Dashboard", href: "/" },
  { label: "Claims Queue", href: "/claims" },
  { label: "Analytics", href: "/analytics" },
  { label: "Driver Profiles", href: "/drivers" },
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
    <div className="min-h-screen bg-teal-50 text-teal-950">
      <div className="mx-auto flex min-h-screen max-w-7xl gap-6 p-6">
        <aside className="w-64 rounded-2xl bg-teal-900 p-6 text-teal-50 flex flex-col">
          <div>
            <EasterEggDetector taps={1} windowMs={1000} onTrigger={() => {
              // We could implement long press by listening to mouse down/up, 
              // but for simplicity in web, we will map 5 taps to resetAll.
            }}>
              <h1 className="text-xl font-bold cursor-pointer select-none">Continuum Admin</h1>
            </EasterEggDetector>
            <p className="mt-1 text-sm text-teal-200">Operations Control Panel</p>
            <nav className="mt-8 space-y-2 text-sm">
              {navItems.map((item) => {
                const isActive = pathname === item.href;
                return (
                  <Link
                    key={item.href}
                    href={item.href}
                    className={`block rounded-lg px-3 py-2 ${
                      isActive
                        ? "bg-teal-700 font-medium text-white"
                        : "text-teal-100 hover:bg-teal-800"
                    }`}
                  >
                    {item.label}
                  </Link>
                );
              })}
            </nav>
          </div>
          <div className="mt-auto pt-8">
            <EasterEggDetector taps={5} windowMs={2000} onTrigger={resetAll}>
              <div className="text-xs text-teal-400 opacity-50 cursor-pointer select-none">v4.0.0-demo</div>
            </EasterEggDetector>
          </div>
        </aside>

        <main className="flex-1 flex flex-col space-y-6">
          <header className="rounded-2xl bg-white p-6 shadow-sm ring-1 ring-teal-100 flex justify-between items-start">
            <div>
              <h2 className="text-2xl font-semibold text-teal-950">{title}</h2>
              <p className="mt-1 text-sm text-teal-700">{subtitle}</p>
            </div>
            
            <div className="flex items-center gap-6">
              <EasterEggDetector taps={3} windowMs={1500} onTrigger={seedDemoNotifications}>
                <div className="relative cursor-pointer hover:bg-teal-50 p-2 rounded-full transition-colors">
                  <svg xmlns="http://www.w3.org/2000/svg" width="24" height="24" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round" className="text-teal-700"><path d="M6 8a6 6 0 0 1 12 0c0 7 3 9 3 9H3s3-2 3-9"/><path d="M10.3 21a1.94 1.94 0 0 0 3.4 0"/></svg>
                  {notifications.length > 0 && (
                    <span className="absolute top-1 right-1 flex h-4 w-4 items-center justify-center rounded-full bg-red-500 text-[9px] font-bold text-white">
                      {notifications.length}
                    </span>
                  )}
                </div>
              </EasterEggDetector>
              
              <div className="flex items-center gap-3">
                <div className="text-right">
                  <EasterEggDetector taps={5} windowMs={2000} onTrigger={killSwitchTrip}>
                    <p className="text-sm font-semibold text-teal-900 cursor-pointer select-none">Preethi Nair</p>
                  </EasterEggDetector>
                  <p className="text-xs text-teal-600">Claims Reviewer</p>
                </div>
                <div className="h-10 w-10 rounded-full bg-teal-200 flex items-center justify-center text-teal-800 font-bold">
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
