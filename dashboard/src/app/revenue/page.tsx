"use client";

export default function RevenuePage() {
  return (
    <div>
      <h2 className="text-2xl font-bold mb-6">Revenue</h2>

      <div className="grid grid-cols-1 md:grid-cols-3 gap-4 mb-8">
        <div className="bg-gray-900 border border-gray-800 rounded-lg p-6">
          <p className="text-sm text-gray-400">MRR</p>
          <p className="text-3xl font-bold mt-1">$0.00</p>
        </div>
        <div className="bg-gray-900 border border-gray-800 rounded-lg p-6">
          <p className="text-sm text-gray-400">Active Subscriptions</p>
          <p className="text-3xl font-bold mt-1">0</p>
        </div>
        <div className="bg-gray-900 border border-gray-800 rounded-lg p-6">
          <p className="text-sm text-gray-400">Churn Rate</p>
          <p className="text-3xl font-bold mt-1">0%</p>
        </div>
      </div>

      <div className="bg-gray-900 border border-gray-800 rounded-lg p-6">
        <p className="text-gray-500 text-sm">
          Revenue charts will be available once transaction data is being collected.
          Connect your App Store / Google Play credentials to start tracking.
        </p>
      </div>
    </div>
  );
}
