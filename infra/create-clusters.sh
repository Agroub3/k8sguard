#!/bin/bash
set -e

CLUSTERS=("k8sguard-dev" "k8sguard-staging" "k8sguard-prod")
CALICO_VERSION="v3.28.0"

for name in "${CLUSTERS[@]}"; do
  if kind get clusters 2>/dev/null | grep -qx "$name"; then
    echo ">>> $name existe déjà, on passe à la suite"
  else
    echo ">>> Création du cluster $name"
    kind create cluster --name "$name" --config infra/kind-config.yaml

    echo ">>> Installation de Calico sur $name"
    kubectl --context "kind-$name" apply -f \
      "https://raw.githubusercontent.com/projectcalico/calico/${CALICO_VERSION}/manifests/calico.yaml"

    echo ">>> Attente que Calico soit prêt sur $name (patience sur VirtualBox)"
    kubectl --context "kind-$name" wait --for=condition=Ready pods \
      -l k8s-app=calico-node -n kube-system --timeout=400s
  fi

  echo ">>> Vérification des namespaces sur $name"
  kubectl --context "kind-$name" create namespace target-apps --dry-run=client -o yaml | kubectl --context "kind-$name" apply -f -
  kubectl --context "kind-$name" create namespace security-tools --dry-run=client -o yaml | kubectl --context "kind-$name" apply -f -

  echo ">>> $name prêt."
  echo ""
done

echo "Les 3 clusters sont prêts. Contextes disponibles :"
kubectl config get-contexts
