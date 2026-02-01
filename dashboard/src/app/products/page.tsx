"use client";

import { useEffect, useState } from "react";
import { api, type App, type Product } from "@/lib/api";

function formatPrice(micros: number | null, currency: string | null): string {
  if (micros == null) return "-";
  const amount = micros / 1_000_000;
  return new Intl.NumberFormat("en-US", {
    style: "currency",
    currency: currency || "USD",
  }).format(amount);
}

export default function ProductsPage() {
  const [apps, setApps] = useState<App[]>([]);
  const [selectedApp, setSelectedApp] = useState<string>("");
  const [products, setProducts] = useState<Product[]>([]);
  const [syncStatus, setSyncStatus] = useState("");

  useEffect(() => {
    api.listApps().then((a) => {
      setApps(a);
      if (a.length > 0) setSelectedApp(a[0].id);
    });
  }, []);

  useEffect(() => {
    if (selectedApp) {
      api.listProducts(selectedApp).then(setProducts);
    }
  }, [selectedApp]);

  const handleSync = async () => {
    if (!selectedApp) return;
    setSyncStatus("Syncing...");
    try {
      const result = await api.syncProducts(selectedApp);
      setSyncStatus(`Synced ${result.synced} products`);
      api.listProducts(selectedApp).then(setProducts);
    } catch (e) {
      setSyncStatus(`Error: ${e instanceof Error ? e.message : String(e)}`);
    }
  };

  return (
    <div>
      <div className="flex items-center justify-between mb-6">
        <h2 className="text-2xl font-bold">Products</h2>
        <div className="flex items-center gap-3">
          <button
            onClick={handleSync}
            className="px-4 py-2 bg-green-600 hover:bg-green-700 rounded text-sm font-medium"
          >
            Sync from Apple
          </button>
          {syncStatus && <span className="text-sm text-gray-400">{syncStatus}</span>}
        </div>
      </div>

      <select
        value={selectedApp}
        onChange={(e) => setSelectedApp(e.target.value)}
        className="mb-6 px-4 py-2 rounded bg-gray-900 border border-gray-700 text-sm"
      >
        {apps.map((app) => (
          <option key={app.id} value={app.id}>{app.name}</option>
        ))}
      </select>

      <div className="bg-gray-900 border border-gray-800 rounded-lg overflow-hidden">
        <table className="w-full text-sm">
          <thead className="bg-gray-800/50">
            <tr>
              <th className="text-left px-4 py-3 text-gray-400 font-medium">Store Product ID</th>
              <th className="text-left px-4 py-3 text-gray-400 font-medium">Display Name</th>
              <th className="text-left px-4 py-3 text-gray-400 font-medium">Type</th>
              <th className="text-left px-4 py-3 text-gray-400 font-medium">Price</th>
              <th className="text-left px-4 py-3 text-gray-400 font-medium">Period</th>
              <th className="text-left px-4 py-3 text-gray-400 font-medium">Trial</th>
              <th className="text-left px-4 py-3 text-gray-400 font-medium">Last Synced</th>
            </tr>
          </thead>
          <tbody>
            {products.map((p) => (
              <tr key={p.id} className="border-t border-gray-800">
                <td className="px-4 py-3 font-mono text-xs">{p.store_product_id}</td>
                <td className="px-4 py-3">{p.display_name || "-"}</td>
                <td className="px-4 py-3">
                  <span className="px-2 py-0.5 rounded text-xs bg-gray-800">{p.product_type}</span>
                </td>
                <td className="px-4 py-3">{formatPrice(p.price_micros, p.currency)}</td>
                <td className="px-4 py-3 text-gray-400">{p.subscription_period || "-"}</td>
                <td className="px-4 py-3 text-gray-400">{p.trial_period || "-"}</td>
                <td className="px-4 py-3 text-gray-400">
                  {p.last_synced_at ? new Date(p.last_synced_at).toLocaleString() : "Never"}
                </td>
              </tr>
            ))}
            {products.length === 0 && (
              <tr>
                <td colSpan={7} className="px-4 py-8 text-center text-gray-500">No products</td>
              </tr>
            )}
          </tbody>
        </table>
      </div>
    </div>
  );
}
