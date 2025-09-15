#!/usr/bin/env bash
set -euo pipefail

# Project/region
PROJECT_ID="autodeploydb"
REGION="us-central1"

# Use the default VPC and the default regional subnet
NETWORK="default"
SUBNET="default"                       # default subnet exists in each region incl. us-central1

# Names to create/use
CONNECTOR="cr-liquibase-connector"
RUN_SA="cloud-run-liquibase"           # runtime SA for the job (no key)

# AlloyDB target (your IDs)
INSTANCE_URI="projects/autodeploydb/locations/us-central1/clusters/alloydb-cluster/instances/alloydb-primary"

echo "Setting project..."
gcloud config set project "$PROJECT_ID"

echo "Enabling required APIs (idempotent)..."
gcloud services enable run.googleapis.com vpcaccess.googleapis.com alloydb.googleapis.com

echo "Creating runtime service account (if missing)..."
gcloud iam service-accounts create "$RUN_SA" --display-name="Cloud Run Liquibase SA" || true
RUN_SA_EMAIL="${RUN_SA}@${PROJECT_ID}.iam.gserviceaccount.com"

echo "Granting minimal IAM to runtime SA..."
gcloud projects add-iam-policy-binding "$PROJECT_ID" \
  --member="serviceAccount:${RUN_SA_EMAIL}" --role="roles/alloydb.client" >/dev/null

echo "Creating Serverless VPC Access connector (if needed)..."
gcloud compute networks vpc-access connectors create "$CONNECTOR" \
  --region "$REGION" \
  --network "$NETWORK" \
  --subnet "$SUBNET" || true

echo "Waiting for connector to become READY (this can take a couple minutes)..."
# Poll until READY
until gcloud compute networks vpc-access connectors describe "$CONNECTOR" --region "$REGION" \
       --format="value(state)" | grep -q "READY"; do
  echo "  connector state: $(gcloud compute networks vpc-access connectors describe "$CONNECTOR" --region "$REGION" --format='value(state)')" 
  sleep 10
done
echo "Connector is READY."

echo "Deploying Cloud Run Job from SOURCE (buildpacks, no Dockerfile)..."
# We don't set env here; CI will set/update before execute.
gcloud run jobs deploy liquibase-apply \
  --source . \
  --region "$REGION" \
  --service-account "$RUN_SA_EMAIL" \
  --vpc-connector "projects/${PROJECT_ID}/locations/${REGION}/connectors/${CONNECTOR}" \
  --vpc-egress all-traffic

echo "Done. Verify with:"
echo "  gcloud run jobs describe liquibase-apply --region $REGION"

