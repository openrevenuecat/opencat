"use client";

import Link from "next/link";
import { usePathname } from "next/navigation";

const navItems = [
  { href: "/", label: "Overview" },
  { href: "/subscribers", label: "Subscribers" },
  { href: "/products", label: "Products" },
  { href: "/revenue", label: "Revenue" },
  { href: "/events", label: "Events" },
  { href: "/webhooks", label: "Webhooks" },
  { href: "/settings", label: "Settings" },
];

export function Sidebar() {
  const pathname = usePathname();

  return (
    <aside className="w-56 min-h-screen bg-gray-950 border-r border-gray-800 p-4">
      <div className="mb-8">
        <h1 className="text-xl font-bold text-white">OpenCat</h1>
        <p className="text-xs text-gray-500">IAP Infrastructure</p>
      </div>
      <nav className="space-y-1">
        {navItems.map((item) => (
          <Link
            key={item.href}
            href={item.href}
            className={`block px-3 py-2 rounded text-sm ${
              pathname === item.href
                ? "bg-gray-800 text-white"
                : "text-gray-400 hover:text-white hover:bg-gray-900"
            }`}
          >
            {item.label}
          </Link>
        ))}
      </nav>
    </aside>
  );
}
