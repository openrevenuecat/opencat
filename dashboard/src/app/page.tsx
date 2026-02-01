"use client";

import { useEffect, useState } from "react";
import { api, type App } from "@/lib/api";

export default function Overview() {
  const [apps, setApps] = useState<App[]>([]);
  const [error, setError] = useState<string | null>(null);

  useEffect(() => {
    api.listApps().then(setApps).catch((e) => setError(e.message));
  }, []);

  return (
    <div>
      <h2 className="text-2xl font-bold mb-6">Overview</h2>

      <div className="grid grid-cols-1 md:grid-cols-3 gap-4 mb-8">
        <div className="bg-gray-900 border border-gray-800 rounded-lg p-6">
          <p className="text-sm text-gray-400">Total Apps</p>
          <p className="text-3xl font-bold mt-1">{apps.length}</p>
        </div>
        <div className="bg-gray-900 border border-gray-800 rounded-lg p-6">
          <p className="text-sm text-gray-400">Status</p>
          <p className="text-3xl font-bold mt-1 text-green-400">Healthy</p>
        </div>
        <div className="bg-gray-900 border border-gray-800 rounded-lg p-6">
          <p className="text-sm text-gray-400">Version</p>
          <p className="text-3xl font-bold mt-1">0.1.0</p>
        </div>
      </div>

      {error && (
        <div className="bg-red-900/30 border border-red-800 rounded-lg p-4 mb-4">
          <p className="text-red-400 text-sm">{error}</p>
        </div>
      )}

      <h3 className="text-lg font-semibold mb-3">Apps</h3>
      <div className="bg-gray-900 border border-gray-800 rounded-lg overflow-hidden">
        <table className="w-full text-sm">
          <thead className="bg-gray-800/50">
            <tr>
              <th className="text-left px-4 py-3 text-gray-400 font-medium">Name</th>
              <th className="text-left px-4 py-3 text-gray-400 font-medium">Platform</th>
              <th className="text-left px-4 py-3 text-gray-400 font-medium">Bundle ID</th>
              <th className="text-left px-4 py-3 text-gray-400 font-medium">Created</th>
            </tr>
          </thead>
          <tbody>
            {apps.map((app) => (
              <tr key={app.id} className="border-t border-gray-800">
                <td className="px-4 py-3">{app.name}</td>
                <td className="px-4 py-3">
                  <span className="px-2 py-0.5 rounded text-xs bg-gray-800">{app.platform}</span>
                </td>
                <td className="px-4 py-3 text-gray-400 font-mono text-xs">{app.bundle_id}</td>
                <td className="px-4 py-3 text-gray-400">{new Date(app.created_at).toLocaleDateString()}</td>
              </tr>
            ))}
            {apps.length === 0 && (
              <tr>
                <td colSpan={4} className="px-4 py-8 text-center text-gray-500">
                  No apps yet. Create one via the API.
                </td>
              </tr>
            )}
          </tbody>
        </table>
      </div>
    </div>
  );
}
