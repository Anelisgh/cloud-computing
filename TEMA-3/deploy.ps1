$resourceGroup = "tema3-rg"
$location = "swedencentral"
$appName = "webapp-tema3-" + (Get-Random -Maximum 999999)
$planName = "asp-tema3"
$sqlServer = "sqlserver-tema3-" + (Get-Random -Maximum 999999)
$dbName = "ItemsDB"
$adminUser = "anelisgh"
$adminPass = "Parola_homework3!"
$appInsightsName = "appinsights-tema3-" + (Get-Random -Maximum 999999)

# 1. Resource Group
Write-Host "`n[1/8] Se creaza resource group..." -ForegroundColor Cyan
az group create --name $resourceGroup --location $location --output none

# 2. Application Insights
Write-Host "[2/8] Se creaza Application Insights..." -ForegroundColor Cyan
az monitor app-insights component create --app $appInsightsName --location $location --resource-group $resourceGroup --application-type web --output none

$appInsightsConnectionString = az monitor app-insights component show --app $appInsightsName --resource-group $resourceGroup --query "connectionString" --output tsv
$appInsightsKey = az monitor app-insights component show --app $appInsightsName --resource-group $resourceGroup --query "instrumentationKey" --output tsv

# 3. SQL Server
Write-Host "[3/8] Se creaza SQL Server..." -ForegroundColor Cyan
az sql server create --name $sqlServer --resource-group $resourceGroup --location $location --admin-user $adminUser --admin-password $adminPass --output none

# 4. Database
Write-Host "[4/8] Se creaza database..." -ForegroundColor Cyan
az sql db create --resource-group $resourceGroup --server $sqlServer --name $dbName --service-objective Basic --output none

# 5. App Service Plan
Write-Host "[5/8] Se creaza App Service Plan..." -ForegroundColor Cyan
az appservice plan create --name $planName --resource-group $resourceGroup --sku F1 --is-linux --output none

# 6. Web App
Write-Host "[6/8] Se creaza Web App..." -ForegroundColor Cyan
az webapp create --resource-group $resourceGroup --plan $planName --name $appName --runtime "PYTHON:3.11" --output none

Start-Sleep -Seconds 10

# Configurare App Insights
az webapp config appsettings set --name $appName --resource-group $resourceGroup --settings "APPLICATIONINSIGHTS_CONNECTION_STRING=$appInsightsConnectionString" "APPINSIGHTS_INSTRUMENTATIONKEY=$appInsightsKey" "ApplicationInsightsAgent_EXTENSION_VERSION=~3" --output none

# 7. Firewall SQL
Write-Host "[7/8] Se configureaza firewall SQL..." -ForegroundColor Cyan
az sql server firewall-rule delete --resource-group $resourceGroup --server $sqlServer --name "AllowAllWindowsAzureIps" --yes 2>$null

$allIps = az webapp show --resource-group $resourceGroup --name $appName --query "possibleOutboundIpAddresses" --output tsv
$ipArray = $allIps -split ","

foreach ($ip in $ipArray) {
    $ip = $ip.Trim()
    $ruleName = "Allow_" + ($ip -replace '\.', '-')
    az sql server firewall-rule create --resource-group $resourceGroup --server $sqlServer --name $ruleName --start-ip-address $ip --end-ip-address $ip --output none 2>$null
}

$connectionString = "Driver={ODBC Driver 18 for SQL Server};Server=tcp:${sqlServer}.database.windows.net,1433;Database=${dbName};Uid=${adminUser};Pwd=${adminPass};Encrypt=yes;TrustServerCertificate=no;Connection Timeout=30;"

az webapp config appsettings set --name $appName --resource-group $resourceGroup --settings "SQL_CONNECTION_STR=$connectionString" "SCM_DO_BUILD_DURING_DEPLOYMENT=true" --output none

az webapp config set --resource-group $resourceGroup --name $appName --startup-file "gunicorn --bind=0.0.0.0 --timeout 600 app:app" --output none

# 8. Deploy cod
Write-Host "[8/8] Se face deploy la cod..." -ForegroundColor Cyan

# Stergem zip vechi daca exista
if (Test-Path "deploy.zip") { Remove-Item "deploy.zip" -Force }

$pythonScript = @"
import zipfile
import os

with zipfile.ZipFile('deploy.zip', 'w', zipfile.ZIP_DEFLATED) as zipf:
    if os.path.exists('app.py'): zipf.write('app.py', 'app.py')
    if os.path.exists('requirements.txt'): zipf.write('requirements.txt', 'requirements.txt')
    if os.path.exists('templates/index.html'): zipf.write(os.path.join('templates', 'index.html'), 'templates/index.html')

print('ZIP created')
"@

$pythonScript | Out-File -FilePath "create_zip.py" -Encoding UTF8
python create_zip.py
Remove-Item "create_zip.py" -Force

az webapp deploy --resource-group $resourceGroup --name $appName --src-path deploy.zip --type zip --output none

Write-Host "DEPLOYMENT COMPLET!" -ForegroundColor Green
Write-Host "App URL: https://$appName.azurewebsites.net"