# Rozbehanie novej Linux mašiny

## Obsah

1. [Pripojenie a základná konfigurácia](#1-pripojenie-a-základná-konfigurácia)
2. [Inštalácia základných nástrojov](#2-inštalácia-základných-nástrojov)
3. [Kubernetes prostredie](#3-kubernetes-prostredie)
4. [Azure DevOps integrácia](#4-azure-devops-integrácia)
5. [Docker image príprava](#5-docker-image-príprava)
6. [Build agenti nasadenie](#6-build-agenti-nasadenie)
7. [Správa a údržba](#7-správa-a-údržba)

---

## 1. Pripojenie a základná konfigurácia

### Pripojenie cez SSH

Prípojíme sa cez ssh príkazom `ssh [meno_uzivatela]@[ip_adresa]`. IP adresu zistíme pri inštalácii Linuxu na mašiny, konkrétne pri nastavovaní SSH prístupu.

```bash
ssh kostelej@192.168.2.213
```

### Aktualizácia systému

```bash
sudo apt update                    # aktualizácia zoznamu balíkov
sudo apt dist-upgrade -y           # upgrade balíkov
sudo apt autoremove -y             # odstránenie nepoužívaných balíkov
```

### Automatická aktualizácia

```bash
sudo apt install unattended-upgrades
sudo dpkg-reconfigure --priority=low unattended-upgrades
```

### Optimalizácia výkonu

**Zníženie swappiness (optimalizácia pre RAM):**

```bash
sudo nano /etc/sysctl.conf
```

Vložíme na koniec súboru `vm.swappiness=10` a uložíme.

---

## 2. Inštalácia základných nástrojov

### Docker

Postupovať podľa oficiálnej dokumentácie: [Docker](https://docs.docker.com/engine/install/ubuntu/)

Nastaviť prístupové práva pre `docker` grupu:

```bash
sudo usermod -aG docker $USER
```

### Portainer (voliteľné)

Portainer je webová aplikácia pre správu Docker kontajnerov. Nie je potrebná pre fungovanie, ale je užitočná pri úpravách dockerfile alebo testovaní kontajnerov.

```bash
docker volume create portainer_data
docker run -d -p 8000:8000 -p 9000:9000 --name portainer --restart=always \
  -v /var/run/docker.sock:/var/run/docker.sock \
  -v portainer_data:/data \
  portainer/portainer-ce
```

Prístup: `http://[ip_adresa]:9000`

### ncdu (voliteľné)

Nástroj pre prehľadné zobrazenie priestoru na disku.

```bash
sudo apt install ncdu
ncdu /
```

### Kubernetes CLI

Na manažovanie kontajnerov využívame Kubernetes.
Postupovať podľa oficiálnej dokumentácie: [Kubernetes](https://kubernetes.io/docs/tasks/tools/install-kubectl-linux/)

### Helm

Helm je správcovský nástroj pre Kubernetes. Zjednodušuje proces vytvárania, upgradovania a odstraňovania podov.

```bash
curl https://baltocdn.com/helm/signing.asc | gpg --dearmor | sudo tee /usr/share/keyrings/helm.gpg > /dev/null
sudo apt-get install apt-transport-https --yes
echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/helm.gpg] https://baltocdn.com/helm/stable/debian/ all main" | sudo tee /etc/apt/sources.list.d/helm-stable-debian.list
sudo apt-get update
sudo apt-get install helm
```

### K9s (voliteľné)

K9s je prehľadný nástroj pre správu Kubernetes. Nie je potrebný pre fungovanie, ale je veľmi užitočný pri úpravách v Kubernetes.

```bash
curl -Lo k9s.tar.gz https://github.com/derailed/k9s/releases/latest/download/k9s_Linux_amd64.tar.gz
tar -xvf k9s.tar.gz
chmod +x k9s
sudo mv k9s /usr/local/bin/
k9s version # overiť inštaláciu
```

### Stiahnutie repozitára

V repozitári sú uložené manifesty pre Build Agentov. Tie budú potrebné pre vytvorenie podov v Kubernetes.

```bash
git clone -b master https://github.com/Kros-sk/kros-sk.github.io.git
```

---

## 3. Kubernetes prostredie

### Vytvorenie clusteru (K3s)

K3s je odľahčená verzia Kubernetes.

```bash
curl -sfL https://get.k3s.io | sh -
sudo cp /etc/rancher/k3s/k3s.yaml ~/.kube/config  # prekopírovanie KUBECONFIG
```

Po nainštalovaní bude K3s služba nakonfigurovaná aby sa automaticky reštartovala po reboote nodu alebo v prípade zlyhania či ukončenia procesu.

**Zmazanie clusteru (odinštalovanie):**

```bash
/usr/local/bin/k3s-uninstall.sh
```

### Vytvorenie namespace

```bash
kubectl create namespace build-agents
kubectl config set-context --current --namespace=build-agents
```

### Nainštalovanie KEDA

Pomocou KEDA dokážeme automaticky škálovať počet agentov v závislosti na počte jobov v pool-e.

```bash
kubectl apply --server-side -f https://github.com/kedacore/keda/releases/download/v2.17.2/keda-2.17.2-core.yaml
```

---

## 4. Azure DevOps integrácia

### Vytvorenie secretov

Nastaviť PAT do Azure DevOps. Token musí mať právo `Read & manage` pre scope `Agent Pools`.
Taktiež treba nastaviť DEVEXTREME_KEY (doplniť z aktuálnych mašín).

```bash
kubectl create secret generic azure-pat-token --from-literal=AZURE_PAT_TOKEN=<VYGENEROVANY_TOKEN>
kubectl create secret generic devextreme-key --from-literal=DEVEXTREME_KEY=<VYGENEROVANY_KEY>
```

---

## 5. Docker image príprava

Ak sa nemenilo nič v image pre Build Agentov, tak buildovať ani pushovať image na registry netreba. Vytvorenie secretu je však potrebné.

### Build docker image

```bash
docker build -t azure-agent-linux:k8s -f azure-agent-linux.dockerfile .
```

### Prihlásenie do Azure Container Registry

```bash
az login
az acr login --name krossk
```

### Nahratie image do Azure Container Registry

Docker image sa nahrá do privátneho registry [krossk](https://portal.azure.com/#@kros.sk/resource/subscriptions/0f009b83-9652-4e0f-b891-2e6d816ecb88/resourcegroups/esw-shared-rsg/providers/microsoft.containerregistry/registries/krossk/overview).

```bash
docker tag azure-agent-linux:k8s krossk.azurecr.io/azure-agent-linux:k8s
docker push krossk.azurecr.io/azure-agent-linux:k8s
```

### Vytvorenie secretu pre prístup k ACR

```bash
# Vytvorenie service principal s prístupom ku ACR
az ad sp create-for-rbac \
  --name "[build-machine-name]-acr-sp" \
  --role "AcrPull" \
  --scopes "/subscriptions/0f009b83-9652-4e0f-b891-2e6d816ecb88/resourceGroups/esw-shared-rsg/providers/Microsoft.ContainerRegistry/registries/krossk"

# Výstup bude obsahovať appId (username) a password
kubectl create secret docker-registry acr-secret \
  --docker-server=krossk.azurecr.io \
  --docker-username=<service-principal-id> \
  --docker-password=<service-principal-password> \
  --namespace=build-agents
```

---

## 6. Build agenti nasadenie

### Vytvorenie Helm chartu

Vytváranie podov pre jednotlivé pooly je riešené cez nástroj [Helm](https://helm.sh/). Pre nasadenie sa využíva spoločný template manifest pre všetky pooly, do ktorých sa dosadia hodnoty podľa toho pre aký pool sa vytvára.
Hodnoty sa dosadzujú cez values súbory v adresári [charts/build-agents-chart/values](charts/build-agents-chart/values). Každý pool má vlastný values súbor.

```bash
mkdir /opt/Agents/agentCharts
cd /opt/Agents/agentCharts

# Vytvorenie shared-resources chartu (zdieľané resources ako PVC)
helm create shared-resources-chart
rm -rf shared-resources-chart/templates
rm -rf shared-resources-chart/values.yaml

# Vytvorenie build-agents chartu
helm create build-agents-chart
rm -rf build-agents-chart/templates
rm -rf build-agents-chart/values.yaml

# Prekopírovanie chartov z repozitára
cp [cesta_k_priečinku_s_chartom]/shared-resources-chart/ /opt/Agents/agentCharts/
cp [cesta_k_priečinku_s_chartom]/build-agents-chart/ /opt/Agents/agentCharts/
# napr. cp -r ~/kros-sk.github.io/linuxmachine/charts/shared-resources-chart/ /opt/Agents/agentCharts/
# napr. cp -r ~/kros-sk.github.io/linuxmachine/charts/build-agents-chart/ /opt/Agents/agentCharts/
```

### Nasadenie build agentov

**Najprv nasadíme zdieľané resources:**

```bash
# Nasadenie zdieľaných resources (PVC)
helm install shared-resources /opt/Agents/agentCharts/shared-resources-chart --namespace build-agents
```

**Overenie manifestu pre build agentov:**

```bash
helm install [pomenovanie_release] /opt/Agents/agentCharts/build-agents-chart \
  --values /opt/Agents/agentCharts/build-agents-chart/values/[nazov_values_suboru] \
  --namespace build-agents \
  --dry-run
```

Vo výstupe môžeme skontrolovať či nám správne dosadilo hodnoty z values súboru.

**Aplikovanie manifestu pre build agentov:**

```bash
helm install [pomenovanie_release] /opt/Agents/agentCharts/build-agents-chart \
  --values /opt/Agents/agentCharts/build-agents-chart/values/[nazov_values_suboru] \
  --namespace build-agents
```

Ak chceme na mašine vytvoriť všetky pooly, tak treba zavolať helm install pre každý values súbor:

```bash
helm install build-be /opt/Agents/agentCharts/build-agents-chart --values /opt/Agents/agentCharts/build-agents-chart/values/values-build-be.yaml --namespace build-agents
helm install build-fe /opt/Agents/agentCharts/build-agents-chart --values /opt/Agents/agentCharts/build-agents-chart/values/values-build-fe.yaml --namespace build-agents
helm install default /opt/Agents/agentCharts/build-agents-chart --values /opt/Agents/agentCharts/build-agents-chart/values/values-default.yaml --namespace build-agents
helm install deploy-be /opt/Agents/agentCharts/build-agents-chart --values /opt/Agents/agentCharts/build-agents-chart/values/values-deploy-be.yaml --namespace build-agents
helm install deploy-fe /opt/Agents/agentCharts/build-agents-chart --values /opt/Agents/agentCharts/build-agents-chart/values/values-deploy-fe.yaml --namespace build-agents
```

---

## 7. Správa a údržba

### Kontrola stavu

```bash
kubectl get pods -n build-agents
kubectl get pvc -n build-agents
kubectl get configmap -n build-agents
kubectl get scaledobject -n build-agents
helm ls -n build-agents  # zobraziť všetky release cez Helm
```

PVC "agent-cache-pvc" sa zobrazuje ako súčasť "shared-resources" release a je zdieľaný medzi všetkými build agent poolmi.

Alternatívne môžeme použiť k9s. Dokumentácia: [k9s](https://k9scli.io/)

### Aktualizácia build agentov

Ak potrebujeme upraviť build agentov, t.j. upravovať chart (buď values alebo samotný template), tak môžeme updatovať release cez `helm upgrade`.

```bash
helm upgrade [pomenovanie_release] /opt/Agents/agentCharts/build-agents-chart \
  --values /opt/Agents/agentCharts/build-agents-chart/values/[nazov_values_suboru] \
  --namespace build-agents
```

Pokiaľ sa nezmenilo nič v manifestoch ale len docker image, tak po upgrade treba reštartnuť pody v konkrétnom StatefulSet, inak nebude vedieť že je dostupný novší image.

```bash
kubectl rollout restart statefulset/[pomenovanie_statefulset] --namespace build-agents
```

### Rollback zmien

Ak sa po úpravach niečo pokazilo a chceme sa vrátiť k pôvodnému stavu, tak môžeme použiť `helm rollback`.

```bash
helm rollback [pomenovanie_release] [číslo_revision] -n build-agents
```

Ak potrebujem overiť ako vyzerali manifesty pre release v konkrétnej revision, tak môžem použiť:

```bash
helm get all [pomenovanie_release] --revision [číslo_revision] -n build-agents
```

### Odstránenie build agentov

```bash
helm uninstall [pomenovanie_release] -n build-agents
```
