"use client";

import { useEffect, useState } from "react";
import { api, type WebhookEndpoint } from "@/lib/api";

export default function WebhooksPage() {
  const [webhooks, setWebhooks] = useState<WebhookEndpoint[]>([]);
  const [error, setError] = useState<string | null>(null);

  useEffect(() => {
    api.listWebhooks().then(setWebhooks).catch((e) => setError(e.message));
  }, []);

  return (
    <div>
      <h2 className="text-2xl font-bold mb-6">Webhooks</h2>

      {error && (
        <div className="bg-red-900/30 border border-red-800 rounded-lg p-4 mb-4">
          <p className="text-red-400 text-sm">{error}</p>
        </div>
      )}

      <div className="bg-gray-900 border border-gray-800 rounded-lg overflow-hidden">
        <table className="w-full text-sm">
          <thead className="bg-gray-800/50">
            <tr>
              <th className="text-left px-4 py-3 text-gray-400 font-medium">URL</th>
              <th className="text-left px-4 py-3 text-gray-400 font-medium">Status</th>
              <th className="text-left px-4 py-3 text-gray-400 font-medium">Created</th>
            </tr>
          </thead>
          <tbody>
            {webhooks.map((wh) => (
              <tr key={wh.id} className="border-t border-gray-800">
                <td className="px-4 py-3 font-mono text-xs">{wh.url}</td>
                <td className="px-4 py-3">
                  <span className={`px-2 py-0.5 rounded text-xs ${
                    wh.active ? "bg-green-900/50 text-green-400" : "bg-gray-800 text-gray-400"
                  }`}>
                    {wh.active ? "Active" : "Inactive"}
                  </span>
                </td>
                <td className="px-4 py-3 text-gray-400">{new Date(wh.created_at).toLocaleDateString()}</td>
              </tr>
            ))}
            {webhooks.length === 0 && (
              <tr>
                <td colSpan={3} className="px-4 py-8 text-center text-gray-500">No webhooks configured</td>
              </tr>
            )}
          </tbody>
        </table>
      </div>
    </div>
  );
}
