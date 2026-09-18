Backend VM1 Fails

Diagnose VM1
az vm run-command invoke \
  --resource-group "$RG2" \
  --name webprod-vm-1 \
  --command-id RunShellScript \
  --scripts '
    systemctl status nginx --no-pager
    ss -lntp | grep :80 || true
  '


  Fix:

az vm run-command invoke \
  --resource-group "$RG2" \
  --name webprod-vm-1 \
  --command-id RunShellScript \
  --scripts "sudo systemctl restart nginx"