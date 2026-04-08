import { useEffect } from "react";
import { useAppStore } from "@/stores/appStore";
import { CheckCircle2, XCircle, Loader2, Clock, Activity } from "lucide-react";
import { Badge } from "@/components/ui/badge";
import { PageHeader } from "@/components/app/PageHeader";

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
        return <Loader2 size={14} className="animate-spin text-info" />;
      case "Done":
        return <CheckCircle2 size={14} className="text-success" />;
      case "Failed":
        return <XCircle size={14} className="text-destructive" />;
      default:
        return <Clock size={14} className="text-warning" />;
    }
  };

  return (
    <div className="p-6 space-y-6">
      <PageHeader
        icon={Activity}
        title="Real-time Monitoring"
        description="Live view of task execution and worker activity"
      />

      <div className="grid grid-cols-2 gap-6">
        <div className="bg-card border border-border rounded-lg">
          <div className="px-4 py-3 border-b border-border flex items-center justify-between">
            <h3 className="text-sm font-medium">Active Tasks</h3>
            <span className="text-xs text-muted-foreground">
              {tasks.filter((t) => t.status === "Running").length} running
            </span>
          </div>
          <div className="divide-y divide-border max-h-[60vh] overflow-auto">
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
                  <div className="ml-6 mt-1 text-xs text-muted-foreground">
                    {task.layer_name || "N/A"} / {task.worker_name || "unassigned"} |{" "}
                    Depth: {task.depth} | Retry: {task.retry_count}/
                    {task.max_retries}
                  </div>
                </div>
              ))}
            {tasks.filter((t) => t.status === "Running" || t.status === "Pending")
              .length === 0 && (
              <div className="px-4 py-8 text-center text-sm text-muted-foreground">
                No active tasks
              </div>
            )}
          </div>
        </div>

        <div className="bg-card border border-border rounded-lg">
          <div className="px-4 py-3 border-b border-border">
            <h3 className="text-sm font-medium">Execution Logs</h3>
          </div>
          <div className="divide-y divide-border max-h-[60vh] overflow-auto">
            {logs.map((log) => (
              <div key={log.id} className="px-4 py-2.5">
                <div className="flex items-center gap-2">
                  {statusIcon(log.status === "success" ? "Done" : "Failed")}
                  <span className="text-sm">
                    {log.worker_name || "System"}
                  </span>
                  <span>
                    <Badge variant={log.status === "success" ? "success" : "error"}>
                      {log.status}
                    </Badge>
                  </span>
                </div>
                {log.message && (
                  <div className="ml-6 mt-0.5 text-xs text-muted-foreground font-mono break-all">
                    {log.message}
                  </div>
                )}
                <div className="ml-6 mt-0.5 text-[10px] text-muted-foreground">
                  {new Date(log.created_at).toLocaleTimeString()}
                </div>
              </div>
            ))}
            {logs.length === 0 && (
              <div className="px-4 py-8 text-center text-sm text-muted-foreground">
                No logs yet
              </div>
            )}
          </div>
        </div>
      </div>
    </div>
  );
}
