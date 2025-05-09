# Implementare un cluster K3s su Azure con Terraform e Docker

Si vuole implementare un'infrastruttura su Azure utilizzando Terraform che consiste in un cluster K3s. Su questo cluster verrà
deployato un progetto Docker fornito e disponibile al seguente indirizzo

https://github.com/MrMagicalSoftware/docker-k8s/blob/main/esercitazione-docker-file.md

## Strumenti e Tecnologie
- Terraform

- Azure Resource Manager (azurerm)

- K3s (lightweight Kubernetes)

- Docker

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
## Creazione VM + provisioner
Per la creazione della Virtual machine si è scelto un Ubuntu Server, la scelta dell'immagine ha creato qualche problema per una questione di disponibilità dell'immagine nella regione scelta (nel mio caso West Europe non supportava  "UbuntuServer-18.04-LTS:latest. La soluzione è esposta in "Errori".

Questa configurazione prevede l'installazione da Terraform di docker e K3s come provisioner.
### main.tf
Questa configurazione prevede l'installazione da Terraform di docker e K3s come provisioner. 
Per configurare Docker e K3s come provisioner in una macchina virtuale (VM) utilizzando Terraform, si utilizza il ```provisioner``` "file" e "remote-exec". Questi permettono di copiare uno script di installazione sulla VM e di eseguirlo per installare Docker e K3s.
```
#4. creo la VM
resource "azurerm_linux_virtual_machine" "vm_master" {
  for_each = var.vm_master

  name                            = each.key
  resource_group_name             = azurerm_resource_group.K3s_Lab.name
  location                        = azurerm_resource_group.K3s_Lab.location
  size                            = each.value.vm_size
  admin_username                  = var.admin_username
  admin_password                  = var.admin_password
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
```
Questa parte del **provisioner** deve essere inserita all'interno del blocco di configurazione della VM, dopo essersi premurati di creare un file script.sh.

**Funzionamento di file**

Quando utilizzi il provisioner ```file```, Terraform esegue i seguenti passaggi:

1. **Copia del File**: Terraform copia il file specificato dalla tua macchina locale al percorso di destinazione sulla macchina remota.
2. **Connessione**: Terraform stabilisce una connessione alla macchina remota utilizzando le credenziali fornite (ad esempio, SSH per Linux o WinRM per Windows).
3. **Percorso di Destinazione**: Puoi specificare il percorso di destinazione sulla macchina remota dove desideri che il file venga copiato.

```
  provisioner "file" {
    source      = "setup.sh"      # File locale
    destination = "/tmp/setup.sh" # Path remoto

    connection {
      type     = "ssh"
      user     = var.admin_username
      password = var.admin_password
      host     = azurerm_public_ip.k3s_ip.ip_address
    }
  }
```
**Funzionamento di ```remote-exec```**
Quando utilizzi il provisioner ```remote-exec```, Terraform stabilisce una connessione SSH (o WinRM per Windows) alla VM e quindi esegue i comandi specificati.

1.**Connessione:** Terraform stabilisce una connessione alla VM utilizzando le credenziali fornite (username e password o chiave SSH).
2. **Esecuzione dei Comandi**: Una volta stabilita la connessione, Terraform esegue i comandi specificati nel blocco inline o in un file di script.
3. **Gestione degli Errori**: Se uno dei comandi fallisce (restituisce un codice di uscita diverso da zero), Terraform interrompe l'esecuzione e restituisce un errore.

```
  provisioner "remote-exec" {
    inline = ["chmod +x /tmp/setup.sh", "/tmp/setup.sh"]

    connection {
      type     = "ssh"
      user     = var.admin_username
      password = var.admin_password
      host     = azurerm_public_ip.k3s_ip.ip_address
    }
  }
}
```

**Per il file variables** si è scelto di accedere alla VM con nome utente e password, rendendo la password segreta (è stata inserita nel file .tfvars.secret).  Le variabili come vm_master, admin_username e admin_password sono utilizzate per rendere la configurazione più flessibile, mantenibile e sicura. Inoltre, aiutano a definire configurazioni diverse per ogni VM in modo centralizzato e riutilizzabile, senza ripetere codice.

La variabile admin e password:
- Definisce le variabili per l'username e la password dell'amministratore per tutte le VM. La password è protetta (sensitive) per evitare di esporla nel piano di esecuzione.
- Consente di centralizzare le credenziali di amministratore e di applicarle uniformemente a tutte le VM, pur mantenendo una certa sicurezza per la password.
- Tuttavia, questo metodo ha portato a diversi errori nell'usare il provisioner. Verrà analizzato nella sezione "Errori".

### variables.tf
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

### terraform.tfvars
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
#qui aggiungere admin_password e subscription_id
```
### Errori riscontrati e soluzione

**Errore nella creazione della VM, causato dall'immagine**
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
Nel file terraform.tfvars, avevo specificato Ubuntu 24.04 LTS che potrebbe non essere disponibile o non essere correttamente referenziato. Ho verificato, quindi, quali immagini fossero disponibili per la regione scelta, "west europe"

```
#Elenca tutte le offerte Ubuntu disponibili
echo "Offerte Ubuntu disponibili:" az vm image list-offers --location westeurope --publisher Canonical -o table
```

![image](https://github.com/user-attachments/assets/473c9b34-0978-4063-a39c-1b830492bb7a)

**Errore con il provisioner**
```
│ Error: file provisioner error
│
│   with azurerm_linux_virtual_machine.vm_master["VM-master"],
│   on main.tf line 80, in resource "azurerm_linux_virtual_machine" "vm_master":
│   80:   provisioner "file" {
│
│ timeout - last error: dial tcp 168.63.28.19:22: i/o timeout
```
**1. credenziali di accesso segrete**
Questo errore è dovuto al fatto che Terraform non riesca ad accedere alla VM e quindi non può utilizzare il file.sh, perché le credenziali che ho creato erano "nascoste", ovvero le ho salvate in un file .tfvars.secret in modo che non poossano essere lette automaticamente come variabili. Però, in questo modo Terraform non riuscirà a connettersi con la VM. Pertanto, ho dovuto re-inserire le variabili, esplicitandole nel file .tfvars.

**2. Alla VM manca l'IP pubblico**
Ultimo problema con questa configurazione, è stato il fatto che nella network interface della VM mi sono dimenticata di inserire l'IP pubblico, altro buon motivo per ricevere errori da Terraform:)

**Network interface corretta**
```
resource "azurerm_network_interface" "network_interface_K3s" {
  for_each            = var.vm_master
  name                = "net-int-${var.prefix}-${each.key}"
  location            = azurerm_resource_group.K3s_Lab.location
  resource_group_name = azurerm_resource_group.K3s_Lab.name

  ip_configuration {
    name                          = "ipconfig"
    subnet_id                     = azurerm_subnet.subnet_master.id
    private_ip_address_allocation = "Static"
    public_ip_address_id          = azurerm_public_ip.k3s_ip.id
  }
}
```
**Errore Risorsa già esistente, devo esportarla**
```
╷  
│ Error: Index value required
│
│   on <import-address> line 1:
│    1: azurerm_linux_virtual_machine.vm_master[VM-master]
│
│ Index brackets must contain either a literal number or a literal string.
╵

For information on valid syntax, see:
https://developer.hashicorp.com/terraform/cli/state/resource-addressing
```

**Risultato atteso**
VM
![image](https://github.com/user-attachments/assets/51e796e4-2a78-4e93-9bbe-a3d89a21a908)

Virtual Network
![image](https://github.com/user-attachments/assets/bca7cf45-53a4-4f62-b974-afdc38a57475)

____________________________________________________________

## Network Security Groups: gruppo di sicurezza di rete
![Screenshot 2025-05-07 160813](https://github.com/user-attachments/assets/408773c8-5168-4e6c-945f-209f906fd3ba)

Per eseguire l'accesso alla VM è necessario creare una regola Inbound per l'accesso alla porta 22 in SSH.
Per garantire il corretto funzionamento dell'ambiente Kubernetes (K3s) e Docker configurato nello script setup.sh, è necessario configurare alcune regole di sicurezza di rete che permettano la comunicazione sulle porte richieste. Ecco uno script che configura le regole firewall necessarie:
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
etc...
}

# Associazione del gruppo di sicurezza alla subnet
resource "azurerm_subnet_network_security_group_association" "nsg_association" {
  subnet_id                 = azurerm_subnet.subnet_master.id
  network_security_group_id = azurerm_network_security_group.K3s_nsg.id
}
```
Per i Gruppi di sicurezza ho dovuto creare (verificando online), delle regole che permettessero il traffico da qualsiasi origine (non è molto sicuro, soprattutto quando si parla della porta 22 SSH). Infatti, in ambiente di produzione sarebbe meglio associare le regole solo ad indirizzi IP sicuri.

Ho ordinato le regole in base alla priorità e associato le regole alla subnet in questione.
![Screenshot 2025-05-07 160822](https://github.com/user-attachments/assets/7d7cf937-db57-4efa-8d93-04def3ec6623)


**Regole di Base**
1. SSH (porta 22) - Priorità 100: Permette la connessione SSH per la gestione remota delle VM.

**Regole per le applicazioni web come Nginx**

2. HTTP (porta 80) - Priorità 300: Consente il traffico HTTP per applicazioni web come NGINX.

3. HTTPS (porta 443) - Priorità 310: Consente il traffico HTTPS sicuro.
__________________________________________________________
# 3. Deployment dell'applicazione setup.sh
Questo file verrà copiato ed eseguito da Terraform nella VM creata. Oltre ai comandi di installazione di docker e K3s, bisogna creare anche 2 file YAML, uno per il deployment e uno per il service.

L'operazione che è stata utilizzata e la redirezione cat <<EOF > file.yaml, questo file avrà al suo interno la versione, la tipologia di servizio, i metadata etc... necessari per la configurazione.

## Come è stato creato il file setup.sh: errori e troubleshooting
1. Mi sono resa conto che ci fosse un errore quando il deployment in Terraform stava durando 50 minuti. Quindi ho deciso di controllare tutti i messaggi di outpput del deployment per verificare dove il codice si fosse fermato.
Il deployment di fermava ad un messaggio che richiedeva di validare l'operazione con [ENTER] O [CTRL-C]. Andando ad analizzare il file sh, infatti, mi sono accorta che ci fosse ```sudo add-apt-repository "deb [arch=amd64] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable" ``` senza il ```-y```, ovvero il sistema di conferma automatica.
**Spiegazione:**
```add-apt-repository``` può, a seconda del sistema e della configurazione, aprire un prompt interattivo (soprattutto se si usa per aggiungere PPA) chiedendo di premere ENTER per confermare l'aggiunta del repository. Anche se in questo caso si tratta di un repository generico (non PPA), su alcune versioni di Ubuntu può ancora apparire la richiesta di conferma.

**Come evitare il prompt:**
Puoi forzare la modalità non interattiva usando -y:
```
sudo add-apt-repository -y "deb [arch=amd64] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable"
```
3. Tuttavia, una volta fatto un ```terraform destroy``` e ```terraform apply``` e, dopo essere entrata nella VM alla fine del deployment, mi sono accorta che non fossero installati nè docker nè K3s. Risultava, invece, che fossero stati creati correttamente la cartella ```hello-docker``` e i file.yaml.
Quindi ho ripreso il file sh e ho testato uno a uno i comandi nella VM. Ho notato subito che la mancata installazione dei pacchetti era dovuta da:

```
sudo apt-get update

# Installa i pacchetti necessari
sudo apt install apt-transport-https ca-certificates curl software-properties-common -y

# Aggiungi la chiave GPG del repository di Docker
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo apt-key add -

# Aggiungi il repository di Docker
sudo add-apt-repository "deb [arch=amd64] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable"

# Aggiorna nuovamente l'elenco dei pacchetti
sudo apt update
```
Seppur, in altri lab, questi comandi funzionassero correttamente, ho dovuto fare una ricerca per capire quale fosse un altro sistema per automatizzare l'installazione di docker, creando correttamente la directory per la chiave GPG (chiave pubblica crittografica utilizzata per verificare l'autenticità dei pacchetti Docker) e per aggiungere il repository di docker.

Sono andata quindi a verificare metodi alternativi,, direttamente nel sito di Docker: https://docs.docker.com/engine/install/ubuntu/ e ho testato i comandi:

```
# Crea directory per chiave GPG
sudo mkdir -p /etc/apt/keyrings

# Aggiungi la chiave GPG
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | \
  sudo gpg --dearmor -o /etc/apt/keyrings/docker.gpg

# Aggiungi il repository Docker
echo \
  "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] \
  https://download.docker.com/linux/ubuntu \
  $(lsb_release -cs) stable" | \
  sudo tee /etc/apt/sources.list.d/docker.list > /dev/null
```
**A questo punto i pacchetti si sono installati correttamente!**

**Installazione K3s**
K3s è una distribuzione leggera di Kubernetes progettata per essere facile da installare e gestire, particolarmente adatta per ambienti edge, IoT e sviluppo. È sviluppata da Rancher Labs e include molte delle funzionalità di Kubernetes, ma con un ingombro ridotto e una configurazione semplificata. K3s è progettato per funzionare bene su hardware con risorse limitate e può essere eseguito in modo efficiente su macchine virtuali o dispositivi a bassa potenza.
```
# Installa K3s
curl -sfL https://get.k3s.io | sh -s - --write-kubeconfig-mode 644

# Attendi che K3s sia completamente avviato
sleep 30

# Avvio servizio K3s (questo è ridondante perché K3s si avvia automaticamente dopo l'installazione)
sudo systemctl enable k3s && sudo systemctl start k3s

# K3s già crea un symlink per kubectl, ma verifichiamo se esiste
sudo ln -s /usr/local/bin/k3s /usr/local/bin/kubectl

#Modifica i permessi del file kubeconfig
sudo chmod 644 /etc/rancher/k3s/k3s.yaml

# Salva la versione di Kubernetes
export KUBEVERSION=$(kubectl version)
```
**"EOF" (End Of File)** è un marcatore utilizzato in programmazione e nei sistemi operativi Unix/Linux che indica la fine di un input di testo. Nel contesto degli script bash, EOF viene utilizzato in particolare con i comandi "here document" (heredoc) che sono identificati dalla sintassi **cat <<EOF > file.yaml o cat <<EOT > file.conf**.
```
# Creazione struttura del progetto Node.js
mkdir -p hello-docker
cd hello-docker

# Crea il file app.js
cat <<EOF > app.js
const express = require('express');
const app = express();
const port = 3000;

app.get('/', (req, res) => {
    res.send('Hello, World!');
});

app.listen(port, '0.0.0.0', () => {
    console.log(\`App listening at http://0.0.0.0:\${port}\`);
});
EOF

# Crea il file package.json
cat <<EOF > package.json
{
  "name": "hello-docker",
  "version": "1.0.0",
  "main": "app.js",
  "scripts": {
    "start": "node app.js"
  },
  "dependencies": {
    "express": "^4.17.1"
  }
}
EOF

#npm install per le dipendenze
sudo apt npm install -y
sudo npm install

# Crea il Dockerfile
cat <<EOF > Dockerfile
# Usa un'immagine base di Node.js
FROM node:14

# Imposta la cartella di lavoro
WORKDIR /usr/src/app

# Copia il file package.json e installa le dipendenze
COPY package*.json ./
RUN npm install

# Copia il resto dell'applicazione
COPY . .

# Espone la porta su cui l'app ascolta
EXPOSE 3000

# Comando per avviare l'app
CMD ["npm", "start"]
EOF

# Costruisci l'immagine Docker
sudo docker build -t hello-docker:latest .

# Salva l'immagine come file tar per importarla in K3s
sudo docker save hello-docker:latest -o hello-docker.tar

# Importa l'immagine nel registro interno di K3s
sudo k3s ctr --namespace=k8s.io images import hello-docker.tar
```
3. In questo caso, invece, nella prima versione del file mi sono dimenticata di **installare npm**, ho aggiunto il comando per completare tutti i passaggi per la creazione dell'immagine Docker.
Un altro problema che ho avuto in questa sezione, era il salvataggio del file.tar (un tipo di file di archivio utilizzato per raccogliere e combinare più file in un unico file gestibile) per l'importazione nel custer di k3s.
Ci sono diverse possibili cause per cui l'importazione non sta avvenendo correttamente:

- **Namespace mancante nella fase di importazione**: K3s utilizza containerd che richiede un namespace. Il comando di importazione dovrebbe specificare il namespace corretto.
- **Path dell'immagine non aggiornato**: Dopo l'importazione, il nome dell'immagine potrebbe non essere accessibile come ti aspetti.
- **Problema di permessi** nei file o comandi.

Ho dovuto testare un comando diverso da quello che usavo inizialmente ```sudo k3s ctr images import hello-docker.tar```

**comando aggiornato**
```
# Importa l'immagine nel registro interno di K3s
sudo k3s ctr --namespace=k8s.io images import hello-docker.tar
```
Per verificare che l'operazione sia andata a buon fine:
```
sudo k3s ctr images ls | grep hello-docker
```
**Restituisce, se tutto va bene**
![image](https://github.com/user-attachments/assets/122d19aa-95ca-4a6f-9370-5d6460840613)
![image](https://github.com/user-attachments/assets/9878ec78-ba37-4bf8-82ca-34cc81873d65)

Infine, ho modificato il file deployment.yaml affinché utilizzasse l'immagine hello-docker e h agggiunto ```imagePullPolicy: IfNotPresent``` ( Kubernetes controllerà se l'immagine richiesta è già presente nel nodo. Se l'immagine è già disponibile, non verrà effettuato alcun pull (estrazione) dall'immagine. Se l'immagine non è presente, Kubernetes procederà a scaricarla dal registro delle immagini).

![image](https://github.com/user-attachments/assets/070f67c1-f051-4570-8013-d708710287b5)


### Creazione del file YAML per il Deployment
Crea un file deployment.yaml direttamente nella VM che definisce un deployment Kubernetes. Questo deployment:
- Crea 3 repliche (pod) di un container NGINX
- Definisce etichette per la selezione e l'identificazione
- Configura il container per esporre la porta 80
![image](https://github.com/user-attachments/assets/90b356d5-a6b1-40fa-bb3b-edee8453afbe)

```
cat <<EOF > deployment.yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: nodejs-app
  labels:
    app: nodejs_app
spec:
  replicas: 3
  selector:
    matchLabels:
      app: nodejs_app
  template:
    metadata:
      labels:
        app: nodejs_app
    spec:
      containers:
      - name: nodejs-app
        image: docker.io/library/hello-docker:latest
        imagePullPolicy: IfNotPresent
        ports:
        - containerPort: 3000
EOF
```
### Creazione del file YAML per il Service
Crea un file service.yaml che definisce un service Kubernetes direttamente nella VM. Questo service:
- Espone i pod creati dal deployment tramite un singolo indirizzo IP interno al cluster
- Indirizza il traffico verso la porta 80 dei pod con l'etichetta "app: example"
- È di tipo ClusterIP, quindi accessibile solo dall'interno del cluster

```
# Creazione del file YAML per il Service
cat <<EOF > service.yaml
apiVersion: v1
kind: Service
metadata:
  name: nodejs-app-service
spec:
  selector:
    app: nodejs-app
  ports:
  - port: 80
    targetPort: 3000
    nodePort: 30080
  type: NodePort
EOF

#applicazione file yaml
kubectl apply -f deployment.yaml
kubectl apply -f service.yaml

# Attendi che i pod siano pronti
sleep 10
```
# Risultati attesi
Dopo l'ultimo test senza aprire la VM il codice funziona, deploya tutto quello che deve deployare ed ecco il nostro **Hello,World!**

![image](https://github.com/user-attachments/assets/68770f99-121e-4bfc-a85c-941eddba75a5)

## Conclusioni
In questo lab ho cercato di creare un codice in Terraform che fosse riutillizzabile attraverso le variabili che ho impostato. 
Infatti, se si volesse, si potrebbero aggiungere nel file variables.tf tante vm quante ne servono per il deployment; in main.tf il codice è adatto per un ciclo di creazione di più VM.

Per quanto riguarda il file.sh, sono riuscita a leggere gli output in Terraform per capire a quale blocco del file si fosse interrotto il deployment, in questo modo è stato più semplice capire dove e quali comandi modificare per il corretto funzionamento del provisioner. 

Ad ora, ecco come dovrebbe apparire il deployment in Terraform
![image](https://github.com/user-attachments/assets/8ad3ffff-3724-4bcb-8085-05cd3a222052)
![image](https://github.com/user-attachments/assets/d1c48d0c-f2ac-4d2b-b0a9-2982d0b7ed40)

Grazie agli output che ho creato, ho ottenuto l'ip pubblico della vm e ho potuto verificare il corretto funzionamento del pod all'indirizzo-ip-pubblico:porta-nodeport.

**Attenzione**: è importante ricordarsi di creare le dovute nsg per esporre le porte scelte nel file deployment.yaml.

### Verifica finale nella VM
**sudo docker version**
![image](https://github.com/user-attachments/assets/15c2ca1c-5f5b-47ae-a132-826553f429e0)

**sudo k3s version**
![image](https://github.com/user-attachments/assets/67160e04-b79d-4666-83f4-77f0841dc262)


**kubectl get pods**
![image](https://github.com/user-attachments/assets/6ab97013-a90c-4464-b5a8-e9d647c48700)

**sudo docker images**
![image](https://github.com/user-attachments/assets/16f87494-37c3-4794-8788-6aa2e39ddfbc)

**cat deployment.yaml**
![image](https://github.com/user-attachments/assets/5eaabf1e-5313-459d-80ec-09b325362fc7)

**cat service.yaml**
![image](https://github.com/user-attachments/assets/290300b2-af10-4c28-b70b-cf1642fc6cb8)





_Gracefully shutting down..._ cit. Terraform


