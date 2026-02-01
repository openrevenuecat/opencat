"use client";

import { useEffect, useState } from "react";
import { api, type App } from "@/lib/api";
import { defaultConfig, type DashboardConfig } from "@/lib/theme";

export default function SettingsPage() {
  const [config, setConfig] = useState<DashboardConfig>(defaultConfig);
  const [apps, setApps] = useState<App[]>([]);
  const [selectedAppId, setSelectedAppId] = useState("");

  // Credentials form
  const [issuerId, setIssuerId] = useState("");
  const [keyId, setKeyId] = useState("");
  const [privateKey, setPrivateKey] = useState("");
  const [credStatus, setCredStatus] = useState("");
  const [syncStatus, setSyncStatus] = useState("");
  const [existingCreds, setExistingCreds] = useState<Record<string, unknown> | null>(null);

  useEffect(() => {
    api.listApps().then(setApps).catch(console.error);
  }, []);

  useEffect(() => {
    if (selectedAppId) {
      api.getCredentials(selectedAppId).then((creds) => {
        setExistingCreds(creds);
      }).catch(console.error);
    }
  }, [selectedAppId]);

  const toggleModule = (key: keyof DashboardConfig["modules"]) => {
    setConfig((prev) => ({
      ...prev,
      modules: { ...prev.modules, [key]: !prev.modules[key] },
    }));
  };

  const saveCredentials = async () => {
    if (!selectedAppId) return;
    setCredStatus("Saving...");
    try {
      await api.updateCredentials(selectedAppId, {
        apple: { issuer_id: issuerId, key_id: keyId, private_key: privateKey },
      });
      setCredStatus("Credentials saved successfully");
      setExistingCreds(await api.getCredentials(selectedAppId));
    } catch (e) {
      setCredStatus(`Error: ${e instanceof Error ? e.message : String(e)}`);
    }
  };

  const syncProducts = async () => {
    if (!selectedAppId) return;
    setSyncStatus("Syncing...");
    try {
      const result = await api.syncProducts(selectedAppId);
      setSyncStatus(`Synced ${result.synced} products: ${result.products.join(", ")}`);
    } catch (e) {
      setSyncStatus(`Error: ${e instanceof Error ? e.message : String(e)}`);
    }
  };

  return (
    <div>
      <h2 className="text-2xl font-bold mb-6">Settings</h2>

      <div className="space-y-6 max-w-lg">
        {/* Brand Settings */}
        <div className="bg-gray-900 border border-gray-800 rounded-lg p-6">
          <h3 className="font-semibold mb-4">Brand</h3>
          <label className="block text-sm text-gray-400 mb-1">Dashboard Name</label>
          <input
            type="text"
            value={config.brandName}
            onChange={(e) => setConfig((prev) => ({ ...prev, brandName: e.target.value }))}
            className="w-full px-4 py-2 rounded bg-gray-800 border border-gray-700 text-sm"
          />
        </div>

        {/* Store Credentials */}
        <div className="bg-gray-900 border border-gray-800 rounded-lg p-6">
          <h3 className="font-semibold mb-4">App Store Connect Credentials</h3>

          <label className="block text-sm text-gray-400 mb-1">Select App</label>
          <select
            value={selectedAppId}
            onChange={(e) => setSelectedAppId(e.target.value)}
            className="w-full px-4 py-2 rounded bg-gray-800 border border-gray-700 text-sm mb-4"
          >
            <option value="">Choose an app...</option>
            {apps.map((app) => (
              <option key={app.id} value={app.id}>
                {app.name} ({app.bundle_id})
              </option>
            ))}
          </select>

          {existingCreds && Object.keys(existingCreds).length > 0 && (
            <div className="mb-4 p-3 bg-gray-800 rounded text-sm text-gray-300">
              Current: {JSON.stringify(existingCreds)}
            </div>
          )}

          {selectedAppId && (
            <>
              <label className="block text-sm text-gray-400 mb-1">Issuer ID</label>
              <input
                type="text"
                value={issuerId}
                onChange={(e) => setIssuerId(e.target.value)}
                placeholder="xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx"
                className="w-full px-4 py-2 rounded bg-gray-800 border border-gray-700 text-sm mb-3"
              />

              <label className="block text-sm text-gray-400 mb-1">Key ID</label>
              <input
                type="text"
                value={keyId}
                onChange={(e) => setKeyId(e.target.value)}
                placeholder="XXXXXXXXXX"
                className="w-full px-4 py-2 rounded bg-gray-800 border border-gray-700 text-sm mb-3"
              />

              <label className="block text-sm text-gray-400 mb-1">Private Key (.p8 contents)</label>
              <textarea
                value={privateKey}
                onChange={(e) => setPrivateKey(e.target.value)}
                placeholder="-----BEGIN PRIVATE KEY-----&#10;...&#10;-----END PRIVATE KEY-----"
                rows={5}
                className="w-full px-4 py-2 rounded bg-gray-800 border border-gray-700 text-sm font-mono mb-3"
              />

              <div className="flex gap-3">
                <button
                  onClick={saveCredentials}
                  className="px-4 py-2 bg-blue-600 hover:bg-blue-700 rounded text-sm font-medium"
                >
                  Save Credentials
                </button>
                <button
                  onClick={syncProducts}
                  className="px-4 py-2 bg-green-600 hover:bg-green-700 rounded text-sm font-medium"
                >
                  Sync Products from Apple
                </button>
              </div>

              {credStatus && (
                <p className="mt-3 text-sm text-gray-300">{credStatus}</p>
              )}
              {syncStatus && (
                <p className="mt-2 text-sm text-gray-300">{syncStatus}</p>
              )}
            </>
          )}
        </div>

        {/* Modules */}
        <div className="bg-gray-900 border border-gray-800 rounded-lg p-6">
          <h3 className="font-semibold mb-4">Modules</h3>
          <div className="space-y-3">
            {(Object.keys(config.modules) as (keyof DashboardConfig["modules"])[]).map((key) => (
              <label key={key} className="flex items-center justify-between">
                <span className="text-sm capitalize">{key}</span>
                <button
                  onClick={() => toggleModule(key)}
                  className={`w-10 h-5 rounded-full transition-colors ${
                    config.modules[key] ? "bg-green-600" : "bg-gray-700"
                  }`}
                >
                  <span
                    className={`block w-4 h-4 rounded-full bg-white transition-transform ${
                      config.modules[key] ? "translate-x-5" : "translate-x-0.5"
                    }`}
                  />
                </button>
              </label>
            ))}
          </div>
        </div>
      </div>
    </div>
  );
}
