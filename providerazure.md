# Provider-Azure

In Terraform, il provider è un plugin che consente di interagire con un provider in cloud per poter creare l’infrastruttura. 

Quando andiamo a creare un’infrastruttura, infatti, il primo blocco sarà provvisto del comando ```provider``` seguito dal nome del provider, es. ```azurerm```, ```features``` e ```subscription```:

```
provider "azurerm" {
  features {} #features è obbligatorio ma può essere lasciato vuoto
  subscription_id = Id-della-sottoscrizione
}
```
Ci sono casi in cui è necessario specificare la versione del provider che si vuole utilizzare. Questo può avvenire nel caso di infrastrutture configurate in una certa versione, o quando si sta modificando un'infrastruttura che è stata condivisa da un cliente e di cui ci ha fornito i file terraform.

```
# 1. Specify the version of the AzureRM Provider to use
terraform {
  required_providers {
    azurerm = {
      source = "hashicorp/azurerm"
      version = "=3.0.1"
    }
  }
}
```
## AzureRM

Azure Resource Manager è il servizio di **distribuzione e di gestione delle risorse** in Azure: permette all'utente di creare, gestire, leggere, aggiornare e cancellare risorse in Azure, tra le quali VM, Storage Accounts, VNet etc...

Con questo provider facciamo riferimento a delle **risorse cloud**, mentre con Azure AD faremo riferimento alla gestione delle **identità**.

