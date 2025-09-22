#!/bin/bash

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

echo "Waiting for bhm and agent are ready"
echo "oc --kubeconfig ~/hypershift-lab/mgmt-kubeconfig -n hardware-inventory get bmh"
echo "oc --kubeconfig ~/hypershift-lab/mgmt-kubeconfig -n hardware-inventory get agent"
