"use client";

import Link from "next/link";
import { usePathname } from "next/navigation";
import { ReactNode } from "react";

type NavItem = {
  label: string;
  href: string;
};

const navItems: NavItem[] = [
  { label: "Dashboard", href: "/" },
  { label: "Claims", href: "/claims" },
  { label: "Payouts", href: "/payouts" },
  { label: "Fraud Review", href: "/fraud-review" },
  { label: "Zone Controls", href: "/zone-controls" },
];

type AdminShellProps = {
  title: string;
  subtitle: string;
  children: ReactNode;
};

export function AdminShell({ title, subtitle, children }: AdminShellProps) {
  const pathname = usePathname();

  return (
    <div className="min-h-screen bg-teal-50 text-teal-950">
      <div className="mx-auto flex min-h-screen max-w-7xl gap-6 p-6">
        <aside className="w-64 rounded-2xl bg-teal-900 p-6 text-teal-50">
          <h1 className="text-xl font-bold">Continuum Admin</h1>
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
        </aside>

        <main className="flex-1 space-y-6">
          <header className="rounded-2xl bg-white p-6 shadow-sm ring-1 ring-teal-100">
            <h2 className="text-2xl font-semibold text-teal-950">{title}</h2>
            <p className="mt-1 text-sm text-teal-700">{subtitle}</p>
          </header>
          {children}
        </main>
      </div>
    </div>
  );
}
