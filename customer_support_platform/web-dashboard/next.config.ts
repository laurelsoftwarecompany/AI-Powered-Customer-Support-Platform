import type { NextConfig } from "next";

const nextConfig: NextConfig = {
  // Emit .next/standalone so the Docker image can ship a minimal server
  // instead of the whole node_modules tree.
  output: "standalone",
};

export default nextConfig;
