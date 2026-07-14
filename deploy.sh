#!/usr/bin/env bash
# Stand up the whole stack: infrastructure, then frontend build and deploy.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$ROOT"

echo "==> Installing S3 presigner deps for the records Lambda"
(cd lambda/records && npm install --omit=dev)

echo "==> Deploying infrastructure with Terraform"
cd terraform
terraform init -input=false
terraform apply -auto-approve

# Pull outputs into shell variables so the frontend build gets them
# automatically. No manual copy-paste, which means CI can run this too.
API_URL=$(terraform output -raw api_url)
USER_POOL_ID=$(terraform output -raw cognito_user_pool_id)
CLIENT_ID=$(terraform output -raw cognito_client_id)
REGION=$(terraform output -raw cognito_region)
BUCKET=$(terraform output -raw frontend_bucket)
DIST_ID=$(terraform output -raw cloudfront_distribution_id)
FRONTEND_URL=$(terraform output -raw frontend_url)
cd "$ROOT"

echo "==> Writing frontend/.env from Terraform outputs"
cat > frontend/.env <<EOF
VITE_API_URL=${API_URL}
VITE_USER_POOL_ID=${USER_POOL_ID}
VITE_CLIENT_ID=${CLIENT_ID}
VITE_REGION=${REGION}
EOF

echo "==> Building the frontend"
(cd frontend && npm install && npm run build)

echo "==> Uploading to S3"
# Hashed assets get a long cache. index.html must not, or browsers keep
# serving the old app after a deploy.
aws s3 sync frontend/dist "s3://${BUCKET}" \
  --delete \
  --exclude "index.html" \
  --cache-control "public,max-age=31536000,immutable"

aws s3 cp frontend/dist/index.html "s3://${BUCKET}/index.html" \
  --cache-control "no-cache,no-store,must-revalidate"

echo "==> Invalidating the CloudFront cache"
aws cloudfront create-invalidation \
  --distribution-id "${DIST_ID}" \
  --paths "/*" \
  --no-cli-pager > /dev/null

echo ""
echo "Deployed: ${FRONTEND_URL}"
echo ""
echo "Next: create a user if you have not already."
echo "  ./create-user.sh doctor@example.com YourPass123 doctors"
echo ""
echo "CloudFront takes a few minutes to propagate on first deploy."