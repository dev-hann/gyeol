import { useEffect } from "react";
import { useAppStore } from "../stores/appStore";
import { CheckCircle2, XCircle, Loader2, Clock } from "lucide-react";
import { cn } from "../lib/utils";

export function MonitoringPage() {
  const { tasks, logs, fetchTasks, fetchLogs } = useAppStore();

  useEffect(() => {
    fetchTasks();
    fetchLogs();
    const interval = setInterval(() => {
      fetchTasks();
      fetchLogs();
    }, 3000);
    return () => clearInterval(interval);
  }, [fetchTasks, fetchLogs]);

  const statusIcon = (status: string) => {
    switch (status) {
      case "Running":
        return <Loader2 size={14} className="animate-spin text-blue-400" />;
      case "Done":
        return <CheckCircle2 size={14} className="text-green-400" />;
      case "Failed":
        return <XCircle size={14} className="text-red-400" />;
      default:
        return <Clock size={14} className="text-yellow-400" />;
    }
  };

  return (
    <div className="p-6 space-y-6">
      <div>
        <h2 className="text-xl font-semibold text-[var(--text-primary)]">
          Real-time Monitoring
        </h2>
        <p className="text-sm text-[var(--text-muted)] mt-1">
          Live view of task execution and worker activity
        </p>
      </div>

      <div className="grid grid-cols-2 gap-6">
        <div className="bg-[var(--bg-secondary)] border border-[var(--border)] rounded-lg">
          <div className="px-4 py-3 border-b border-[var(--border)] flex items-center justify-between">
            <h3 className="text-sm font-medium">Active Tasks</h3>
            <span className="text-xs text-[var(--text-muted)]">
              {tasks.filter((t) => t.status === "Running").length} running
            </span>
          </div>
          <div className="divide-y divide-[var(--border)] max-h-[60vh] overflow-auto">
            {tasks
              .filter((t) => t.status === "Running" || t.status === "Pending")
              .map((task) => (
                <div key={task.id} className="px-4 py-3">
                  <div className="flex items-center gap-2">
                    {statusIcon(task.status)}
                    <span className="text-sm font-medium">
                      {task.task_type}
                    </span>
                  </div>
                  <div className="ml-6 mt-1 text-xs text-[var(--text-muted)]">
                    {task.layer_name} / {task.worker_name || "unassigned"} |{" "}
                    Depth: {task.depth} | Retry: {task.retry_count}/
                    {task.max_retries}
                  </div>
                </div>
              ))}
            {tasks.filter((t) => t.status === "Running" || t.status === "Pending")
              .length === 0 && (
              <div className="px-4 py-8 text-center text-sm text-[var(--text-muted)]">
                No active tasks
              </div>
            )}
          </div>
        </div>

        <div className="bg-[var(--bg-secondary)] border border-[var(--border)] rounded-lg">
          <div className="px-4 py-3 border-b border-[var(--border)]">
            <h3 className="text-sm font-medium">Execution Logs</h3>
          </div>
          <div className="divide-y divide-[var(--border)] max-h-[60vh] overflow-auto">
            {logs.map((log) => (
              <div key={log.id} className="px-4 py-2.5">
                <div className="flex items-center gap-2">
                  {statusIcon(log.status === "success" ? "Done" : "Failed")}
                  <span className="text-sm">
                    {log.worker_name || "System"}
                  </span>
                  <span
                    className={cn(
                      "text-[10px] px-1.5 py-0.5 rounded",
                      log.status === "success"
                        ? "bg-green-500/10 text-green-400"
                        : "bg-red-500/10 text-red-400"
                    )}
                  >
                    {log.status}
                  </span>
                </div>
                {log.message && (
                  <div className="ml-6 mt-0.5 text-xs text-[var(--text-muted)] font-mono break-all">
                    {log.message}
                  </div>
                )}
                <div className="ml-6 mt-0.5 text-[10px] text-[var(--text-muted)]">
                  {new Date(log.created_at).toLocaleTimeString()}
                </div>
              </div>
            ))}
            {logs.length === 0 && (
              <div className="px-4 py-8 text-center text-sm text-[var(--text-muted)]">
                No logs yet
              </div>
            )}
          </div>
        </div>
      </div>
    </div>
  );
}
