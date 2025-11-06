/** @type {import('next').NextConfig} */
const nextConfig = {
  reactStrictMode: true,
  experimental: {
    serverActions: { allowedOrigins: ['localhost:9876', 'sweezy.onrender.com'] }
  }
}

export default nextConfig


