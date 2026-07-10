Journey,AppVersion,Replicas
mule-common-journey-internal,1.0.0,2
mule-go-nogo-journey-internal,1.0.21,1

BASE_PATH="/home/eis2user/devopstest/pranjal/helm-files"
ENV="uat2"
ENV_PATH="${BASE_PATH}/${ENV}"
NAMESPACE="eisuat2"

HELM_VERSION="3.0.0"
IMAGE_TAG="4.6.28-timezone-domain15-vol-04072026"

mkdir -p /home/eis2user/devopstest/pranjal/helm-files/uat2
cd /home/eis2user/devopstest/pranjal/helm-files/uat2

helm get values mule-common-journey-internal -n eisuat2 > values-common-journey-internal.yaml
helm get values mule-go-nogo-journey-internal -n eisuat2 > values-go-nogo-journey-internal.yaml

sed -i 's|image: h06vksharbor.corp.ad.sbi/eis2.0/mule-rhel-runtime:.*|image: h06vksharbor.corp.ad.sbi/eis2.0/mule-rhel-runtime:4.6.28-timezone-domain15-vol-04072026|g' values-*.yaml

mkdir mule-common-journey-internal
mkdir mule-go-nogo-journey-internal

mv values-common-journey-internal.yaml mule-common-journey-internal
mv values-go-nogo-journey-internal.yaml mule-go-nogo-journey-internal

cd /home/eis2user/devopstest/pranjal/helm-files/uat2

cd ../mule-common-journey-internal
sed -i 's|image: h06vksharbor.corp.ad.sbi/eis2.0/mule-rhel-runtime:.*|image: h06vksharbor.corp.ad.sbi/eis2.0/mule-rhel-runtime:4.6.28-timezone-domain15-vol-290626|g' values-*.yaml
helm pull oci://h06vksharbor.corp.ad.sbi/eis2.0/mule-journey --version 3.0.0 --untar --insecure-skip-tls-verify
sed -i "s/^appVersion:.*/appVersion: \"1.0.0\"/" mule-journey/Chart.yaml
echo "View appVersion for mule-common-journey-internal..."
cat mule-journey/Chart.yaml | grep appVersion
echo " "

cd ../mule-go-nogo-journey-internal
sed -i 's|image: h06vksharbor.corp.ad.sbi/eis2.0/mule-rhel-runtime:.*|image: h06vksharbor.corp.ad.sbi/eis2.0/mule-rhel-runtime:4.6.28-timezone-domain15-vol-290626|g' values-*.yaml
helm pull oci://h06vksharbor.corp.ad.sbi/eis2.0/mule-journey --version 3.0.0 --untar --insecure-skip-tls-verify
sed -i "s/^appVersion:.*/appVersion: \"1.0.21\"/" mule-journey/Chart.yaml
echo "View appVersion for mule-go-nogo-journey-internal..."
cat mule-journey/Chart.yaml | grep appVersion
echo " "


cd /home/eis2user/devopstest/pranjal/helm-files/uat2

cd ../mule-common-journey-internal
echo "-------------------------------------------------------------------------------------------"
echo "Scaling down statefulset for mule-common-journey-internal before deletion..."
kubectl scale sts "mule-common-journey-internal-dr-eisuat2" -n eisuat2 --replicas=0
echo "-------------------------------------------------------------------------------------------"
echo "Sleep for 60 seconds before deleting statefulset and persistent volume claims..."
sleep 60
echo "-------------------------------------------------------------------------------------------"
echo "Deleting statefulset for mule-common-journey-internal..."
kubectl delete sts "mule-common-journey-internal-dr-eisuat2" -n eisuat2
echo " "
echo "Deleting persistent volumeclaim for mule-common-journey-internal..."
# Deleting 2 pvcs since there are 2 replicas in this one. Need to create a for loop logic for this
kubectl delete pvc "mule-identity-storage-mule-common-journey-internal-dr-eisuat2-0" -n eisuat2
kubectl delete pvc "mule-identity-storage-mule-common-journey-internal-dr-eisuat2-1" -n eisuat2
echo "-------------------------------------------------------------------------------------------"
echo "Sleep for 60 seconds before helm upgrade install..."
sleep 60
echo "-------------------------------------------------------------------------------------------"
echo "Doing helm install upgrade for RELEASE_NAME mule-common-journey-internal..."
helm upgrade --install "mule-common-journey-internal" ./mule-journey --namespace eisuat2 --insecure-skip-tls-verify -f "values-common-journey-internal.yaml"
echo "-------------------------------------------------------------------------------------------"
echo " "


cd ../mule-go-nogo-journey-internal
echo "-------------------------------------------------------------------------------------------"
echo "Scaling down statefulset for mule-go-nogo-journey-internal before deletion..."
kubectl scale sts "mule-go-nogo-journey-internal-dr-eisuat2" -n eisuat2 --replicas=0
echo "-------------------------------------------------------------------------------------------"
echo "Sleep for 60 seconds before deletion..."
sleep 60
echo "-------------------------------------------------------------------------------------------"
echo "Deleting statefulset for mule-go-nogo-journey-internal..."
kubectl delete sts "mule-go-nogo-journey-internal-dr-eisuat2" -n eisuat2
echo " "
echo "Deleting persistent volumeclaim for mule-common-journey-internal..."
# Deleting 1 pvcs since there are 1 replica in this one.
kubectl delete pvc "mule-identity-storage-mule-go-nogo-journey-internal-dr-eisuat2-0" -n eisuat2
echo "-------------------------------------------------------------------------------------------"
echo "Sleep for 60 seconds before helm upgrade install..."
sleep 60
echo "-------------------------------------------------------------------------------------------"
echo "Doing helm install upgrade for RELEASE_NAME mule-go-nogo-journey-internal..."
helm upgrade --install "mule-go-nogo-journey-internal" ./mule-journey --namespace eisuat2 --insecure-skip-tls-verify -f "values-go-nogo-journey-internal.yaml"
echo "-------------------------------------------------------------------------------------------"
echo " "
