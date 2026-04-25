"use client";

import { useDemo } from "./demo-provider";

export function DemoBanner() {
  const { banner } = useDemo();

  if (!banner.active) return null;

  const bgColors = {
    red: "bg-red-600",
    amber: "bg-amber-500",
    orange: "bg-orange-500",
  };

  return (
    <div className={`w-full text-white text-center py-2 px-4 font-medium text-sm shadow-md ${bgColors[banner.type]}`}>
      {banner.message}
    </div>
  );
}
