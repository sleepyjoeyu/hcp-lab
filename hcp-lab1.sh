#!/bin/bash

admin-passwd=BFRCY8NWIWG3Q3sa

# Lab-create openshift-install dir
mkdir -p ~/hypershift-lab/


# Lab-login and create kubeconfig for management cluster
oc --kubeconfig ~/hypershift-lab/mgmt-kubeconfig login -u admin \
    -p $admin-passwd https://api.management.hypershift.lab:6443 \
    --insecure-skip-tls-verify=true

# Lab-install mce
cat <<EOF | oc --kubeconfig ~/hypershift-lab/mgmt-kubeconfig apply -f -
---
apiVersion: v1
kind: Namespace
metadata:
  labels:
    openshift.io/cluster-monitoring: "true"
  name: multicluster-engine
---
apiVersion: operators.coreos.com/v1
kind: OperatorGroup
metadata:
  name: multicluster-engine-operatorgroup
  namespace: multicluster-engine
spec:
  targetNamespaces:
  - multicluster-engine
---
apiVersion: operators.coreos.com/v1alpha1
kind: Subscription
metadata:
  name: multicluster-engine
  namespace: multicluster-engine
spec:
  channel: "stable-2.8"
  name: multicluster-engine
  source: redhat-operators
  sourceNamespace: openshift-marketplace
EOF

oc --kubeconfig ~/hypershift-lab/mgmt-kubeconfig -n multicluster-engine \
    wait --for=jsonpath='{.status.state}'=AtLatestKnown \
    subscription/multicluster-engine --timeout=300s

oc --kubeconfig ~/hypershift-lab/mgmt-kubeconfig -n multicluster-engine get pods

cat <<EOF | oc --kubeconfig ~/hypershift-lab/mgmt-kubeconfig apply -f -
---
apiVersion: multicluster.openshift.io/v1
kind: MultiClusterEngine
metadata:
  name: multiclusterengine
spec:
  availabilityConfig: Basic
  targetNamespace: multicluster-engine
EOF

oc --kubeconfig ~/hypershift-lab/mgmt-kubeconfig wait \
    --for=jsonpath='{.status.phase}'=Available \
    multiclusterengine/multiclusterengine --timeout=300s

oc --kubeconfig ~/hypershift-lab/mgmt-kubeconfig -n hypershift get pods

# Lab-config bare metal operator
oc --kubeconfig ~/hypershift-lab/mgmt-kubeconfig patch \
    provisioning/provisioning-configuration \
    -p '{"spec":{"watchAllNamespaces":true}}' --type merge

# Lab-config assisted service
cat <<EOF | oc --kubeconfig ~/hypershift-lab/mgmt-kubeconfig apply -f -
---
apiVersion: agent-install.openshift.io/v1beta1
kind: AgentServiceConfig
metadata:
  namespace: multicluster-engine
  name: agent
spec:
  databaseStorage:
    storageClassName: lvms-vg1
    accessModes:
      - ReadWriteOnce
    resources:
      requests:
        storage: 10Gi
  filesystemStorage:
    storageClassName: lvms-vg1
    accessModes:
      - ReadWriteOnce
    resources:
      requests:
        storage: 20Gi
  osImages:
    - openshiftVersion: "4.18"
      url: "https://mirror.openshift.com/pub/openshift-v4/dependencies/rhcos/4.18/4.18.1/rhcos-4.18.1-x86_64-live.x86_64.iso"
      rootFSUrl: "https://mirror.openshift.com/pub/openshift-v4/dependencies/rhcos/4.18/4.18.1/rhcos-4.18.1-x86_64-live-rootfs.x86_64.img"
      cpuArchitecture: "x86_64"
      version: "418.94.202503061016-0"
EOF

oc --kubeconfig ~/hypershift-lab/mgmt-kubeconfig -n multicluster-engine \
    wait --for=condition=DeploymentsHealthy \
    agentserviceconfig/agent --timeout=300s

oc --kubeconfig ~/hypershift-lab/mgmt-kubeconfig -n multicluster-engine get pods\
   --selector 'app in (assisted-image-service,assisted-service)'

# Lab-enable MCE option

oc --kubeconfig ~/hypershift-lab/mgmt-kubeconfig label clusterimageset \
    img4.18.4-x86-64-appsub visible=true --overwrite

# Lab-create h/w inventor

oc --kubeconfig ~/hypershift-lab/mgmt-kubeconfig create \
    namespace hardware-inventory

# Lab-create pull-secret
oc --kubeconfig ~/hypershift-lab/mgmt-kubeconfig -n openshift-config get \
    secret pull-secret -o yaml | grep -vE "uid|resourceVersion|creationTimestamp|namespace" \
    | sed "s/openshift-config/hardware-inventory/g" | oc --kubeconfig ~/hypershift-lab/mgmt-kubeconfig \
    -n hardware-inventory apply -f -

# Lab-cate infraEnv

cat <<EOF | oc --kubeconfig ~/hypershift-lab/mgmt-kubeconfig apply -f -
---
apiVersion: agent-install.openshift.io/v1beta1
kind: InfraEnv
metadata:
  name: hosted
  namespace: hardware-inventory
