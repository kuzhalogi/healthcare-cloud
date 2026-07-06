#!/usr/bin/env bash
# One command to stand up the whole stack.
set -e

echo "==> Installing S3 presigner deps for the records Lambda"
cd lambda/records && npm install --omit=dev && cd ../..

echo "==> Deploying infrastructure with Terraform"
cd terraform
terraform init
terraform apply -auto-approve

echo ""
echo "==> Done. Copy these values into frontend/src/config.js:"
terraform output
cd ..

echo ""
echo "Next steps:"
echo "1. Paste the outputs above into frontend/src/config.js"
echo "2. Create a test user (see README, section 'Create a demo user')"
echo "3. cd frontend && npm install && npm run dev"
