# TEMA 4: Code Explanation Plugin

**Nume:** Niță-Gheorghiaș Anelis-Ramona

**Link Aplicație:** [https://code-explainer-6896.azurewebsites.net/](https://code-explainer-6896.azurewebsites.net/)

**Info Endpoint:** [https://code-explainer-6896.azurewebsites.net/info](https://code-explainer-6896.azurewebsites.net/info)

## 📜 Descriere
Aplicație web care explică fragmente de cod folosind Azure OpenAI. Primește cod în orice limbaj de programare și returnează o explicație clară a funcționalității acestuia.

## 🤖 Model Azure OpenAI
- **Model**: GPT-4o-mini
- **Versiune**: 2024-07-18
- **Deployment**: gpt-4o-mini
- **Regiune**: Sweden Central

## 💡 Funcționalitate
Plugin-ul oferă trei endpoint-uri principale:
- `GET /` - Interfață web pentru utilizatori
- `POST /prompt` - API pentru explicarea codului
- `GET /info` - Informații despre plugin
- `GET /health` - Status aplicație

## 🔍 Exemplu Request/Response

### Request
```bash
POST /prompt
Content-Type: application/json

{
  "prompt": "def factorial(n):\n    return 1 if n == 0 else n * factorial(n-1)"
}
```

### Response (Success)
```json
{
  "explanation": "This function is a classic example of recursion and effectively computes the factorial of a given number using a straightforward mathematical definition.",
  "status": "success"
}
```

## ❌ Cum se declanșează o eroare

### Eroare 400 - Prompt gol
```bash
POST /prompt
Content-Type: application/json

{
  "prompt": ""
}
```
**Răspuns**: `{"error": "Prompt cannot be empty"}`

### Eroare 502 - OpenAI indisponibil
Dacă credențialele Azure OpenAI sunt incorecte sau serviciul este indisponibil:
**Răspuns**: `{"error": "Azure OpenAI request failed", "details": "..."}`

## 🛠️ Deployment

Aplicația este deployată pe **Azure App Service** folosind următoarea infrastructură:

- **Platform**: Azure App Service (Linux)
- **Runtime**: Python 3.11
- **Pricing Tier**: B1 (Basic)
- **Web Server**: Gunicorn
- **Regiune**: Sweden Central

### Resurse create
1. Resource Group: `tema4-rg`
2. App Service Plan: `asp-openai` (Linux B1)
3. Web App: `code-explainer-6896`
4. Azure OpenAI: `openai-code-6896` (SKU S0)

### Procesul de deployment
1. Se creează resursele Azure prin Azure CLI
2. Se configurează variabilele de mediu (endpoint, API key, deployment name)
3. Aplicația Flask este împachetată într-un ZIP
4. ZIP-ul este urcat pe Azure App Service
5. Gunicorn pornește aplicația pe portul 8000

**Script deployment**: `deploy.ps1` (PowerShell)