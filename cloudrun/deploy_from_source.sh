#!/usr/bin/env bash
set -euo pipefail

# Project/region
PROJECT_ID="autodeploydb"
REGION="us-central1"

# Use the default VPC
NETWORK="default"

# Dedicated subnet just for the connector (must be /28)
SUBNET="serverless-connector-subnet"
SUBNET_RANGE="10.8.0.0/28"   # <- adjust if this collides with your existing ranges

# Names
CONNECTOR="cr-liquibase-connector"
RUN_SA="cloud-run-liquibase"
RUN_SA_EMAIL="${RUN_SA}@${PROJECT_ID}.iam.gserviceaccount.com"

# AlloyDB target
INSTANCE_URI="projects/${PROJECT_ID}/locations/${REGION}/clusters/alloydb-cluster/instances/alloydb-primary"

echo "Setting project..."
gcloud config set project "$PROJECT_ID"

echo "Enable required APIs (idempotent)..."
gcloud services enable run.googleapis.com vpcaccess.googleapis.com alloydb.googleapis.com

echo "Create runtime service account (if missing)..."
gcloud iam service-accounts create "$RUN_SA" --display-name="Cloud Run Liquibase SA" || true

echo "Grant minimal IAM to runtime SA..."
gcloud projects add-iam-policy-binding "$PROJECT_ID" \
  --member="serviceAccount:${RUN_SA_EMAIL}" \
  --role="roles/alloydb.client" >/dev/null

# Ensure /28 subnet exists
if ! gcloud compute networks subnets describe "$SUBNET" --region "$REGION" --project "$PROJECT_ID" >/dev/null 2>&1; then
  echo "Creating /28 subnet [$SUBNET] in VPC [$NETWORK]..."
  gcloud compute networks subnets create "$SUBNET" \
    --network "$NETWORK" \
    --region "$REGION" \
    --range "$SUBNET_RANGE"
else
  echo "Subnet [$SUBNET] already exists."
fi

# Ensure connector exists
if ! gcloud compute networks vpc-access connectors describe "$CONNECTOR" --region "$REGION" >/dev/null 2>&1; then
  echo "Creating connector [$CONNECTOR]..."
  gcloud compute networks vpc-access connectors create "$CONNECTOR" \
    --region "$REGION" \
    --subnet "$SUBNET"
else
  echo "Connector [$CONNECTOR] already exists."
fi

echo "Waiting for connector to be READY..."
for i in {1..60}; do
  state=$(gcloud compute networks vpc-access connectors describe "$CONNECTOR" \
            --region "$REGION" --format='value(state)' 2>/dev/null || true)
  echo "  state: ${state:-<not found>}"
  if [[ "$state" == "READY" ]]; then break; fi
  if [[ -z "$state" ]]; then
    echo "Connector not found; create failed. Exiting."; exit 1
  fi
  sleep 10
done

echo "Deploying Cloud Run Job from source..."
gcloud run jobs deploy liquibase-apply \
  --source . \
  --region "$REGION" \
  --service-account "$RUN_SA_EMAIL" \
  --vpc-connector "projects/${PROJECT_ID}/locations/${REGION}/connectors/${CONNECTOR}" \
  --vpc-egress all-traffic

echo "Done. Verify with:"
echo "  gcloud run jobs describe liquibase-apply --region $REGION"
