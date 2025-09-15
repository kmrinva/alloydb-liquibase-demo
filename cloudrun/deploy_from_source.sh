#!/usr/bin/env bash
set -euo pipefail

# ===== FIX THESE TWO NAMES TO MATCH YOUR VPC =====
NETWORK="default"
SUBNET="default"        # must be in us-central1
# ================================================

PROJECT_ID="autodeploydb"
REGION="us-central1"
CONNECTOR="cr-liquibase-connector"
RUN_SA="cloud-run-liquibase"

# AlloyDB target (your IDs)
INSTANCE_URI="projects/autodeploydb/locations/us-central1/clusters/alloydb-cluster/instances/alloydb-primary"

gcloud config set project "$PROJECT_ID"

echo "Enable required APIs..."
gcloud services enable \
  run.googleapis.com \
  vpcaccess.googleapis.com \
  alloydb.googleapis.com

echo "Create runtime service account (if missing)..."
gcloud iam service-accounts create "$RUN_SA" \
  --display-name="Cloud Run Liquibase SA" || true
RUN_SA_EMAIL="${RUN_SA}@${PROJECT_ID}.iam.gserviceaccount.com"

echo "Grant minimal IAM to runtime SA..."
# Needed to run the AlloyDB Auth Proxy to private IP
gcloud projects add-iam-policy-binding "$PROJECT_ID" \
  --member="serviceAccount:${RUN_SA_EMAIL}" --role="roles/alloydb.client" >/dev/null

echo "Create Serverless VPC Access connector (if needed)..."
gcloud compute networks vpc-access connectors create "$CONNECTOR" \
  --region "$REGION" \
  --network "$NETWORK" \
  --subnet "$SUBNET" || true
# Wait for the connector to become READY before first job execution.

echo "Deploy Cloud Run Job from SOURCE (no envs baked; we pass at execute time)..."
gcloud run jobs deploy liquibase-apply \
  --source . \
  --region "$REGION" \
  --service-account "$RUN_SA_EMAIL" \
