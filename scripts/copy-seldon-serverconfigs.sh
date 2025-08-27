#!/bin/bash

# Script: copy-seldon-serverconfigs.sh
# Purpose: Copy Seldon ServerConfig resources from seldon-system to application namespace
# Usage: ./copy-seldon-serverconfigs.sh [namespace]
# 
# This is a WORKAROUND for Seldon Core v2.9.1 bug where cross-namespace 
# ServerConfig references don't work properly.
#
# Issue: Server resources cannot reference "seldon-system/mlserver-config"
# Solution: Copy ServerConfigs to the application namespace

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Get namespace from argument or current context
if [ $# -eq 1 ]; then
    NAMESPACE=$1
else
    NAMESPACE=$(kubectl config view --minify -o jsonpath='{..namespace}')
    if [ -z "$NAMESPACE" ]; then
        NAMESPACE="default"
    fi
fi

echo -e "${GREEN}=== Seldon ServerConfig Copy Tool ===${NC}"
echo -e "Copying ServerConfigs from ${YELLOW}seldon-system${NC} to ${YELLOW}$NAMESPACE${NC}"
echo ""

# Check if source namespace exists
if ! kubectl get namespace seldon-system &>/dev/null; then
    echo -e "${RED}Error: seldon-system namespace not found!${NC}"
    echo "Please ensure Seldon Core is installed in your cluster."
    exit 1
fi

# Create target namespace if it doesn't exist
if ! kubectl get namespace $NAMESPACE &>/dev/null; then
    echo -e "${YELLOW}Creating namespace $NAMESPACE...${NC}"
    kubectl create namespace $NAMESPACE
fi

# List of standard ServerConfigs to copy
SERVERCONFIGS="mlserver mlserver-config triton"
COPIED=0
FAILED=0

echo "Copying ServerConfigs..."
for config in $SERVERCONFIGS; do
    if kubectl get serverconfig $config -n seldon-system &>/dev/null; then
        echo -n "  • Copying $config... "
        if kubectl get serverconfig $config -n seldon-system -o yaml | \
           sed "s/namespace: seldon-system/namespace: $NAMESPACE/" | \
           sed '/resourceVersion:/d' | \
           sed '/uid:/d' | \
           sed '/selfLink:/d' | \
           kubectl apply -f - &>/dev/null; then
            echo -e "${GREEN}✓${NC}"
            ((COPIED++))
        else
            echo -e "${RED}✗${NC}"
            ((FAILED++))
        fi
    else
        echo "  • Skipping $config (not found in seldon-system)"
    fi
done

echo ""
echo -e "${GREEN}Summary:${NC}"
echo "  • ServerConfigs copied: $COPIED"
if [ $FAILED -gt 0 ]; then
    echo -e "  • ${RED}Failed: $FAILED${NC}"
fi

# Verify the copies
echo ""
echo "Verifying ServerConfigs in $NAMESPACE:"
kubectl get serverconfig -n $NAMESPACE --no-headers 2>/dev/null | while read line; do
    echo "  • $line"
done

echo ""
echo -e "${GREEN}Next Steps:${NC}"
echo "1. Update your Server resources to reference ServerConfigs without namespace prefix:"
echo "   spec:"
echo "     serverConfig: mlserver-config  # NOT seldon-system/mlserver-config"
echo ""
echo "2. Apply your Server and Model resources:"
echo "   kubectl apply -f your-server.yaml -n $NAMESPACE"
echo ""
echo -e "${YELLOW}Note:${NC} This is a workaround for Seldon v2.9.1 bug."
echo "See: docs/seldon-v2-known-issues.md for more information."