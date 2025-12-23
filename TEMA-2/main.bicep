param location string = 'swedencentral'
param sqlAdminUser string = 'anelisgh'
@secure()
param sqlAdminPassword string

var uniqueSuffix = substring(uniqueString(resourceGroup().id), 0, 8)
var appName = 'webapp-tema2-${uniqueSuffix}'
var sqlServerName = 'sqlserver-tema2-${uniqueSuffix}'
var planName = 'asp-tema2'
var dbName = 'ItemsDB'

// 1. Service Plan
resource appServicePlan 'Microsoft.Web/serverfarms@2023-01-01' = {
  name: planName
  location: location
  kind: 'linux'
  sku: {
    name: 'F1'
    tier: 'Free'
  }
  properties: {
    reserved: true
  }
}

// 2. Web App
resource webApp 'Microsoft.Web/sites@2023-01-01' = {
  name: appName
  location: location
  properties: {
    serverFarmId: appServicePlan.id
    httpsOnly: true
    siteConfig: {
      linuxFxVersion: 'PYTHON|3.11'
      appCommandLine: 'gunicorn --bind=0.0.0.0 --timeout 600 app:app'
      appSettings: [
        {
          name: 'SCM_DO_BUILD_DURING_DEPLOYMENT'
          value: 'true'
        }
        {
          name: 'SQL_CONNECTION_STR'
          value: 'Driver={ODBC Driver 18 for SQL Server};Server=tcp:${sqlServerName}.database.windows.net,1433;Database=${dbName};Uid=${sqlAdminUser};Pwd=${sqlAdminPassword};Encrypt=yes;TrustServerCertificate=no;Connection Timeout=30;'
        }
      ]
    }
  }
}

// 3. SQL Server
resource sqlServer 'Microsoft.Sql/servers@2023-05-01-preview' = {
  name: sqlServerName
  location: location
  properties: {
    administratorLogin: sqlAdminUser
    administratorLoginPassword: sqlAdminPassword
    minimalTlsVersion: '1.2'
    publicNetworkAccess: 'Enabled' 
    restrictOutboundNetworkAccess: 'Disabled'
  }
}

// 4. SQL Database
resource sqlDatabase 'Microsoft.Sql/servers/databases@2023-05-01-preview' = {
  parent: sqlServer
  name: dbName
  location: location
  sku: {
    name: 'Basic'
    tier: 'Basic'
  }
}

// Outputs pt PowerShell
output appName string = appName
output sqlServerName string = sqlServerName
output dbName string = dbName
