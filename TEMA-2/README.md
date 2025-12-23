# Homework 2 - Azure Web App Hosting

## 1. NUME COMPLET
**Niță-Gheorghiaș Anelis-Ramona**

## 2. PUBLIC URL
**[https://webapp-tema2-dvtqqhq3.azurewebsites.net/](https://webapp-tema2-dvtqqhq3.azurewebsites.net/)**

## 3. TECHNOLOGY STACK
* **Python 3.11** + **Flask**
* **Azure SQL Database**
* **Gunicorn**
* **Azure App Service (Linux)**

## 4. DATABASE
* **Azure SQL Database** (Basic Tier)

## 5. SECURITATE

### a. Cum am restricționat accesul:
* Am șters regula default "Allow Azure Services".
* Am adăugat doar IP-urile App Service-ului în SQL Firewall.
* Connection string-ul este stocat în **Application Settings**, nu în cod.
* Nimeni altcineva nu poate accesa baza de date.

### b. IP-uri permise:
* Doar IP-urile din lista `possibleOutboundIpAddresses` ale App Service.
* Sunt aproximativ 30 de IP-uri, toate din regiunea **Azure Sweden Central**.
* Le putem vedea rulând: `az webapp show --query "possibleOutboundIpAddresses"`
* Sau în Azure Portal: **App Service → Properties → Outbound IPs**.

## 6. CUM SE TESTEAZĂ APLICAȚIA
1. Accesăm URL-ul public generat.
2. Scriem ceva în câmpul de text.
3. Apasăm butonul **"Salvează"**.
4. Elementul apare în lista de jos.
5. Dăm **Refresh** la pagină -> datele rămân (demonstrând persistența în DB).

## 7. CUM SE RULEAZĂ DEPLOYMENT

**Prerequisites:**
* Azure CLI instalat (`az login`)
* Python 3.x

### Standard
    .\deploy.ps1

### Sau cu Infrastructure as Code
    .\deploy-bonus.ps1

*Ambele scripturi realizează același deployment, dar `deploy-bonus.ps1` utilizează Bicep pentru infrastructură.*

## 8. Infrastructure as Code
Implementat folosind **Azure Bicep** într-o abordare hibridă:

* **`main.bicep`**: Definește declarativ resursele (Server SQL, Database, App Service Plan, Web App).
* **`deploy-bonus.ps1`**: Rulează template-ul Bicep și apoi configurează firewall-ul prin comenzi CLI.

Această abordare este necesară deoarece IP-urile de ieșire sunt alocate dinamic la runtime.

## 9. STRUCTURA PROIECTULUI

    TEMA-2/
    ├── app.py                  # Aplicația Flask
    ├── requirements.txt        # Dependențe
    ├── deploy.ps1              # Deployment standard
    ├── deploy-bonus.ps1        # Deployment cu IaC
    ├── main.bicep              # Infrastructură
    ├── templates/
    │   └── index.html          # Interfață grafică
    └── README.md               # Acest fișier
