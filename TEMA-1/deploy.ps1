$ResourceGroup = "rg-static-website"
# pentru unicitate
$StorageAccount = "portfolio$(Get-Date -Format 'yyyyMMddHHmmss')"
$Location = "westeurope"

Write-Host "Se creează resource group..." -ForegroundColor Green
az group create --name $ResourceGroup --location $Location

Write-Host "Se creează storage account..." -ForegroundColor Green
az storage account create --name $StorageAccount --resource-group $ResourceGroup --location $Location --sku Standard_LRS --kind StorageV2

Write-Host "Se activeză static website hosting..." -ForegroundColor Green
az storage blob service-properties update --account-name $StorageAccount --static-website --index-document index.html --404-document index.html

Write-Host "Se încarcă fișierele..." -ForegroundColor Green
az storage blob upload-batch --account-name $StorageAccount --source ./website --destination '$web' --overwrite

Write-Host "===========================================" -ForegroundColor Cyan
Write-Host "Site-ul este live la adresa:" -ForegroundColor Green
az storage account show --name $StorageAccount --resource-group $ResourceGroup --query "primaryEndpoints.web" --output tsv
Write-Host "===========================================" -ForegroundColor Cyan
