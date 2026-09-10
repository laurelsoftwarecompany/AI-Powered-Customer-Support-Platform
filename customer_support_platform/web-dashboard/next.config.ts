import type { NextConfig } from "next";

const nextConfig: NextConfig = {
  // Use standalone output for Docker environments, standard for Vercel
  output: process.env.VERCEL ? undefined : "standalone",
  compress: true,
  poweredByHeader: false,
  experimental: {
    optimizePackageImports: ["lucide-react", "@tanstack/react-query"],
  },
};

export default nextConfig;
