import { lazy, Suspense } from "react";
import { BrowserRouter, Routes, Route } from "react-router-dom";
import { AppShell } from "./components/layout/AppShell";

const DashboardPage = lazy(() =>
  import("./pages/Dashboard").then((m) => ({ default: m.DashboardPage }))
);
const MonitoringPage = lazy(() =>
  import("./pages/Monitoring").then((m) => ({ default: m.MonitoringPage }))
);
const LayersPage = lazy(() =>
  import("./pages/Layers").then((m) => ({ default: m.LayersPage }))
);
const WorkersPage = lazy(() =>
  import("./pages/Workers").then((m) => ({ default: m.WorkersPage }))
);
const PromptEditorPage = lazy(() =>
  import("./pages/PromptEditor").then((m) => ({ default: m.PromptEditorPage }))
);
const SettingsPage = lazy(() =>
  import("./pages/Settings").then((m) => ({ default: m.SettingsPage }))
);

function App() {
  return (
    <BrowserRouter>
      <Suspense>
        <Routes>
          <Route element={<AppShell />}>
            <Route path="/" element={<DashboardPage />} />
            <Route path="/monitoring" element={<MonitoringPage />} />
            <Route path="/layers" element={<LayersPage />} />
            <Route path="/workers" element={<WorkersPage />} />
            <Route path="/editor" element={<PromptEditorPage />} />
            <Route path="/settings" element={<SettingsPage />} />
          </Route>
        </Routes>
      </Suspense>
    </BrowserRouter>
  );
}

export default App;
