"use client";

import { useState } from "react";
import { api, type SubscriberInfo } from "@/lib/api";

export default function SubscribersPage() {
  const [query, setQuery] = useState("");
  const [subscriber, setSubscriber] = useState<SubscriberInfo | null>(null);
  const [error, setError] = useState<string | null>(null);

  const handleSearch = async () => {
    setError(null);
    setSubscriber(null);
    try {
      const info = await api.getSubscriber(query);
      setSubscriber(info);
    } catch (e: unknown) {
      setError(e instanceof Error ? e.message : "Unknown error");
    }
  };

  return (
    <div>
      <h2 className="text-2xl font-bold mb-6">Subscribers</h2>

      <div className="flex gap-2 mb-6">
        <input
          type="text"
          placeholder="Enter app_user_id..."
          value={query}
          onChange={(e) => setQuery(e.target.value)}
          onKeyDown={(e) => e.key === "Enter" && handleSearch()}
          className="flex-1 max-w-md px-4 py-2 rounded bg-gray-900 border border-gray-700 text-sm focus:outline-none focus:border-gray-500"
        />
        <button
          onClick={handleSearch}
          className="px-4 py-2 bg-white text-black rounded text-sm font-medium hover:bg-gray-200"
        >
          Search
        </button>
      </div>

      {error && (
        <div className="bg-red-900/30 border border-red-800 rounded-lg p-4 mb-4">
          <p className="text-red-400 text-sm">{error}</p>
        </div>
      )}

      {subscriber && (
        <div className="space-y-6">
          <div className="bg-gray-900 border border-gray-800 rounded-lg p-6">
            <h3 className="font-semibold mb-3">Subscriber Info</h3>
            <dl className="grid grid-cols-2 gap-2 text-sm">
              <dt className="text-gray-400">ID</dt>
              <dd className="font-mono text-xs">{subscriber.subscriber.id}</dd>
              <dt className="text-gray-400">App User ID</dt>
              <dd>{subscriber.subscriber.app_user_id}</dd>
              <dt className="text-gray-400">Created</dt>
              <dd>{new Date(subscriber.subscriber.created_at).toLocaleString()}</dd>
            </dl>
          </div>

          <div className="bg-gray-900 border border-gray-800 rounded-lg p-6">
            <h3 className="font-semibold mb-3">Active Entitlements</h3>
            {subscriber.active_entitlements.length === 0 ? (
              <p className="text-gray-500 text-sm">No active entitlements</p>
            ) : (
              <div className="flex gap-2">
                {subscriber.active_entitlements.map((e) => (
                  <span key={e.id} className="px-3 py-1 rounded-full bg-green-900/50 text-green-400 text-xs">
                    {e.name}
                  </span>
                ))}
              </div>
            )}
          </div>

          <div className="bg-gray-900 border border-gray-800 rounded-lg overflow-hidden">
            <h3 className="font-semibold p-4">Transactions</h3>
            <table className="w-full text-sm">
              <thead className="bg-gray-800/50">
                <tr>
                  <th className="text-left px-4 py-2 text-gray-400 font-medium">Store</th>
                  <th className="text-left px-4 py-2 text-gray-400 font-medium">Status</th>
                  <th className="text-left px-4 py-2 text-gray-400 font-medium">Purchase Date</th>
                  <th className="text-left px-4 py-2 text-gray-400 font-medium">Expiration</th>
                </tr>
              </thead>
              <tbody>
                {subscriber.transactions.map((t) => (
                  <tr key={t.id} className="border-t border-gray-800">
                    <td className="px-4 py-2">{t.store}</td>
                    <td className="px-4 py-2">
                      <span className={`px-2 py-0.5 rounded text-xs ${
                        t.status === "active" ? "bg-green-900/50 text-green-400" : "bg-gray-800 text-gray-400"
                      }`}>
                        {t.status}
                      </span>
                    </td>
                    <td className="px-4 py-2 text-gray-400">{new Date(t.purchase_date).toLocaleString()}</td>
                    <td className="px-4 py-2 text-gray-400">{t.expiration_date ? new Date(t.expiration_date).toLocaleString() : "-"}</td>
                  </tr>
                ))}
              </tbody>
            </table>
          </div>
        </div>
      )}
    </div>
  );
}
