#!/usr/bin/env bash
# One command to delete everything so you stop paying.
set -e
cd terraform
terraform destroy -auto-approve
echo ""
echo "==> All resources destroyed. Your AWS bill for this project is now zero."
