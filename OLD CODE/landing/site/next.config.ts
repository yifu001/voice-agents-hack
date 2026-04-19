import type { NextConfig } from 'next';
import path from 'node:path';

const config: NextConfig = {
  reactStrictMode: true,
  // Pin tracing root to this project — silences the "multiple lockfiles"
  // warning when a parent directory also has a package-lock.json.
  outputFileTracingRoot: path.resolve(__dirname),
};

export default config;
