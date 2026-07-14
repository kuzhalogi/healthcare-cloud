// Values come from environment variables at build time.
// Populate .env from terraform output before running the build.
const config = {
  apiUrl: import.meta.env.VITE_API_URL,
  userPoolId: import.meta.env.VITE_USER_POOL_ID,
  clientId: import.meta.env.VITE_CLIENT_ID,
  region: import.meta.env.VITE_REGION,
};

export default config;