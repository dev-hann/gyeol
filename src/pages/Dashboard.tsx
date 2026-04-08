import { useEffect } from "react";
import { useAppStore } from "../stores/appStore";
import {
  Activity,
  CheckCircle2,
  XCircle,
  Clock,
  Loader2,
  ArrowUpRight,
} from "lucide-react";
import { cn } from "../lib/utils";

export function DashboardPage() {
  const { tasks, queueSize, fetchTasks, fetchQueueSize } = useAppStore();

  useEffect(() => {
    fetchTasks();
    fetchQueueSize();
    const interval = setInterval(() => {
      fetchTasks();
      fetchQueueSize();
    }, 5000);
    return () => clearInterval(interval);
  }, [fetchTasks, fetchQueueSize]);

  const pending = tasks.filter((t) => t.status === "Pending").length;
  const running = tasks.filter((t) => t.status === "Running").length;
  const done = tasks.filter((t) => t.status === "Done").length;
  const failed = tasks.filter((t) => t.status === "Failed").length;

  const stats = [
    { label: "Queue", value: queueSize, icon: Clock, color: "text-blue-400" },
    {
      label: "Pending",
      value: pending,
      icon: Activity,
      color: "text-yellow-400",
    },
    {
      label: "Running",
      value: running,
      icon: Loader2,
      color: "text-purple-400",
    },
    {
      label: "Completed",
      value: done,
      icon: CheckCircle2,
      color: "text-green-400",
    },
    { label: "Failed", value: failed, icon: XCircle, color: "text-red-400" },
  ];

  const statusColor = (status: string) => {
    switch (status) {
      case "Pending":
        return "bg-yellow-500/10 text-yellow-400 border-yellow-500/20";
      case "Running":
        return "bg-blue-500/10 text-blue-400 border-blue-500/20";
      case "Done":
        return "bg-green-500/10 text-green-400 border-green-500/20";
      case "Failed":
        return "bg-red-500/10 text-red-400 border-red-500/20";
      default:
        return "bg-zinc-500/10 text-zinc-400 border-zinc-500/20";
    }
  };

  const priorityColor = (priority: string) => {
    switch (priority) {
      case "High":
        return "text-red-400";
      case "Medium":
        return "text-yellow-400";
      default:
        return "text-zinc-400";
    }
  };

  return (
    <div className="p-6 space-y-6">
      <div>
        <h2 className="text-xl font-semibold text-[var(--text-primary)]">
          Dashboard
        </h2>
        <p className="text-sm text-[var(--text-muted)] mt-1">
          Overview of your AI worker system
        </p>
      </div>

      <div className="grid grid-cols-5 gap-4">
        {stats.map((stat) => (
          <div
            key={stat.label}
            className="bg-[var(--bg-secondary)] border border-[var(--border)] rounded-lg p-4"
          >
            <div className="flex items-center justify-between mb-2">
              <span className="text-xs text-[var(--text-muted)] uppercase tracking-wider">
                {stat.label}
              </span>
              <stat.icon size={16} className={stat.color} />
            </div>
            <div className={cn("text-2xl font-bold", stat.color)}>
              {stat.value}
            </div>
          </div>
        ))}
      </div>

      <div className="bg-[var(--bg-secondary)] border border-[var(--border)] rounded-lg">
        <div className="px-4 py-3 border-b border-[var(--border)]">
          <h3 className="text-sm font-medium text-[var(--text-primary)]">
            Recent Tasks
          </h3>
        </div>
        <div className="divide-y divide-[var(--border)]">
          {tasks.slice(0, 20).map((task) => (
            <div
              key={task.id}
              className="px-4 py-3 flex items-center gap-3 hover:bg-[var(--bg-hover)] transition-colors"
            >
              <div className="flex-1 min-w-0">
                <div className="flex items-center gap-2">
                  <span className="text-sm font-medium text-[var(--text-primary)]">
                    {task.task_type}
                  </span>
                  <span
                    className={cn(
                      "text-[10px] px-1.5 py-0.5 rounded border",
                      statusColor(task.status)
                    )}
                  >
                    {task.status}
                  </span>
                  <span
                    className={cn("text-[10px]", priorityColor(task.priority))}
                  >
                    {task.priority}
                  </span>
                </div>
                <div className="text-xs text-[var(--text-muted)] mt-0.5 flex items-center gap-2">
                  <span>
                    {task.layer_name && `Layer: ${task.layer_name}`}
                  </span>
                  {task.worker_name && (
                    <span className="flex items-center gap-0.5">
                      <ArrowUpRight size={10} />
                      {task.worker_name}
                    </span>
                  )}
                  <span>
                    {new Date(task.created_at).toLocaleTimeString()}
                  </span>
                </div>
              </div>
              <div className="text-[10px] text-[var(--text-muted)] font-mono">
                {task.id.slice(0, 8)}
              </div>
            </div>
          ))}
          {tasks.length === 0 && (
            <div className="px-4 py-8 text-center text-sm text-[var(--text-muted)]">
              No tasks yet. Create a task or configure layers to get started.
            </div>
          )}
        </div>
      </div>
    </div>
  );
}
