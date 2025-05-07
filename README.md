# Implementazione di un cluster K3s su Azure con Terraform e Docker

Si vuole implementare un'infrastruttura su Azure utilizzando Terraform che consiste in un cluster K3s ad alta disponibilità con 3 nodi. Su questo cluster verrà
deployato un progetto Docker fornito e disponibile al seguente indirizzo

https://github.com/MrMagicalSoftware/docker-k8s/blob/main/esercitazione-docker-file.md

**NB:Comandi utili per lavorare in Terraform**

- ```terraform init```  = Inizializza una directory di lavoro Terraform, scaricando i plugin dei provider e preparando l’ambiente per l'esecuzione dei comandi successivi.
- ```terraform plan```  = Mostra un’anteprima delle modifiche che Terraform apporterà all’infrastruttura, confrontando lo stato attuale con il codice definito.
- ```terraform apply``` = Applica effettivamente le modifiche all’infrastruttura secondo quanto previsto dal piano, creando, modificando o distruggendo risorse.
- ```terraform fmt```  = Formatta i file di configurazione Terraform secondo lo stile standard, migliorandone la leggibilità e la coerenza.

**NB: Comandi utili per la gestione in Azure**

- ```az account show```  = Mostra le informazioni sull’account Azure attualmente in uso, inclusi ID sottoscrizione e tenant.
- ```az login```  =  Avvia il processo di autenticazione per accedere al proprio account Azure tramite il browser o altri metodi supportati.
- ```az vm image list-offers --location westeurope --publisher Canonical -o table``` = Elenca le offerte di immagini di macchine virtuali disponibili dal publisher _Canonical_ nella regione _westeurope_, formattando l’output in forma tabellare.

## 1. Infrastruttura Azure:
- Creare 1 macchina virtuale (VM) in Azure usando Terraform. La macchina servirà per i test , definirla correttamente con l’uso di variabili)
- Configurare una rete virtuale (VNet) appropriata
- Implementare gruppi di sicurezza (NSG) per gestire il traffico di rete

## Creazione infrastruttura
Verifica dell'**account di Azure**:

```az account show```
Questo comando permette di **verificare** quale **account** di Azure è attualmente **in uso**. 
Nel mio caso ho creato un nuovo account Azure, ma sono collegata in Terraform a quello vecchio. 

```az login```

Quindi faccio il login all'account nuovo.

Una volta fatto il login, creo i primi due blocchi con il provider in uso ```azurerm```, ovvero Azure Resource Manager, il provider che mi permette di creare le risorse in Azure, e creo il gruppo di risorse sul quale lavorerò.

```
provider "azurerm" {
  features {}
  subscription_id = var.subscription_id
}

resource "azurerm_resource_group" "K3s_Lab" {
  name     = "K3s-Lab"
  location = "West Europe"

}
```

Per una questione di **sicurezza**, è stata creata una variabile in ```variables.tf``` per **inserire manualmente il proprio ```subscription_id```**:

variables.tf
```
variable "subscription_id" {
  description = "ID della sottoscrizione Azure"
  type        = string
  sensitive   = true
}
```

Successivamente, ho creato un ```terraform.tfvars.secret```.

In questo file verranno messi tutti i dati sensibili, come l'id, le password etc...

Infine, dò il comando ```terraform init``` per inizializzare la directory in cui lavorerò.

## Creazione VNet e Subnet
Per la creazione della virtual network ho utilizzato una variabile per personalizzare il nome rispetto al progetto. Si tratta di un prefisso, il cui valore predefinito sarà "K3s".

main.tf

```
resource "azurerm_virtual_network" "vnet_master" {
  name                = "${var.prefix}-vnet-master" #Risulterà "K3s-vnet-master"
  location            = azurerm_resource_group.K3s_Lab.location #Usa la location del resource group
  resource_group_name = azurerm_resource_group.K3s_Lab.name #Appartiene al resource group esistente
  address_space       = ["10.0.0.0/16"]  # IP range della VNet
}

resource "azurerm_subnet" "subnet_master" {
  name                 = "${var.prefix}-subnet-master" #Risulterà "K3s-subnet-master"
  resource_group_name  = azurerm_resource_group.K3s_Lab.name #Stesso gruppo della VNet
  virtual_network_name = azurerm_virtual_network.vnet_master.name  #Collegata alla VNet creata sopra
  address_prefixes     = ["10.0.1.0/24"] #IP range per la sottorete
}
```

variables.tf> definisco i nomi dinamici per le risorse usando la variabile ```prefix``` e esplicitando il contenuto (essendo ```string```) nel file ```.tfvars.```
```
variable "prefix" {
  default     = "string"
  description = "Prefisso della risorsa"
}
```

terraform.tfvars > assegno esplicitamente il valore "K3s" alla variabile ```prefix```
```
prefix = "K3s"
```


