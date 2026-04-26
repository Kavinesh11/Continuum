"use client";

import { ReactNode, useState, useCallback, useRef } from "react";

type EasterEggDetectorProps = {
  taps: number;
  windowMs?: number;
  onTrigger?: () => void;
  onLongPress?: () => void;
  longPressMs?: number;
  children: ReactNode;
  className?: string;
};

export function EasterEggDetector({
  taps,
  windowMs = 2000,
  onTrigger,
  onLongPress,
  longPressMs = 600,
  children,
  className = "",
}: EasterEggDetectorProps) {
  const [, setClickTimestamps] = useState<number[]>([]);
  const longPressTimer = useRef<ReturnType<typeof setTimeout> | null>(null);

  const handleClick = useCallback(() => {
    if (!onTrigger) return;
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

  const handleMouseDown = useCallback(() => {
    if (!onLongPress) return;
    longPressTimer.current = setTimeout(() => {
      onLongPress();
    }, longPressMs);
  }, [onLongPress, longPressMs]);

  const handleMouseUp = useCallback(() => {
    if (longPressTimer.current) {
      clearTimeout(longPressTimer.current);
      longPressTimer.current = null;
    }
  }, []);

  return (
    <div
      onClick={handleClick}
      onMouseDown={handleMouseDown}
      onMouseUp={handleMouseUp}
      onMouseLeave={handleMouseUp}
      className={className}
      style={{ cursor: "pointer" }}
    >
      {children}
    </div>
  );
}
