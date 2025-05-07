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

___________________________________________________

## Azurerm e Gruppo risorse
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
![image](https://github.com/user-attachments/assets/ef28516e-d7b1-45c8-977c-109d694f6e94)


Successivamente, ho creato un ```terraform.tfvars.secret```.

In questo file verranno messi tutti i dati sensibili, come l'id, le password etc...

Infine, dò il comando ```terraform init``` per inizializzare la directory in cui lavorerò.
**Risultato atteso dopo ```terraform plan```/```terraform apply```**
![image](https://github.com/user-attachments/assets/66561906-8d4d-4fcf-a36e-b81e929e549f)

**Risultato atteso nella piattaforma Azure**
![image](https://github.com/user-attachments/assets/abd4b04b-344c-4844-85de-4a11be5507de)

____________________________________________________________

## Creazione VNet, Subnet e interfaccia di rete
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
### Errori riscontrati e soluzione
Nella risorsa azurerm_network_interface, avevo definito il nome come "net-int-${var.prefix}" e Terraform avrebbe creato delle risorse con lo stesso nome. Ma Azure Network Interface deve avere un nome univoco all'interno di una stesssa sottorete e gruppo di risorse. 

Mi aveva infatti restituito : ```"The resource with the name 'net-int-K3s' already exists."```

Per risolvere il problema, mi sono assicurata che ogni risorsa avesse un nome univoco, concatenando un identificatore unico per ogni iterazione del ciclo for_each con ${each-key}

 ```
resource "azurerm_network_interface" "network_interface_K3s" {
  for_each            = var.vm_master
  name                = "net-int-${var.prefix}-${each.key}"
  location            = azurerm_resource_group.K3s_Lab.location
  resource_group_name = azurerm_resource_group.K3s_Lab.name

  ip_configuration {
    name                          = "ipconfig"
    subnet_id                     = azurerm_subnet.subnet_master.id
    private_ip_address_allocation = "Dynamic"
  }
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
### Validazione CIDR dopo ```terraform plan```/```terraform apply```
In questa configurazione, se avessimo voluto garantire che l'indirizzo IP della subnet (in formato CIDR) fosse valido e rientrasse in un intervallo accettabile, potevamo definire una variabile con il CIDR della subnet, aggiungendo una validazione (ad esempio, 10.0.0.0/16).

main.tf
```
resource "azurerm_subnet" "subnet_master" {
  name                 = "${var.prefix}-subnet-master"
  resource_group_name  = azurerm_resource_group.K3s_Lab.name
  virtual_network_name = azurerm_virtual_network.vnet_master.name
  address_prefixes     = [var.subnet_cidr]
}
```
variables.tf
```
#Definire una variabile subnet_cidr
variable "subnet_cidr" {
    type = string
    description = "CIDR della subnet (es. 10.0.1.0/24)"

    validation {
      condition = can(cidrhost(var.subnet_cidr, 0)) && startswith(var.subnet_cidr, "10.0")
      error_message = "Il CIDR deve essere valido e deve appartenere al blocco 10.0.0.0/16"
    }
  
}
#Verificare che il CIDR sia valido e rientri in un range accettabile (es. una /24 all’interno di 10.0.0.0/16)

#Usare quel CIDR per creare una subnet
```
outputs.tf
```
output "subnet_cidr_validato" {
  value = var.subnet_cidr
} #mostrare in outputs.tf il risultato
```
**Risultato atteso nella piattaforma Azure**
![image](https://github.com/user-attachments/assets/5243c860-07f1-4516-8350-3f50be78290c)

_______________________________________________________
## Creazione VM
Per la creazione della Virtual machine si è scelto un Ubuntu Server, la scelta dell'immagine ha creato qualche problema per una questione di disponibilità dell'immagine nella regione scelta (nel mio caso West Europe non supportava  "UbuntuServer-18.04-LTS:latest. La soluzione è esposta in "Errori"
main.tf
```
resource "azurerm_linux_virtual_machine" "vm_master" {
  for_each = var.vm_master

  name                            = each.key
  resource_group_name             = azurerm_resource_group.K3s_Lab.name
  location                        = azurerm_resource_group.K3s_Lab.location
  size                            = each.value.vm_size
  admin_username                  = "azureuser"
  admin_password                  = "Password!£!?"
  disable_password_authentication = false

  network_interface_ids = [
    azurerm_network_interface.network_interface_K3s[each.key].id
  ]

  source_image_reference {
    publisher = each.value.image.publisher
    offer     = each.value.image.offer
    sku       = each.value.image.sku
    version   = each.value.image.version
  }

  os_disk {
    name                 = "${each.key}-osdisk"
    caching              = "ReadWrite"
    storage_account_type = "Standard_LRS"
  }

  tags = each.value.tags
}
```

**Per il file variables** si è scelto di accedere alla VM con nome utente e password, rendendo la password segreta (è stata inserita nel file .tfvars.secret).  Le variabili come vm_master, admin_username e admin_password sono utilizzate per rendere la configurazione più flessibile, mantenibile e sicura. Inoltre, aiutano a definire configurazioni diverse per ogni VM in modo centralizzato e riutilizzabile, senza ripetere codice.

La variabile admin e password:
- Definisce le variabili per l'username e la password dell'amministratore per tutte le VM. La password è protetta (sensitive) per evitare di esporla nel piano di esecuzione.
- Consente di centralizzare le credenziali di amministratore e di applicarle uniformemente a tutte le VM, pur mantenendo una certa sicurezza per la password.

variables.tf
```
variable "vm_master" {
  type = map(object({
    vm_size = string
    image = object({
      publisher = string
      offer     = string
      sku       = string
      version   = string
    })
    tags = map(string)
  }))

  default = {
    "VM-master" = {
      vm_size = "Standard_B1s"
      image = {
        publisher = "Canonical"
        offer     = "UbuntuServer"
        sku       = "22_04-lts-gen2"
        version   = "latest"
      }
      tags = {
        Environment = "dev"
        Role        = "K3s"
      }
    }
  }
}

variable "admin_username" {
  description = "Username dell'amministratore"
  type        = string
  default     = "azureuser"

  validation {
    condition     = length(var.admin_username) >= 6 && length(var.admin_username) <= 20
    error_message = "Il nome utente deve essere compreso tra 6 e 20 caratteri."
  }
}

variable "admin_password" {
  description = "Password dell'amministratore per le macchine virtuali"
  type        = string
  sensitive   = true

  validation {
    condition     = length(var.admin_password) >= 12 && can(regex("[A-Z]", var.admin_password)) && can(regex("[a-z]", var.admin_password)) && can(regex("[0-9]", var.admin_password)) && can(regex("[!@#$%^&*()_+]", var.admin_password))
    error_message = "La password deve contenere almeno 12 caratteri, inclusi maiuscole, minuscole, numeri e caratteri speciali (!@#$%^&*()_+)."
  }
}
```

terraform.tfvars
```
vm_master = {
  "VM-master" = {
    vm_size = "Standard_B2s"
    image = {
      publisher = "Canonical"
      offer     = "0001-com-ubuntu-server-jammy"
      sku       = "22_04-lts-gen2"
      version   = "latest"
    }
    tags = {
      Environment = "dev"
      Role        = "K3s"
    }
  }
}
admin_username = "azureadmin"
```

### Errori riscontrati e soluzione
```
│ Error: creating Linux Virtual Machine (Subscription: "your_subscription_id"
│ Resource Group Name: "K3s-Lab"
cted status 404 (404 Not Found) with error: PlatformImageNotFound: The platform image 'Canonical:0001-com-ubuntu-server-kinetic:24_04-lts-gen2:latest' is not available. Verify that all fields in the storage profile are correct. For more details about storage profile information, please refer to https://aka.ms/storageprofile
│
│   with azurerm_linux_virtual_machine.vm_master["VM-master"],
│   on main.tf line 42, in resource "azurerm_linux_virtual_machine" "vm_master":
│   42: resource "azurerm_linux_virtual_machine" "vm_master" {
│
╵
```
**Problema con l'immagine di Ubuntu**
Nel file terraform.tfvars, avevo specificato Ubuntu 24.04 LTS che potrebbe non essere disponibile o non essere correttamente referenziato. Ho verificato, quindi, quali immagini fossero disponibili per la regione scelta, "west europe"

```
#Elenca tutte le offerte Ubuntu disponibili
echo "Offerte Ubuntu disponibili:" az vm image list-offers --location westeurope --publisher Canonical -o table
```
![image](https://github.com/user-attachments/assets/473c9b34-0978-4063-a39c-1b830492bb7a)

**Risultato atteso**
VM
![image](https://github.com/user-attachments/assets/51e796e4-2a78-4e93-9bbe-a3d89a21a908)

Virtual Network
![image](https://github.com/user-attachments/assets/bca7cf45-53a4-4f62-b974-afdc38a57475)

____________________________________________________________

## Network Security Groups: gruppo di sicurezza di rete

main.tf
```
resource "azurerm_network_security_group" "K3s_nsg" {
  name                = "${var.prefix}-nsg"
  location            = azurerm_resource_group.K3s_Lab.location
  resource_group_name = azurerm_resource_group.K3s_Lab.name

  security_rule {
    name                       = "Allow_SSH_TCP_22"
    priority                   = 100
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "22"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }
}

# Associazione del gruppo di sicurezza alla subnet
resource "azurerm_subnet_network_security_group_association" "nsg_association" {
  subnet_id                 = azurerm_subnet.subnet_master.id
  network_security_group_id = azurerm_network_security_group.K3s_nsg.id
}
```



