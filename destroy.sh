#!/usr/bin/env bash
# Delete the application stack. The bootstrap stack (state bucket, CI role)
# survives on purpose. Destroying it would orphan every resource in AWS.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$ROOT/terraform"

terraform destroy -auto-approve

echo ""
echo "Application stack destroyed. Running cost is now zero."
echo "The state bucket and CI role remain. Both are free when idle."
