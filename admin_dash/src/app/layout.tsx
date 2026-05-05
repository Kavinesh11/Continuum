import type { Metadata } from "next";
import { Geist, Geist_Mono } from "next/font/google";
import "./globals.css";
import { DemoProvider } from "@/components/demo-provider";
import { DemoBanner } from "@/components/demo-banner";
import { TooltipProvider } from "@/components/ui/tooltip";

const geistSans = Geist({ variable: "--font-geist-sans", subsets: ["latin"] });
const geistMono = Geist_Mono({ variable: "--font-geist-mono", subsets: ["latin"] });

export const metadata: Metadata = {
  title: "Continuum — Operations Control",
  description: "Mission-critical admin console for parametric insurance operations",
};

export default function RootLayout({ children }: { children: React.ReactNode }) {
  return (
    <html lang="en" className={`${geistSans.variable} ${geistMono.variable} dark`}>
      <body className="min-h-screen bg-background text-foreground antialiased">
        <DemoProvider>
          <TooltipProvider>
            <DemoBanner />
            {children}
          </TooltipProvider>
        </DemoProvider>
      </body>
    </html>
  );
}
