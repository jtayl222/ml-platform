#!/bin/bash
# Systematic Helm chart investigation

CHART_NAME="seldon/seldon-core-v2-runtime"
RELEASE_NAME="seldon-core-v2-runtime"
NAMESPACE="seldon-system"

echo "=== Systematic Helm Chart Investigation ==="
echo "Chart: $CHART_NAME"
echo "Release: $RELEASE_NAME"
echo

echo "1. Get the COMPLETE default values (not just user overrides):"
echo "============================================================"
helm show values "$CHART_NAME" > /tmp/seldon-default-values.yaml
echo "Saved to: /tmp/seldon-default-values.yaml"

echo
echo "2. Search for clusterwide configuration:"
echo "======================================="
grep -n -A5 -B5 -i "cluster\|wide" /tmp/seldon-default-values.yaml || echo "No clusterwide found in default values"

echo
echo "3. Check what's actually deployed vs defaults:"
echo "============================================="
helm get values "$RELEASE_NAME" -n "$NAMESPACE" --all > /tmp/seldon-current-values.yaml
echo "Current values saved to: /tmp/seldon-current-values.yaml"

echo
echo "4. Compare default vs current for clusterwide:"
echo "=============================================="
echo "=== DEFAULT VALUES ==="
grep -A5 -B5 -i "cluster\|wide" /tmp/seldon-default-values.yaml | head -20
echo
echo "=== CURRENT VALUES ==="
grep -A5 -B5 -i "cluster\|wide" /tmp/seldon-current-values.yaml | head -20

echo
echo "5. Inspect the actual rendered templates:"
echo "========================================"
helm template test-seldon "$CHART_NAME" \
  --set controller.clusterwide=true \
  --namespace "$NAMESPACE" > /tmp/seldon-rendered.yaml
echo "Rendered templates saved to: /tmp/seldon-rendered.yaml"

echo
echo "6. Find CLUSTERWIDE in rendered output:"
echo "======================================"
grep -n -A2 -B2 "CLUSTERWIDE" /tmp/seldon-rendered.yaml || echo "No CLUSTERWIDE found in rendered templates"

echo
echo "7. Try different value paths and see what renders:"
echo "================================================"
for path in "clusterwide" "controller.clusterwide" "controllerManager.clusterwide" "manager.clusterwide"; do
    echo "Testing: --set $path=true"
    helm template test-seldon "$CHART_NAME" --set "$path=true" 2>/dev/null | grep -q "CLUSTERWIDE.*true" && echo "  ✅ $path WORKS!" || echo "  ❌ $path failed"
done

echo
echo "8. Files created for manual inspection:"
echo "======================================"
echo "- /tmp/seldon-default-values.yaml"
echo "- /tmp/seldon-current-values.yaml" 
echo "- /tmp/seldon-rendered.yaml"
echo
echo "Manual inspection commands:"
echo "yq '.controller' /tmp/seldon-default-values.yaml"
echo "yq '.controllerManager' /tmp/seldon-default-values.yaml"
echo "grep -A10 -B10 'CLUSTERWIDE' /tmp/seldon-rendered.yaml"