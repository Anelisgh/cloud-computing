$resourceGroup = "tema2-bicep"
$location = "swedencentral"
$sqlAdminUser = "anelisgh"
$sqlAdminPassword = "Parola_homework2!"

Write-Host "SE INCEPE DEPLOYMENT-UL" -ForegroundColor Green

Write-Host "`n[1/5] Se creaza resource group..." -ForegroundColor Cyan
az group create --name $resourceGroup --location $location --output none

Write-Host "[2/5] Se deploy infrastructura cu Bicep..." -ForegroundColor Cyan

az deployment group create `
    --resource-group $resourceGroup `
    --template-file main.bicep `
    --parameters `
        sqlAdminUser=$sqlAdminUser `
        sqlAdminPassword=$sqlAdminPassword `
    --output none

Write-Host "[3/5] Se obtin detaliile resurselor create..." -ForegroundColor Cyan

$appName = az deployment group show `
    --resource-group $resourceGroup `
    --name main `
    --query properties.outputs.appName.value `
    --output tsv

$sqlServerName = az deployment group show `
    --resource-group $resourceGroup `
    --name main `
    --query properties.outputs.sqlServerName.value `
    --output tsv

$appUrl = az deployment group show `
    --resource-group $resourceGroup `
    --name main `
    --query properties.outputs.appUrl.value `
    --output tsv

Write-Host "App Name: $appName" -ForegroundColor Gray
Write-Host "SQL Server: $sqlServerName" -ForegroundColor Gray

Write-Host "[4/5] Se configureaza SQL Firewall cu IP-urile App Service..." -ForegroundColor Cyan

Start-Sleep -Seconds 20

# Stergem regula placeholder din Bicep
az sql server firewall-rule delete `
    --resource-group $resourceGroup `
    --server $sqlServerName `
    --name "AllowAppServiceIPs" `
    --yes 2>$null

# Stergem si regula default Azure
az sql server firewall-rule delete `
    --resource-group $resourceGroup `
    --server $sqlServerName `
    --name "AllowAllWindowsAzureIps" `
    --yes 2>$null

# Obtinem toate IP-urile posibile pentru ca am avut eroarea Eroare: ('42000', "[42000] [Microsoft][ODBC Driver 18 for SQL Server][SQL Server]Cannot open server 'sqlserver-tema2-157288' requested by the login. Client with IP address '74.241.164.139' is not allowed to access the server. To enable access, use the Azure Management Portal or run sp_set_firewall_rule on the master database to create a firewall rule for this IP address or address range. It may take up to five minutes for this change to take effect. (40615) (SQLDriverConnect)")
Write-Host "   Se iau toate IP-urile posibile ale App Service..."
$allIps = az webapp show `
    --resource-group $resourceGroup `
    --name $appName `
    --query "possibleOutboundIpAddresses" `
    --output tsv

$ipArray = $allIps -split ","
Write-Host "   S-au gasit $($ipArray.Count) IP-uri" -ForegroundColor Gray

# Adaugam fiecare IP in firewall
foreach ($ip in $ipArray) {
    $ip = $ip.Trim()
    $ruleName = "Allow_" + ($ip -replace '\.', '-')
    
    az sql server firewall-rule create `
        --resource-group $resourceGroup `
        --server $sqlServerName `
        --name $ruleName `
        --start-ip-address $ip `
        --end-ip-address $ip `
        --output none 2>$null
}

Write-Host "Toate IP-urile au fost adaugate in firewall" -ForegroundColor Green

Write-Host "[5/5] Se face deploy la codul aplicatiei..." -ForegroundColor Cyan

# Verificam fisierele
if (-Not (Test-Path "app.py")) { 
    Write-Host "EROARE: app.py lipseste!" -ForegroundColor Red
    exit 1 
}
if (-Not (Test-Path "requirements.txt")) { 
    Write-Host "EROARE: requirements.txt lipseste!" -ForegroundColor Red
    exit 1 
}
if (-Not (Test-Path "templates\index.html")) { 
    Write-Host "EROARE: templates\index.html lipseste!" -ForegroundColor Red
    exit 1 
}

# Stergem ZIP vechi
if (Test-Path "deploy.zip") { Remove-Item "deploy.zip" -Force }

# Cream ZIP cu paths corecte pentru Linux
Write-Host "   Se creaza ZIP..." -ForegroundColor Gray

$pythonScript = @"
import zipfile
import os

with zipfile.ZipFile('deploy.zip', 'w', zipfile.ZIP_DEFLATED) as zipf:
    zipf.write('app.py', 'app.py')
    zipf.write('requirements.txt', 'requirements.txt')
    zipf.write(os.path.join('templates', 'index.html'), 'templates/index.html')

print('ZIP created')
"@

$pythonScript | Out-File -FilePath "create_zip.py" -Encoding UTF8
python create_zip.py
Remove-Item "create_zip.py" -Force

# Deploy ZIP
Write-Host "   Se uploadeaza codul..." -ForegroundColor Gray
az webapp deploy `
    --resource-group $resourceGroup `
    --name $appName `
    --src-path deploy.zip `
    --type zip `
    --output none

# Asteptam ca aplicatia sa porneasca
Write-Host "   Asteptare pornire aplicatie (45 sec)..." -ForegroundColor Gray
Start-Sleep -Seconds 45

# Final output
Write-Host "`n DEPLOYMENT COMPLET" -ForegroundColor Green

Write-Host "`nResurse create prin Bicep:"
Write-Host "- Resource Group: $resourceGroup"
Write-Host "- App Service Plan: asp-tema2 (definit in main.bicep)"
Write-Host "- Web App: $appName"
Write-Host "- SQL Server: $sqlServerName"
Write-Host "- SQL Database: ItemsDB"
Write-Host "- Firewall Rules: $($ipArray.Count) reguli pentru App Service IPs"

Write-Host "`nApp URL: $appUrl" -ForegroundColor Cyan

Write-Host "`nPentru logs:"
Write-Host "az webapp log tail --name $appName --resource-group $resourceGroup" -ForegroundColor Gray