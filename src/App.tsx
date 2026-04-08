import { BrowserRouter, Routes, Route } from "react-router-dom";
import { AppShell } from "./components/layout/AppShell";
import { DashboardPage } from "./pages/Dashboard";
import { MonitoringPage } from "./pages/Monitoring";
import { LayersPage } from "./pages/Layers";
import { WorkersPage } from "./pages/Workers";
import { PromptEditorPage } from "./pages/PromptEditor";
import { SettingsPage } from "./pages/Settings";

function App() {
  return (
    <BrowserRouter>
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
    </BrowserRouter>
  );
}

export default App;
