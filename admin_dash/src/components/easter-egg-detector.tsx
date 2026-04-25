"use client";

import { ReactNode, useState, useCallback } from "react";

type EasterEggDetectorProps = {
  taps: number;
  windowMs?: number;
  onTrigger: () => void;
  children: ReactNode;
  className?: string;
};

export function EasterEggDetector({
  taps,
  windowMs = 2000,
  onTrigger,
  children,
  className = "",
}: EasterEggDetectorProps) {
  const [, setClickTimestamps] = useState<number[]>([]);

  const handleClick = useCallback(() => {
    const now = Date.now();
    setClickTimestamps((prev) => {
      const validTaps = prev.filter((t) => now - t < windowMs);
      const newTaps = [...validTaps, now];
      if (newTaps.length >= taps) {
        onTrigger();
        return [];
      }
      return newTaps;
    });
  }, [taps, windowMs, onTrigger]);

  return (
    <div onClick={handleClick} className={className} style={{ cursor: "pointer" }}>
      {children}
    </div>
  );
}
