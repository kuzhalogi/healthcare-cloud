#!/usr/bin/env bash
# Creates a confirmed demo user in the doctors group.
# Usage: ./create-user.sh doctor@demo.com YourPassword123
set -e
EMAIL="$1"
PASSWORD="$2"
GROUP="${3:-doctors}"

if [ -z "$EMAIL" ] || [ -z "$PASSWORD" ]; then
  echo "Usage: ./create-user.sh <email> <password> [group]"
  exit 1
fi

cd terraform
POOL_ID=$(terraform output -raw cognito_user_pool_id)
cd ..

aws cognito-idp admin-create-user \
  --user-pool-id "$POOL_ID" \
  --username "$EMAIL" \
  --message-action SUPPRESS \
  --user-attributes Name=email,Value="$EMAIL" Name=email_verified,Value=true

aws cognito-idp admin-set-user-password \
  --user-pool-id "$POOL_ID" \
  --username "$EMAIL" \
  --password "$PASSWORD" \
  --permanent

aws cognito-idp admin-add-user-to-group \
  --user-pool-id "$POOL_ID" \
  --username "$EMAIL" \
  --group-name "$GROUP"

echo "User $EMAIL created in group $GROUP. You can sign in now."
