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
import { cn } from "../../lib/utils";
import { useAppStore } from "../../stores/appStore";

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
    <div className="flex h-screen">
      <aside className="w-56 flex-shrink-0 bg-[var(--bg-secondary)] border-r border-[var(--border)] flex flex-col">
        <div className="p-4 border-b border-[var(--border)]">
          <h1 className="text-lg font-semibold tracking-tight text-[var(--text-primary)]">
            Gyeol
          </h1>
          <p className="text-xs text-[var(--text-muted)] mt-0.5">
            AI Multi-Layer Worker
          </p>
        </div>

        <nav className="flex-1 p-2 space-y-0.5">
          {navItems.map((item) => (
            <NavLink
              key={item.to}
              to={item.to}
              className={({ isActive }) =>
                cn(
                  "flex items-center gap-2.5 px-3 py-2 rounded-md text-sm transition-colors",
                  isActive
                    ? "bg-[var(--accent)] text-white"
                    : "text-[var(--text-secondary)] hover:bg-[var(--bg-hover)] hover:text-[var(--text-primary)]"
                )
              }
            >
              <item.icon size={16} />
              {item.label}
            </NavLink>
          ))}
        </nav>

        <div className="p-3 border-t border-[var(--border)]">
          <div className="text-xs text-[var(--text-muted)] mb-2">
            Queue: {queueSize} tasks
          </div>
          <button
            onClick={runScheduler}
            disabled={loading}
            className={cn(
              "w-full flex items-center justify-center gap-2 px-3 py-2 rounded-md text-sm font-medium transition-colors",
              loading
                ? "bg-[var(--bg-hover)] text-[var(--text-muted)] cursor-not-allowed"
                : "bg-[var(--accent)] hover:bg-[var(--accent-hover)] text-white"
            )}
          >
            <Play size={14} />
            {loading ? "Running..." : "Run Scheduler"}
          </button>
        </div>
      </aside>

      <main className="flex-1 overflow-auto bg-[var(--bg-primary)]">
        <Outlet />
      </main>
    </div>
  );
}
