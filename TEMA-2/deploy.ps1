# DEPLOY SIMPLU FARA BICEP
$resourceGroup = "tema2"
$location = "swedencentral"
$appName = "webapp-tema2-" + (Get-Random -Maximum 999999)
$planName = "asp-tema2"
$sqlServer = "sqlserver-tema2-" + (Get-Random -Maximum 999999)
$dbName = "ItemsDB"
$adminUser = "anelisgh"
$adminPass = "Parola_homework2!"

Write-Host "SE INCEPE DEPLOYMENT-UL" -ForegroundColor Green

Write-Host "`n[1/10] Se creaza resource group..."
az group create --name $resourceGroup --location $location --output none

Write-Host "[2/10] Se creaza SQL Server..."
az sql server create `
    --name $sqlServer `
    --resource-group $resourceGroup `
    --location $location `
    --admin-user $adminUser `
    --admin-password $adminPass `
    --output none
Start-Sleep -Seconds 30

Write-Host "[3/10] Se creaza database..."
az sql db create `
    --resource-group $resourceGroup `
    --server $sqlServer `
    --name $dbName `
    --service-objective Basic `
    --output none

Write-Host "[4/10] Se creaza App Service Plan..."
az appservice plan create `
    --name $planName `
    --resource-group $resourceGroup `
    --sku F1 `
    --is-linux `
    --output none

Write-Host "[5/10] Se creaza Web App..."
az webapp create `
    --resource-group $resourceGroup `
    --plan $planName `
    --name $appName `
    --runtime "PYTHON:3.11" `
    --output none
Start-Sleep -Seconds 20

# adauagam toate ip-urile posibile pentru ca am avut eroarea Eroare: ('42000', "[42000] [Microsoft][ODBC Driver 18 for SQL Server][SQL Server]Cannot open server 'sqlserver-tema2-157288' requested by the login. Client with IP address '74.241.164.139' is not allowed to access the server. To enable access, use the Azure Management Portal or run sp_set_firewall_rule on the master database to create a firewall rule for this IP address or address range. It may take up to five minutes for this change to take effect. (40615) (SQLDriverConnect)")
Write-Host "[6/10] Se configureaza firewall SQL cu TOATE IP-urile posibile..."

# Stergem regula default
az sql server firewall-rule delete `
    --resource-group $resourceGroup `
    --server $sqlServer `
    --name "AllowAllWindowsAzureIps" `
    --yes 2>$null

Write-Host "Se iau toate IP-urile posibile..."
$allIps = az webapp show `
    --resource-group $resourceGroup `
    --name $appName `
    --query "possibleOutboundIpAddresses" `
    --output tsv

$ipArray = $allIps -split ","
Write-Host "S-au gasit $($ipArray.Count) IP-uri posibile"

foreach ($ip in $ipArray) {
    $ip = $ip.Trim()
    Write-Host "Se adauga IP: $ip"
    $ruleName = "Allow_" + ($ip -replace '\.', '-')
    
    az sql server firewall-rule create `
        --resource-group $resourceGroup `
        --server $sqlServer `
        --name $ruleName `
        --start-ip-address $ip `
        --end-ip-address $ip `
        --output none 2>$null
}


Write-Host "[7/10] Se seteaza connection string..."
$connectionString = "Driver={ODBC Driver 18 for SQL Server};Server=tcp:$sqlServer.database.windows.net,1433;Database=$dbName;Uid=$adminUser;Pwd=$adminPass;Encrypt=yes;TrustServerCertificate=no;Connection Timeout=30;"

az webapp config appsettings set `
    --name $appName `
    --resource-group $resourceGroup `
    --settings `
        "SQL_CONNECTION_STR=$connectionString" `
        "SCM_DO_BUILD_DURING_DEPLOYMENT=true" `
    --output none

Write-Host "[8/10] Se configureaza startup..."
az webapp config set `
    --resource-group $resourceGroup `
    --name $appName `
    --startup-file "gunicorn --bind=0.0.0.0 --timeout 600 app:app" `
    --output none

# fix pentru linux paths in zip
Write-Host "[9/10] Se creaza ZIP cu paths corecte pentru Linux..."

# verificam sa ne asiguram ca am scapat de eroare
if (-Not (Test-Path "app.py")) { Write-Host "EROARE: app.py lipseste!" -ForegroundColor Red; exit 1 }
if (-Not (Test-Path "requirements.txt")) { Write-Host "EROARE: requirements.txt lipseste!" -ForegroundColor Red; exit 1 }
if (-Not (Test-Path "templates\index.html")) { Write-Host "EROARE: templates\index.html lipseste!" -ForegroundColor Red; exit 1 }

if (Test-Path "deploy.zip") { Remove-Item "deploy.zip" -Force }

# se creează ZIP cu structura corecta pentru Linux
$pythonScript = @"
import zipfile
import os

with zipfile.ZipFile('deploy.zip', 'w', zipfile.ZIP_DEFLATED) as zipf:
    # Add app.py
    zipf.write('app.py', 'app.py')
    # Add requirements.txt
    zipf.write('requirements.txt', 'requirements.txt')
    # Add templates/index.html with FORWARD SLASH
    zipf.write(os.path.join('templates', 'index.html'), 'templates/index.html')

print('ZIP created successfully with Linux paths')
"@

# salvează script temporar
$pythonScript | Out-File -FilePath "create_zip.py" -Encoding UTF8

# ruleaza pentru a crea zip 100% corect
python create_zip.py

# stergem fisierul temp
Remove-Item "create_zip.py" -Force

# verificam
Write-Host "   Verificare ZIP:"
Add-Type -Assembly System.IO.Compression.FileSystem
$zip = [System.IO.Compression.ZipFile]::OpenRead("$PWD\deploy.zip")
$zip.Entries | ForEach-Object { Write-Host "     - $($_.FullName)" -ForegroundColor Cyan }
$zip.Dispose()

Write-Host "[10/10] Se face deploy la cod..."
az webapp deploy `
    --resource-group $resourceGroup `
    --name $appName `
    --src-path deploy.zip `
    --type zip

Write-Host "`n Asteptare start aplicatie (45 sec)..."
Start-Sleep -Seconds 45

Write-Host "`n DEPLOYMENT COMPLET" -ForegroundColor Green
Write-Host "`n App URL: https://$appName.azurewebsites.net" -ForegroundColor Cyan
Write-Host "`n Resurse create:"
Write-Host "   - Resource Group: $resourceGroup"
Write-Host "   - SQL Server: $sqlServer.database.windows.net"
Write-Host "   - Database: $dbName"
Write-Host "   - Web App: $appName"
Write-Host "` Logs:"
Write-Host "   az webapp log tail --name $appName --resource-group $resourceGroup" -ForegroundColor Gray