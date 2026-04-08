import { NavLink, Outlet } from "react-router-dom";
import {
  Activity,
  Settings,
  LayoutDashboard,
  Code2,
  Layers,
  Cpu,
  Play,
} from "lucide-react";
import { cn } from "@/lib/utils";
import { useAppStore } from "@/stores/appStore";
import { Button } from "@/components/ui/button";
import { Separator } from "@/components/ui/separator";
import {
  Tooltip,
  TooltipContent,
  TooltipProvider,
  TooltipTrigger,
} from "@/components/ui/tooltip";

const navItems = [
  { to: "/", icon: LayoutDashboard, label: "Dashboard" },
  { to: "/monitoring", icon: Activity, label: "Monitoring" },
  { to: "/layers", icon: Layers, label: "Layers" },
  { to: "/workers", icon: Cpu, label: "Workers" },
  { to: "/editor", icon: Code2, label: "Prompt Editor" },
  { to: "/settings", icon: Settings, label: "Settings" },
];

export function AppShell() {
  const { runScheduler, loading, queueSize } = useAppStore();

  return (
    <TooltipProvider>
      <div className="flex h-screen">
        <aside className="w-56 flex-shrink-0 bg-card border-r border-border flex flex-col">
          <div className="p-4">
            <h1 className="text-lg font-semibold tracking-tight text-foreground">
              Gyeol
            </h1>
            <p className="text-xs text-muted-foreground mt-0.5">
              AI Multi-Layer Worker
            </p>
          </div>

          <Separator />

          <nav className="flex-1 p-2 space-y-0.5">
            {navItems.map((item) => (
              <NavLink
                key={item.to}
                to={item.to}
                end={item.to === "/"}
                className={({ isActive }) =>
                  cn(
                    "flex items-center gap-2.5 px-3 py-2 rounded-md text-sm transition-colors",
                    isActive
                      ? "bg-primary text-primary-foreground"
                      : "text-muted-foreground hover:bg-accent hover:text-foreground"
                  )
                }
              >
                <item.icon size={16} />
                {item.label}
              </NavLink>
            ))}
          </nav>

          <Separator />

          <div className="p-3">
            <div className="text-xs text-muted-foreground mb-2">
              Queue: {queueSize} tasks
            </div>
            <Tooltip>
              <TooltipTrigger asChild>
                <Button
                  onClick={runScheduler}
                  disabled={loading}
                  className="w-full"
                  size="sm"
                >
                  <Play size={14} />
                  {loading ? "Running..." : "Run Scheduler"}
                </Button>
              </TooltipTrigger>
              <TooltipContent>Execute the next batch of tasks</TooltipContent>
            </Tooltip>
          </div>
        </aside>

        <main className="flex-1 overflow-auto bg-background">
          <Outlet />
        </main>
      </div>
    </TooltipProvider>
  );
}
