#!/bin/bash

RG2="rg-ha-web-lab"

echo "Deleting resource group: $RG2"

az group delete \
  --name "$RG2" \
  --yes \
  --no-wait

echo "Deletion request submitted."

# This script deletes the specified Azure resource group using the Azure CLI. It takes the resource group name as an argument and confirms the deletion without prompting for user confirmation. The deletion is performed asynchronously, allowing the script to exit immediately after submitting the deletion request.
 