#!/bin/bash
set -e

for ctx in kind-k8sguard-dev kind-k8sguard-staging kind-k8sguard-prod; do
  echo ""
  echo "=== Test NetworkPolicy sur $ctx ==="

  kubectl --context "$ctx" create namespace test-a --dry-run=client -o yaml | kubectl --context "$ctx" apply -f -
  kubectl --context "$ctx" create namespace test-b --dry-run=client -o yaml | kubectl --context "$ctx" apply -f -

  kubectl --context "$ctx" run pod-a -n test-a --image=busybox --restart=Never --command -- sleep 3600 2>/dev/null || true
  kubectl --context "$ctx" run pod-b -n test-b --image=busybox --restart=Never --command -- sleep 3600 2>/dev/null || true

  echo "Attente que les pods soient prêts..."
  kubectl --context "$ctx" wait --for=condition=Ready pod/pod-a -n test-a --timeout=60s
  kubectl --context "$ctx" wait --for=condition=Ready pod/pod-b -n test-b --timeout=60s

  IP_B=$(kubectl --context "$ctx" get pod pod-b -n test-b -o jsonpath='{.status.podIP}')

  echo "-- AVANT policy (doit réussir) --"
  kubectl --context "$ctx" exec -n test-a pod-a -- ping -c 2 -W 2 "$IP_B" && echo "OK : trafic autorisé, comme attendu"

  kubectl --context "$ctx" apply -n test-b -f - <<EOF
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: default-deny
spec:
  podSelector: {}
  policyTypes: ["Ingress", "Egress"]
EOF

  sleep 3
  echo "-- APRÈS policy (doit échouer) --"
  if kubectl --context "$ctx" exec -n test-a pod-a -- ping -c 2 -W 2 "$IP_B" 2>/dev/null; then
    echo "⚠️  PROBLÈME : le trafic passe encore après la policy sur $ctx"
  else
    echo "✅ Bloqué comme attendu sur $ctx"
  fi

  kubectl --context "$ctx" delete namespace test-a test-b --wait=false
done

echo ""
echo "Tests terminés sur les 3 clusters."
