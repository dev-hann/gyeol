import { useEffect } from "react";
import { useAppStore } from "../stores/appStore";
import {
  Activity,
  CheckCircle2,
  XCircle,
  Clock,
  Loader2,
  ArrowUpRight,
  LayoutDashboard,
} from "lucide-react";
import { PageHeader } from "@/components/app/PageHeader";
import { StatusBadge } from "@/components/app/StatusBadge";
import { Card, CardHeader, CardTitle, CardContent } from "@/components/ui/card";
import { Badge } from "@/components/ui/badge";

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
    { label: "Queue", value: queueSize, icon: Clock, variant: "info" as const },
    { label: "Pending", value: pending, icon: Activity, variant: "warning" as const },
    { label: "Running", value: running, icon: Loader2, variant: "info" as const },
    { label: "Completed", value: done, icon: CheckCircle2, variant: "success" as const },
    { label: "Failed", value: failed, icon: XCircle, variant: "error" as const },
  ];

  const priorityVariant = (priority: string) => {
    switch (priority) {
      case "High": return "error" as const;
      case "Medium": return "warning" as const;
      default: return "secondary" as const;
    }
  };

  return (
    <div className="p-6 space-y-6">
      <PageHeader
        icon={LayoutDashboard}
        title="Dashboard"
        description="Overview of your AI worker system"
      />

      <div className="grid grid-cols-5 gap-4">
        {stats.map((stat) => (
          <Card key={stat.label} className="transition-shadow hover:shadow-md">
            <CardContent className="p-4">
              <div className="flex items-center justify-between mb-2">
                <span className="text-xs text-muted-foreground uppercase tracking-wider">
                  {stat.label}
                </span>
                <stat.icon size={16} />
              </div>
              <Badge variant={stat.variant} className="text-lg font-bold px-2 py-1">
                {stat.value}
              </Badge>
            </CardContent>
          </Card>
        ))}
      </div>

      <Card>
        <CardHeader className="border-b border-border">
          <CardTitle>Recent Tasks</CardTitle>
        </CardHeader>
        <div className="divide-y divide-border">
          {tasks.slice(0, 20).map((task) => (
            <div
              key={task.id}
              className="px-4 py-3 flex items-center gap-3 hover:bg-accent transition-colors"
            >
              <div className="flex-1 min-w-0">
                <div className="flex items-center gap-2">
                  <span className="text-sm font-medium text-foreground">
                    {task.task_type}
                  </span>
                  <StatusBadge status={task.status} />
                  <Badge variant={priorityVariant(task.priority)}>{task.priority}</Badge>
                </div>
                <div className="text-xs text-muted-foreground mt-0.5 flex items-center gap-2">
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
              <div className="text-[10px] text-muted-foreground font-mono">
                {task.id.slice(0, 8)}
              </div>
            </div>
          ))}
          {tasks.length === 0 && (
            <div className="px-4 py-8 text-center text-sm text-muted-foreground">
              No tasks yet. Create a task or configure layers to get started.
            </div>
          )}
        </div>
      </Card>
    </div>
  );
}
