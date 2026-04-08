import { clsx, type ClassValue } from "clsx";
import { twMerge } from "tailwind-merge";

export function cn(...inputs: ClassValue[]) {
  return twMerge(clsx(inputs));
}

export const splitCSV = (value: string): string[] =>
  value.split(",").map((s) => s.trim()).filter(Boolean);
