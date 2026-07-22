import { defineConfig, globalIgnores } from "eslint/config"
import nextVitals from "eslint-config-next/core-web-vitals"

export default defineConfig([
  ...nextVitals,
  {
    rules: {
      // Existing admin editors intentionally hydrate controlled state when a dialog opens.
      "react-hooks/set-state-in-effect": "off",
      // Server monitoring measures upstream latency during dynamic rendering.
      "react-hooks/purity": "off",
      // CMS previews accept arbitrary editor-provided image URLs that cannot be allow-listed.
      "@next/next/no-img-element": "off",
    },
  },
  globalIgnores([".next/**", "node_modules/**", "next-env.d.ts"]),
])