![image](https://github.com/user-attachments/assets/624417a8-c725-4641-a1de-730713080cf4)

Questo servizio è disponibile sia da portale, che da Powershell, Azure CLI e API REST.
- **Resource**: le risorse in Azure sono tutti gli oggetti che possono essere configurati come VM, VNet, Stroage accounts etc...
- **Resource groups** : I gruppi di risorse sono contenitori logici all'interno dei quali inseriamo le risorse che abbiamo creato.

  Es. sto creando un'infrastruttura per lo sviluppo:
    - creo il gruppo risorse "Dev"
``` 
  resource "azurerm_resource_group" "Dev" {
  name     = "Dev"
  location = "West Europe"
}
```
    - quando configuro una nuova risorsa, es. VNet-dev, la inserisco in quel gruppo risorse
    
```
resource "azurerm_virtual_network" "VNet_Dev" {
  name                = "VNet-Dev"
  resource_group_name = azurerm_resource_group.Dev.name
  location            = azurerm_resource_group.Dev.location
  address_space       = ["10.0.0.0/16"]
}
```
 ## AzureAD

 ![image](https://github.com/user-attachments/assets/2b56eb85-5545-4296-8289-e3dc89c8cf21)

 
Azure AD è il **servizio di identità** e **gestione degli accessi** di Microsoft sul cloud. Serve per:
- **Autenticare** utenti e dispositivi (Single Sign-On, Multi-Factor Authentication)
- **Gestire** permessi e ruoli (RBAC)
- **Integrazione** con applicazioni (Microsoft 365, app custom)
- Autenticazione per servizi cloud come Azure, Microsoft 365, e altre app SaaS

Il provider ```azuread``` di Terraform consente di gestire risorse di Azure Active Directory (es. utenti, gruppi, applicazioni, service principal), utilizzando le Microsoft Graph API. 
Questo provider è complementare ad ```azurerm```: ```azuread``` gestisce identità e accessi (come utenti e permessi), ```azurerm``` gestisce le risorse di Azure.
```
# Configure Terraform
terraform {
  required_providers {
    azuread = {
      source  = "hashicorp/azuread"
      version = "~> 2.15.0"
    }
  }
}

# Configure the Azure Active Directory Provider
provider "azuread" {
  tenant_id = "00000000-0000-0000-0000-000000000000"
}

# Retrieve domain information
data "azuread_domains" "example" {
  only_initial = true
}

# Create an application
resource "azuread_application_registration" "example" {
  display_name = "ExampleApp"
}

# Create a service principal
resource "azuread_service_principal" "example" {
  client_id = azuread_application_registration.example.client_id
}

# Create a user
resource "azuread_user" "example" {
  user_principal_name = "ExampleUser@${data.azuread_domains.example.domains.0.domain_name}"
  display_name        = "Example User"
  password            = "..." #in questo caso si possono usare sia le variabili, che Azure Key Vault per la gestione sicura della password
}
```

## Azure DevOps

![image](https://github.com/user-attachments/assets/3e650d28-0b74-4640-bdb1-1a5f9b27ae87)


Azure DevOps è una piattaforma di DevOps offerta da Microsoft per supportare lo **sviluppo software end-to-end** (dallo sviluppo al monitoraggio). 
Include:
- **Repos** – sistema di controllo di versione basatu su Git
- **Pipelines** – CI/CD per automatizzare integrazione, test e rilascio; supporta YAML pipelines, multi-stage e può essere usato in ambienti multi-cloud e container...
- **Boards** – gestione dei task o sprint

Il ****provider** ```azuredevops``` consente di gestire e configurare risorse di Azure DevOps tramite Terraform, sfruttando le REST API di Azure DevOps. 
Può essere usato per creare **progetti, pipeline, repository** e molto altro.

```
terraform {
  required_providers {
    azuredevops = {
      source  = "microsoft/azuredevops"
      version = ">= 0.1.0"
    }
  }
}

resource "azuredevops_project" "project" {
  name        = "Project Name"
  description = "Project Description"
}
```

Per il processo di autenticazione è possibile utilizzare il servizio principale di Azure AD, attraverso EntraID, oppure tramite accesso personale con token.
**Metodi di autenticazione:**
- Personal Access Token > per ambienti locali o pipeline. Si genera da Azure DevOps con scadenza e permessi specifici;
- OpenID Connect per l'integrazione con sistemi automatizzati come GitHub Actions e Terraform Cloud
    - ```use_oidc = true``` : per usare direttamente un token OIDC
    - ```oidc_token_file_path```: percorso a un file con il token
    - ```oidc_token_request_url```: URL per ottenere un token dinamicamente
- Client Certificate Path : ```client_certificate_path```
- Autenticazione tramite Azure AD/Entra ID:
    - ```client_id ```,  ```client_secret ```,  ```tenant_id ``` : autenticazione via app registrata
- Managed Identity (MSI) – per ambienti Azure con identità gestita (es. VM, App Service)
    - ```use_msi = true```: : supporta Managed Identity (es. in ambienti Azure come VM, App Services)

## Azure API Provider

![image](https://github.com/user-attachments/assets/dbcb9120-e326-4c0a-bede-1e892872efda)

AzAPI è un provider Terraform che ti permette di gestire risorse Azure che non sono ancora supportate (e potrebbero non essere mai supportate ) dai provider classici come ```azurerm```. Il provider azurerm segue un ciclo di rilascio più lento e potrebbe non supportare le risorse più recenti o in anteprima. 
```azapi``` permette di colmare questa lacuna, interfacciandosi direttamente con le API ARM.

Serve per usare le REST API di Azure direttamente da Terraform, utile per:
- Risorse in anteprima (preview)
- Feature sperimentali
- Personalizzazioni particolari

**Esempio di utilizzo di ```azapi```**
```
# We strongly recommend using the required_providers block to set the
# Azure Provider source and version being used
terraform {
  required_providers {
    azapi = {
      source = "azure/azapi"
    }
  }
}

provider "azapi" {
}

resource "azapi_resource" "example" {
  type      = "Microsoft.Authorization/roleAssignments@2020-04-01-preview"
  name      = "example-role-assignment"
  parent_id = data.azurerm_resource_group.example.id
  body      = jsonencode({
    properties = {
      roleDefinitionId = "/subscriptions/.../roleDefinitions/..."
      principalId      = "..."
    }
  })
}

```
## Azure Stack

![image](https://github.com/user-attachments/assets/ffa823de-9ce4-4c82-bb50-a195d660db5c)


Azure Stack è pensato per ambienti con limitata connettività al cloud o esigenze di compliance, non solo per "on-premises". 

Esistono diverse versioni:
- **Azure Stack Hub** – piattaforma completa per eseguire servizi Azure localmente. Esegue VM, app e servizi PaaS di Azure localmente; orientato ai service provider e alle aziende con esigenze di isolamento
- **Azure Stack HCI** – soluzioni ibride per infrastruttura iperconvergente. Sistema operativo per cluster iperconvergenti ottimizzati per Azure Hybrid.
- **Azure Stack Edge**– appliance per elaborazione locale ed edge computing. Appliance gestita da Microsoft, per elaborazione dati in edge computing, AI locale, e carichi di lavoro offline.

```
# Configure the Azure Stack Provider
provider "azurestack" {
  # NOTE: we recommend pinning the version of the Provider which should be used in the Provider block
  # version = "=0.9.0"
}

# Create a resource group
resource "azurestack_resource_group" "test" {
  name     = "production"
  location = "West US"
}

# Create a virtual network within the resource group
resource "azurestack_virtual_network" "test" {
  name                = "production-network"
  address_space       = ["10.0.0.0/16"]
  location            = azurestack_resource_group.test.location
  resource_group_name = azurestack_resource_group.test.name

  subnet {
    name           = "subnet1"
    address_prefix = "10.0.1.0/24"
  }

  subnet {
    name           = "subnet2"
    address_prefix = "10.0.2.0/24"
  }

  subnet {
    name           = "subnet3"
    address_prefix = "10.0.3.0/24"
  }
}
```
_________________________________________________

# Azure DevOps : creare una Pipeline con Terraform

https://learn.microsoft.com/it-it/azure/developer/terraform/best-practices-integration-testing

## Test di integrazione
I test di integrazione verificano che una modifica del codice appena introdotta non interrompa il codice esistente. In DevOps, l'integrazione continua (CI) fa riferimento a un processo che compila l'intero sistema ogni volta che la base di codice viene modificata, ad esempio quando qualcuno desidera unire una pull request in un repository Git.

## Requisiti
1. Abbonamento Azure
2. Configurazione Terraform
3. Progetto in Azure DevOps > https://learn.microsoft.com/it-it/azure/devops/organizations/projects/create-project?view=azure-devops&tabs=browser
4. Estensione delle attività di build e rilascio & Terraform > https://marketplace.visualstudio.com/items?itemName=JasonBJohnson.azure-pipelines-tasks-terraform
5. Concedere ad Azure DevOps l'accesso alla sottoscrizione di Azure: creare una connessione al servizio di Azure denominata terraform-basic-testing-azure-connection per consentire ad Azure Pipelines di connettersi alle sottoscrizioni di Azure
6. Codice e risorse di esempio: Scaricare da GitHub il progetto di test di integrazione. La directory in cui si scarica l'esempio viene definita directory di esempio.

## Convalidare una configurazione Terraform locale
Il comando terraform validate viene eseguito dalla riga di comando nella cartella che contiene i file di Terraform. Questo obiettivo principale dei comandi consiste nel convalidare la sintassi.

1. All'interno della directory di esempio, naviga alla directory ```src```.

2. Eseguire terraform init per inizializzare la directory di lavoro.

```
terraform init
```
3. Eseguire terraform validate per convalidare la sintassi dei file di configurazione.

```
terraform validate
```
**Punti chiave:**
Viene visualizzato un messaggio che indica che la configurazione di Terraform è valida.

4. Modificare il file main.tf.
Nella riga 5 inserire un errore di digitazione che invalida la sintassi. Ad esempio, sostituire var.location con var.loaction

5. Salvare il file.
6. Eseguire di nuovo la convalida.
```
terraform validate
```
**Punti chiave:**
Viene visualizzato un messaggio di errore che indica la riga di codice in errore e una descrizione dell'errore.

### Progetto di esempio Terraform in GitHub
https://github.com/Azure/terraform

**File YAML di base**

```file.yaml```
```
trigger:
  branches:
    include:
      - main
      - develop

pool:
  vmImage: 'ubuntu-latest'

variables:
  azureServiceConnection: 'terraform-basic-testing-azure-connection'
  terraformWorkingDirectory: 'src'

stages:
  - stage: TerraformValidation
    displayName: "Terraform Init & Validate"
    jobs:
      - job: ValidateTerraform
        displayName: "Init and Validate Terraform Config"
        steps:

          - task: Checkout@1
            displayName: "Checkout repository"

          - task: TerraformInstaller@1
            displayName: "Install Terraform"
            inputs:
              terraformVersion: 'latest'

          - task: TerraformTaskV4@4
            displayName: "Terraform Init"
            inputs:
              provider: 'azurerm'
              command: 'init'
              workingDirectory: '$(terraformWorkingDirectory)'
              backendServiceArm: '$(azureServiceConnection)'

          - task: TerraformTaskV4@4
            displayName: "Terraform Validate"
            inputs:
              provider: 'azurerm'
              command: 'validate'
              workingDirectory: '$(terraformWorkingDirectory)'
              environmentServiceNameAzureRM: '$(azureServiceConnection)'
```
### Cosa fa questa pipeline:
- Trigger su main e develop.
- Usa un VM Ubuntu.
- Usa il servizio ```terraform-basic-testing-azure-connection``` per autenticarsi ad Azure.
- Esegue terraform init e terraform validate nella cartella src/.

### Requisiti per farla funzionare:
1. Estensione Terraform installata in Azure DevOps:
2. Terraform extension per Azure DevOps (_quella di JasonBJohnson o Microsoft va bene_)
3. Una connessione al servizio ARM chiamata ```terraform-basic-testing-azure-connection```.
