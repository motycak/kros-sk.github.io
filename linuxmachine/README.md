# Rozbehanie novej Linux mašiny

## Pripojenie cez ssh

Prípojíme sa cez ssh príkazom `ssh [meno_uzivatela]@[ip_adresa]`. Ip adresu zistíme pri inštalácii Linuxu na mašiny, konkrétne pri nastavovaní ssh prístupu. Príkaz je napr.:

```bash
ssh kostelej@192.168.2.213
```

## Aktualizácia appiek

```bash
sudo apt update # update package list
sudo apt dist-upgrade -y # upgrade packages
sudo apt autoremove -y # remove unused packages
```

## Automatická aktualizácia

```bash
sudo apt install unattended-upgrades
sudo dpkg-reconfigure --priority=low unattended-upgrades
```

## Zníženie swappiness (optimalizácia pre RAM)

```bash
sudo nano /etc/sysctl.conf
```

Vložíme na koniec súboru `vm.swappiness=10` a uložíme.

## Inštalácia Docker

Postupovať podľa oficiálnej dokumentácie: [Docker](https://docs.docker.com/engine/install/ubuntu/)

Nastaviť prístupové práva pre `docker` grupu.

```bash
sudo usermod -aG docker $USER
```

## Inštalácia Portainer (voliteľné)

Portainer je webová aplikácia pre správu Docker kontajnerov. Nie je potrebná pre fungovanie ale je užitočná pri úpravach dockerfile alebo keď chceme niečo s kontajnermi testovať.

```bash
docker volume create portainer_data
docker run -d -p 8000:8000 -p 9000:9000 --name portainer --restart=always -v /var/run/docker.sock:/var/run/docker.sock -v portainer_data:/data portainer/portainer-ce
```

Po inštalácii sa dá pristupovať na adrese `http://[ip_adresa]:9000`.

## Stiahnutie [kros-sk.github.io](https://github.com/Kros-sk/kros-sk.github.io) repozitára

V repozitári sú uložené manifesty pre Build Agentov. Tie budú potrebné pre vytvorenie podov v kubernetes.

```bash
git clone -b master https://github.com/Kros-sk/kros-sk.github.io.git
```

## Spustenie kontajnerov

Na spustenie kontajnerov vieme použiť 2 prístupy:

### Orchestrácia kontajnerov TODO (kubernetes/docker swarm)

Máme nad správaním kontajnerov väčšiu kontrolu a viac možností. TODO pokračovať.

## Inštalácia Kubernetes

Na manažovanie kontajnerov využívame Kubernetes.
Pre nainštalovanie postupovať podľa oficiálnej dokumentácie: [Kubernetes](https://kubernetes.io/docs/tasks/tools/install-kubectl-linux/)

## Inštalácia Helm

Helm je správcovský nástroj pre Kubernetes. Zjednodušuje proces vytvárania, upgradovania a odstraňovania podov.

```bash
curl https://baltocdn.com/helm/signing.asc | gpg --dearmor | sudo tee /usr/share/keyrings/helm.gpg > /dev/null
sudo apt-get install apt-transport-https --yes
echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/helm.gpg] https://baltocdn.com/helm/stable/debian/ all main" | sudo tee /etc/apt/sources.list.d/helm-stable-debian.list
sudo apt-get update
sudo apt-get install helm
```

## Inštalácia K9s (voliteľné)

K9s je prehľadný nástroj pre správu Kubernetes. Nie je potrebný pre fungovanie ale vie byť veľmi užitočný pri úpravách v kubernetes.

```bash
curl -Lo k9s.tar.gz https://github.com/derailed/k9s/releases/latest/download/k9s_Linux_amd64.tar.gz
tar -xvf k9s.tar.gz
chmod +x k9s
sudo mv k9s /usr/local/bin/
k9s version # overiť inštaláciu
```

## Vytvorenie secretu s PAT tokenom

Nastaviť PAT do Azure DevOps. Bude sa ku nemu pristupovať v podoch. Token musí mať právo `Read & manage` pre scope `Agent Pools`.
Taktiež treba nastaviť DEVEXTREME_KEY (doplniť z aktuálnych mašín). Nájdeme v Capabilities, prípadne priamo na inej mašine v environment variables.

```bash
kubectl create secret generic azure-pat-token --from-literal=AZURE_PAT_TOKEN=<VYGENEROVANY_TOKEN>
kubectl create secret generic devextreme-key --from-literal=DEVEXTREME_KEY=<VYGENEROVANY_KEY>
```

## Vytvorenie clusteru (K3s)

K3s je odľahčená verzia Kubernetes.

```bash
curl -sfL https://get.k3s.io | sh -
sudo cp /etc/rancher/k3s/k3s.yaml ~/.kube/config # prekopírovanie KUBECONFIG
```

Po nainštalovaní bude K3s služba nakonfigurovaná aby sa automaticky reštartovala po reboote nodu alebo v prípade zlyhania či ukončenia procesu.

Zmazanie clusteru (odinštalovanie):

```bash
/usr/local/bin/k3s-uninstall.sh
```

## Vytvorenie namespace

```bash
kubectl create namespace build-agents
kubectl config set-context --current --namespace=build-agents # Nastavenie defaultneho namespace
```

## Nainštalovanie KEDA

Pomocou KEDA dokážeme automaticky škálovať počet agentov v závislosti na počte čakajúcich úloh v Azure DevOps. Využíva sa v manifestoch pre Build Agentov.

```bash
kubectl apply --server-side -f https://github.com/kedacore/keda/releases/download/v2.17.0/keda-2.17.0-core.yaml
```

## Príprava docker image

Ak sa nemenilo nič v image pre Build Agentov [azure-agent-linux.dockerfile](azure-agent-linux.dockerfile), tak buildovať ani pushovať na registry netreba. Vytvorenie secretu ale je potrebné aby mohli pody pristupovať na image v registry.

### Build docker image

Vytvorenie docker image pre Build Agentov.

```bash
docker build -t azure-agent-linux:k8s -f azure-agent-linux.dockerfile .
```

### Prihlásenie do Azure Container Registry

```bash
az login
az acr login --name krossk
```

### Nahratie image do Azure Container Registry

Docker image sa nahrá do nášho privátneho registry. [krossk](https://portal.azure.com/#@kros.sk/resource/subscriptions/0f009b83-9652-4e0f-b891-2e6d816ecb88/resourcegroups/esw-shared-rsg/providers/microsoft.containerregistry/registries/krossk/overview)

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

## Vytvorenie Helm chartu

Vytváranie podov pre jednotlivé pooly je riešené cez nástroj [Helm](https://helm.sh/). Pre nasadenie sa využíva spoločný template manifest pre všetky pooly (v priečinku [templates](charts/build-agents-chart/templates)), do ktorých sa dosadia hodnoty podľa toho pre aký pool sa vytvára.
Hodnoty sa dosadzujú cez values súbory v adresári [charts/build-agents-chart/values](charts/build-agents-chart/values). Každý pool má vlastný values súbor.
Najprv potrebujeme na mašine vytvoriť adresár pre charty.

```bash
mkdir /opt/Agents/agentCharts
cd /opt/Agents/agentCharts
helm create build-agents-chart # vytvorenie defaultného chartu
#Odstranenie nepotrebných súborov (použijeme vlastné)
rm -rf build-agents-chart/templates
rm -rf build-agents-chart/values.yaml
# Prekopírovanie chartu z repozitára do adresára /opt/Agents/agentCharts/
cp [cesta_k_priečinku_s_chartom] /opt/Agents/agentCharts/ # napr. cp ~/kros-sk.github.io/linuxmachine/charts/build-agents-chart/ /opt/Agents/agentCharts/
```

## Vytvorenie podov s build agentmi cez Helm chart

Najprv si môžeme overiť vygenerovaný manifest.

```bash
helm install [pomenovanie_release] /opt/Agents/agentCharts/build-agents-chart --values /opt/Agents/agentCharts/build-agents-chart/values/[nazov_values_suboru] --namespace build-agents --dry-run
```

Vo výstupe môžeme skontrolovať či nám správne dosadilo hodnoty z values súboru.

Následne môžeme manifest aplikovať.

```bash
helm install [pomenovanie_release] /opt/Agents/agentCharts/build-agents-chart --values /opt/Agents/agentCharts/build-agents-chart/values/[nazov_values_suboru] --namespace build-agents
```

Ak chceme na mašine vytvoriť všetky pooly, tak treba zavolať helm install pre každý values súbor:

```bash
helm install build-be /opt/Agents/agentCharts/build-agents-chart --values /opt/Agents/agentCharts/build-agents-chart/values/values-build-be.yaml --namespace build-agents
helm install build-fe /opt/Agents/agentCharts/build-agents-chart --values /opt/Agents/agentCharts/build-agents-chart/values/values-build-fe.yaml --namespace build-agents
helm install default /opt/Agents/agentCharts/build-agents-chart --values /opt/Agents/agentCharts/build-agents-chart/values/values-default.yaml --namespace build-agents
helm install deploy-be /opt/Agents/agentCharts/build-agents-chart --values /opt/Agents/agentCharts/build-agents-chart/values/values-deploy-be.yaml --namespace build-agents
helm install deploy-fe /opt/Agents/agentCharts/build-agents-chart --values /opt/Agents/agentCharts/build-agents-chart/values/values-deploy-fe.yaml --namespace build-agents
```

Použiteľné príkazy pre kontrolu stavu:

```bash
kubectl get pods -n build-agents
kubectl get pvc -n build-agents
kubectl get configmap -n build-agents
kubectl get scaledobject -n build-agents
helm ls -n build-agents # zobraziť všetky release cez Helm
```

Alternatívne môžeme použiť k9s.

Ak potrebujeme upraviť build agentov, t.j. upravovať chart (buď values alebo samotný template), tak môžeme updatovať release cez `helm upgrade`.

```bash
helm upgrade [pomenovanie_release] /opt/Agents/agentCharts/build-agents-chart --values /opt/Agents/agentCharts/build-agents-chart/values/[nazov_values_suboru] --namespace build-agents
```

Ak sa po úpravach niečo pokazilo a chceme sa vrátiť k pôvodnému stavu, tak môžeme použiť `helm rollback`.

```bash
helm rollback [pomenovanie_release] [číslo_revision] -n build-agents
```

Ak potrebujem overiť ako vyzerali manifesty pre release v konkrétnej revision, tak môžem použiť:

```bash
helm get all [pomenovanie_release] --revision [číslo_revision] -n build-agents
```

## Odstránenie build agentov

```bash
helm uninstall [pomenovanie_release] -n build-agents
```
