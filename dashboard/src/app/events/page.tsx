"use client";

import { useEffect, useState } from "react";
import { api, type Event } from "@/lib/api";

export default function EventsPage() {
  const [events, setEvents] = useState<Event[]>([]);
  const [error, setError] = useState<string | null>(null);

  useEffect(() => {
    api.listEvents(undefined, 50).then(setEvents).catch((e) => setError(e.message));
  }, []);

  return (
    <div>
      <h2 className="text-2xl font-bold mb-6">Events</h2>

      {error && (
        <div className="bg-red-900/30 border border-red-800 rounded-lg p-4 mb-4">
          <p className="text-red-400 text-sm">{error}</p>
        </div>
      )}

      <div className="bg-gray-900 border border-gray-800 rounded-lg overflow-hidden">
        <table className="w-full text-sm">
          <thead className="bg-gray-800/50">
            <tr>
              <th className="text-left px-4 py-3 text-gray-400 font-medium">Time</th>
              <th className="text-left px-4 py-3 text-gray-400 font-medium">Type</th>
              <th className="text-left px-4 py-3 text-gray-400 font-medium">ID</th>
            </tr>
          </thead>
          <tbody>
            {events.map((event) => (
              <tr key={event.id} className="border-t border-gray-800">
                <td className="px-4 py-3 text-gray-400">{new Date(event.created_at).toLocaleString()}</td>
                <td className="px-4 py-3">
                  <span className="px-2 py-0.5 rounded text-xs bg-blue-900/50 text-blue-400">
                    {event.event_type}
                  </span>
                </td>
                <td className="px-4 py-3 font-mono text-xs text-gray-500">{event.id}</td>
              </tr>
            ))}
            {events.length === 0 && (
              <tr>
                <td colSpan={3} className="px-4 py-8 text-center text-gray-500">No events yet</td>
              </tr>
            )}
          </tbody>
        </table>
      </div>
    </div>
  );
}
