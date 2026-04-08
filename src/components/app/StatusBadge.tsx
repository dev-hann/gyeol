import { Badge } from "@/components/ui/badge";
import type { VariantProps } from "class-variance-authority";

type BadgeVariant = VariantProps<typeof Badge>["variant"];

const statusMap: Record<string, BadgeVariant> = {
  Pending: "warning",
  Running: "info",
  Done: "success",
  Failed: "error",
  success: "success",
  failed: "error",
};

interface StatusBadgeProps {
  status: string;
  className?: string;
}

export function StatusBadge({ status, className }: StatusBadgeProps) {
  const variant = statusMap[status] ?? "secondary";
  return (
    <Badge variant={variant} className={className}>
      {status}
    </Badge>
  );
}
