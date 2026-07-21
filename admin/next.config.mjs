/** @type {import('next').NextConfig} */
const nextConfig = {
  reactStrictMode: true,
  outputFileTracingRoot: process.cwd(),
  experimental: {
    serverActions: { allowedOrigins: ['localhost:9876', 'sweezy.onrender.com'] }
  }
}

export default nextConfig

