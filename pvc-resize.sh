#!/bin/bash

# ==========================================
# Configuration Variables
# ==========================================
BASE_PATH="/home/eis2user/devopstest/pranjal/helm-files"
ENV="uat2"
ENV_PATH="${BASE_PATH}/${ENV}"
NAMESPACE="eisuat2"

HELM_VERSION="3.0.0"
IMAGE_TAG="4.6.28-timezone-domain15-vol-04072026"
CSV_FILE="input.csv" # Ensure this is in the same directory where you run the script

# ==========================================
# Initialize Arrays
# ==========================================
declare -a JOURNEYS
declare -a APP_VERSIONS
declare -a REPLICAS

# Read CSV and populate arrays (skipping the header)
# Assumes the CSV is comma-separated without spaces around the commas
{
  read -r header # Consume the header row
  while IFS=, read -r journey appVersion replicas; do
    # Skip any empty lines
    [[ -z "$journey" ]] && continue
    
    JOURNEYS+=("$journey")
    APP_VERSIONS+=("$appVersion")
    REPLICAS+=("$replicas")
  done
} < "$CSV_FILE"

echo "Parsed ${#JOURNEYS[@]} entries from $CSV_FILE."

# ==========================================
# Execution Loop
# ==========================================

mkdir -p "$ENV_PATH"

# Loop through all array indexes
for i in "${!JOURNEYS[@]}"; do
    JOURNEY="${JOURNEYS[$i]}"
    APP_VERSION="${APP_VERSIONS[$i]}"
    REPLICA_COUNT="${REPLICAS[$i]}"

    # Generate values file name by replacing the first occurrence of 'mule-' with 'values-'
    VALUES_FILE="${JOURNEY/mule-/values-}.yaml"

    echo "==========================================================================================="
    echo "Processing: $JOURNEY"
    echo "==========================================================================================="

    # 1. Fetch values and update the image tag
    cd "$ENV_PATH" || exit 1
    helm get values "$JOURNEY" -n "$NAMESPACE" > "$VALUES_FILE"
    
    # Update image tag using the IMAGE_TAG variable 
    sed -i "s|image: h06vksharbor.corp.ad.sbi/eis2.0/mule-rhel-runtime:.*|image: h06vksharbor.corp.ad.sbi/eis2.0/mule-rhel-runtime:${IMAGE_TAG}|g" "$VALUES_FILE"

    # 2. Create directory and move the updated values file
    mkdir -p "$JOURNEY"
    mv "$VALUES_FILE" "$JOURNEY/"

    # 3. Enter journey directory, pull chart, and update Chart.yaml appVersion
    cd "${ENV_PATH}/${JOURNEY}" || exit 1
    helm pull oci://h06vksharbor.corp.ad.sbi/eis2.0/mule-journey --version "$HELM_VERSION" --untar --insecure-skip-tls-verify
    sed -i "s/^appVersion:.*/appVersion: \"${APP_VERSION}\"/" mule-journey/Chart.yaml

    echo "View appVersion for $JOURNEY..."
    grep "^appVersion:" mule-journey/Chart.yaml
    echo " "

    # 4. Scale down StatefulSet
    echo "-------------------------------------------------------------------------------------------"
    echo "Scaling down statefulset for $JOURNEY before deletion..."
    kubectl scale sts "${JOURNEY}-dr-${NAMESPACE}" -n "$NAMESPACE" --replicas=0

    echo "-------------------------------------------------------------------------------------------"
    echo "Sleep for 60 seconds before deleting statefulset and persistent volume claims..."
    sleep 60

    # 5. Delete StatefulSet
    echo "-------------------------------------------------------------------------------------------"
    echo "Deleting statefulset for $JOURNEY..."
    kubectl delete sts "${JOURNEY}-dr-${NAMESPACE}" -n "$NAMESPACE"
    echo " "

    # 6. Delete PVCs using a nested for-loop based on the CSV Replica count
    echo "Deleting persistent volumeclaim(s) for $JOURNEY..."
    for (( r=0; r<REPLICA_COUNT; r++ )); do
        PVC_NAME="mule-identity-storage-${JOURNEY}-dr-${NAMESPACE}-${r}"
        kubectl delete pvc "$PVC_NAME" -n "$NAMESPACE"
    done

    echo "-------------------------------------------------------------------------------------------"
    echo "Sleep for 60 seconds before helm upgrade install..."
    sleep 60

    # 7. Helm Upgrade Install
    echo "-------------------------------------------------------------------------------------------"
    echo "Doing helm install upgrade for RELEASE_NAME $JOURNEY..."
    helm upgrade --install "$JOURNEY" ./mule-journey --namespace "$NAMESPACE" --insecure-skip-tls-verify -f "$VALUES_FILE"
    echo "-------------------------------------------------------------------------------------------"
    echo " "

done

echo "Automation sequence completed successfully for all deployments."
