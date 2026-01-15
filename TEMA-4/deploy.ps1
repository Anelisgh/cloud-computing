$APP_LOCATION = "swedencentral"
$AI_LOCATION = "swedencentral" 
$RESOURCE_GROUP = "tema4-rg"
$APP_NAME = "code-explainer-$(Get-Random -Maximum 99999)"
$APP_SERVICE_PLAN = "asp-openai"
$OPENAI_RESOURCE = "openai-code-$(Get-Random -Maximum 99999)"

$OPENAI_DEPLOYMENT = "gpt-4o-mini"
$MODEL_NAME = "gpt-4o-mini"
$MODEL_VERSION = "2024-07-18"

Write-Host "1. Creez grupul de resurse..." -ForegroundColor Yellow
az group create --name $RESOURCE_GROUP --location $APP_LOCATION

Write-Host "2. Creez App Service Plan (Linux B1)..." -ForegroundColor Yellow
az appservice plan create `
  --name $APP_SERVICE_PLAN `
  --resource-group $RESOURCE_GROUP `
  --location $APP_LOCATION `
  --sku B1 `
  --is-linux

Write-Host "3. Creez Web App (Python 3.11)..." -ForegroundColor Yellow
az webapp create `
  --name $APP_NAME `
  --resource-group $RESOURCE_GROUP `
  --plan $APP_SERVICE_PLAN `
  --runtime "PYTHON:3.11"

Write-Host "4. Creez resursa OpenAI..." -ForegroundColor Yellow
az cognitiveservices account create `
  --name $OPENAI_RESOURCE `
  --resource-group $RESOURCE_GROUP `
  --kind OpenAI `
  --sku S0 `
  --location $AI_LOCATION `
  --yes

Write-Host "   Astept 30 secunde propagarea..." 
Start-Sleep -Seconds 30

$OPENAI_ENDPOINT = az cognitiveservices account show --name $OPENAI_RESOURCE --resource-group $RESOURCE_GROUP --query properties.endpoint --output tsv
$OPENAI_KEY = az cognitiveservices account keys list --name $OPENAI_RESOURCE --resource-group $RESOURCE_GROUP --query key1 --output tsv

Write-Host "5. Deploy la modelul OpenAI..." -ForegroundColor Yellow
az cognitiveservices account deployment create `
  --name $OPENAI_RESOURCE `
  --resource-group $RESOURCE_GROUP `
  --deployment-name $OPENAI_DEPLOYMENT `
  --model-name $MODEL_NAME `
  --model-version $MODEL_VERSION `
  --model-format OpenAI `
  --sku-capacity 10 `
  --sku-name GlobalStandard

Write-Host "6. Configurez variabilele de mediu si Start Command..." -ForegroundColor Yellow
az webapp config appsettings set `
  --name $APP_NAME `
  --resource-group $RESOURCE_GROUP `
  --settings `
    AZURE_OPENAI_ENDPOINT="$OPENAI_ENDPOINT" `
    AZURE_OPENAI_API_KEY="$OPENAI_KEY" `
    AZURE_OPENAI_DEPLOYMENT_NAME="$OPENAI_DEPLOYMENT" `
    SCM_DO_BUILD_DURING_DEPLOYMENT="true" `
    WEBSITES_CONTAINER_START_TIME_LIMIT="1800"

az webapp config set `
  --name $APP_NAME `
  --resource-group $RESOURCE_GROUP `
  --startup-file "python -m gunicorn --bind=0.0.0.0:8000 --timeout 600 app:app"

Write-Host "7. Generez requirements.txt stabil..." -ForegroundColor Yellow

@"
flask
openai==1.10.0
gunicorn
httpx==0.25.2
"@ | Out-File -FilePath "requirements.txt" -Encoding ASCII -Force

Write-Host "8. Impachetez ZIP..." -ForegroundColor Yellow
if (Test-Path "deploy.zip") { Remove-Item "deploy.zip" -Force }

$pythonZipScript = @"
import zipfile
import os

print('Impachetez...')
with zipfile.ZipFile('deploy.zip', 'w', zipfile.ZIP_DEFLATED) as zipf:
    # Fisierele din radacina
    files = ['app.py', 'requirements.txt']
    for f in files:
        if os.path.exists(f):
            zipf.write(f, f)
            print(f' + {f}')
    
    # Folderul templates
    if os.path.exists('templates/index.html'): 
        zipf.write(os.path.join('templates', 'index.html'), 'templates/index.html')
        print(' + templates/index.html')
"@
$pythonZipScript | Out-File -FilePath "create_zip_temp.py" -Encoding UTF8
python create_zip_temp.py
Remove-Item "create_zip_temp.py" -Force

Write-Host "9. Urc aplicatia (Metoda ZIP)..." -ForegroundColor Yellow
az webapp deployment source config-zip `
  --resource-group $RESOURCE_GROUP `
  --name $APP_NAME `
  --src "deploy.zip"

Write-Host ""
Write-Host "Aplicatia e functionala aici:" -ForegroundColor Green
Write-Host "https://$APP_NAME.azurewebsites.net" -ForegroundColor Cyan