spec:
  additionalNTPSources:
  - 192.168.125.1
  pullSecretRef:
    name: pull-secret
  sshAuthorizedKey: ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAACAQC5pFKFLOuxrd9Q/TRu9sRtwGg2PV+kl2MHzBIGUhCcR0LuBJk62XG9tQWPQYTQ3ZUBKb6pRTqPXg+cDu5FmcpTwAKzqgUb6ArnjECxLJzJvWieBJ7k45QzhlZPeiN2Omik5bo7uM/P1YIo5pTUdVk5wJjaMOb7Xkcmbjc7r22xY54cce2Wb7B1QDtLWJkq++eJHSX2GlEjfxSlEvQzTN7m2N5pmoZtaXpLKcbOqtuSQSVKC4XPgb57hgEs/ZZy/LbGGHZyLAW5Tqfk1JCTFGm6Q+oOd3wAOF1SdUxM7frdrN3UOB12u/E6YuAx3fDvoNZvcrCYEpjkfrsjU91oz78aETZV43hOK9NWCOhdX5djA7G35/EMn1ifanVoHG34GwNuzMdkb7KdYQUztvsXIC792E2XzWfginFZha6kORngokZ2DwrzFj3wgvmVyNXyEOqhwi6LmlsYdKxEvUtiYhdISvh2Y9GPrFcJ5DanXe7NVAKXe5CyERjBnxWktqAPBzXJa36FKIlkeVF5G+NWgufC6ZWkDCD98VZDiPP9sSgqZF8bSR4l4/vxxAW4knKIZv11VX77Sa1qZOR9Ml12t5pNGT7wDlSOiDqr5EWsEexga/2s/t9itvfzhcWKt+k66jd8tdws2dw6+8JYJeiBbU63HBjxCX+vCVZASrNBjiXhFw==
EOF

echo "wait couple seconds for iso generation"
echo "oc --kubeconfig ~/hypershift-lab/mgmt-kubeconfig -n hardware-inventory \
    get infraenv hosted"

# Lab-create bare metalhost - secret, BMH, RBAC

cat <<EOF | oc --kubeconfig ~/hypershift-lab/mgmt-kubeconfig apply -f -
apiVersion: v1
kind: Secret
metadata:
  name: hosted-worker0-bmc-secret
  namespace: hardware-inventory
data:
  password: YWRtaW4=
  username: YWRtaW4=
type: Opaque
---
apiVersion: v1
kind: Secret
metadata:
  name: hosted-worker1-bmc-secret
  namespace: hardware-inventory
data:
  password: YWRtaW4=
  username: YWRtaW4=
type: Opaque
---
apiVersion: v1
kind: Secret
metadata:
  name: hosted-worker2-bmc-secret
  namespace: hardware-inventory
data:
  password: YWRtaW4=
  username: YWRtaW4=
type: Opaque
---
apiVersion: metal3.io/v1alpha1
kind: BareMetalHost
metadata:
  name: hosted-worker0
  namespace: hardware-inventory
  labels:
    infraenvs.agent-install.openshift.io: hosted
  annotations:
    inspect.metal3.io: disabled
    bmac.agent-install.openshift.io/hostname: hosted-worker0
spec:
  automatedCleaningMode: disabled
  bmc:
    disableCertificateVerification: True
    address: redfish-virtualmedia://192.168.125.1:9000/redfish/v1/Systems/local/hosted-worker0
    credentialsName: hosted-worker0-bmc-secret
  bootMACAddress: aa:aa:aa:aa:02:01
  online: true
---
apiVersion: metal3.io/v1alpha1
kind: BareMetalHost
metadata:
  name: hosted-worker1
  namespace: hardware-inventory
  labels:
    infraenvs.agent-install.openshift.io: hosted
  annotations:
    inspect.metal3.io: disabled
    bmac.agent-install.openshift.io/hostname: hosted-worker1
spec:
  automatedCleaningMode: disabled
  bmc:
    disableCertificateVerification: True
    address: redfish-virtualmedia://192.168.125.1:9000/redfish/v1/Systems/local/hosted-worker1
    credentialsName: hosted-worker1-bmc-secret
  bootMACAddress: aa:aa:aa:aa:02:02
  online: true
---
apiVersion: metal3.io/v1alpha1
kind: BareMetalHost
metadata:
  name: hosted-worker2
  namespace: hardware-inventory
  labels:
    infraenvs.agent-install.openshift.io: hosted
  annotations:
    inspect.metal3.io: disabled
    bmac.agent-install.openshift.io/hostname: hosted-worker2
spec:
  automatedCleaningMode: disabled
  bmc:
    disableCertificateVerification: True
    address: redfish-virtualmedia://192.168.125.1:9000/redfish/v1/Systems/local/hosted-worker2
    credentialsName: hosted-worker2-bmc-secret
  bootMACAddress: aa:aa:aa:aa:02:03
  online: true
---
apiVersion: rbac.authorization.k8s.io/v1
kind: Role
metadata:
  name: capi-provider-role
  namespace: hardware-inventory
rules:
- apiGroups:
  - agent-install.openshift.io
  resources:
  - agents
  verbs:
  - '*'
EOF


oc --kubeconfig ~/hypershift-lab/mgmt-kubeconfig -n hardware-inventory get bmh
oc --kubeconfig ~/hypershift-lab/mgmt-kubeconfig -n hardware-inventory get agent
