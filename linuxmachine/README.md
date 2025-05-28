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

Nastaviť PAT do Azure DevOps. Bude sa ku nemu pristupovať v [docker-compose.yml](docker-compose.yml). Token musí mať právo `Read & manage` pre scope `Agent Pools`.

```bash
docker swarm init
echo "VYGENEROVANY_TOKEN" | docker secret create azure_pat_token -
docker secret ls # zobraziť secrety
```

## Vytvorenie adresárov

Vytvorenie adresárov pre Build Agentov a cache.

```bash
mkdir -p /opt/Agents /opt/Agents/cache /opt/Agents/cache/cypress /opt/Agents/cache/npm /opt/Agents/cache/nuget /opt/Agents/cache/nx
```

## Pridanie DEVEXTREME_KEY do environment variables

```bash
echo "DEVEXTREME_KEY=[realny_kluc]" | sudo tee -a /etc/environment
```

## Inštalácia Portainer

Portainer je webová aplikácia pre správu Docker kontajnerov.

```bash
docker volume create portainer_data
docker run -d -p 8000:8000 -p 9000:9000 --name portainer --restart=always -v /var/run/docker.sock:/var/run/docker.sock -v portainer_data:/data portainer/portainer-ce
```

Po inštaláci sa dá pristupovať na adrese `http://[ip_adresa]:9000`.

## Stiahnutie [kros-sk.github.io](https://github.com/Kros-sk/kros-sk.github.io) repozitára

```bash
git clone -b master https://github.com/Kros-sk/kros-sk.github.io.git
```

Po naklonovaní na mašinu budeme môcť spustiť kontajnery pre Build Agentov. Všetko sa rieši cez docker-compose.

## Build image

Vybudovanie image podla [azure-agent-linux.dockerfile](azure-agent-linux.dockerfile).

```bash
docker build -t azure-agent-linux:latest -f azure-agent-linux.dockerfile . 
```

## Spustenie kontajnerov

Na spustenie kontajnerov vieme použiť 2 prístupy:

1. Docker compose
2. Orchestrácia kontajnerov

### Docker compose

Pre každý pool je samostatný docker-compose súbor. V ňom sú definovaní build agenti pre daný pool.
Každý z nich treba nasadiť do tzv. stacku. Docker compose súbory pre jednotlivé pooly:

- Build BE: [docker-compose-build-be.yml](docker-compose-build-be.yml)
- Build FE: [docker-compose-build-fe.yml](docker-compose-build-fe.yml)
- Deploy BE: [docker-compose-deploy-be.yml](docker-compose-deploy-be.yml)
- Deploy FE: [docker-compose-deploy-fe.yml](docker-compose-deploy-fe.yml)
- Default: [docker-compose-default.yml](docker-compose-default.yml)

```bash
docker stack deploy -c docker-compose-build-be.yml build_be_stack -d
docker stack deploy -c docker-compose-build-fe.yml build_fe_stack -d
docker stack deploy -c docker-compose-deploy-be.yml deploy_be_stack -d
docker stack deploy -c docker-compose-deploy-fe.yml deploy_fe_stack -d
docker stack deploy -c docker-compose-default.yml default_stack -d
```

Vypnutie kontajnerov:

```bash
docker stack rm build_be_stack
docker stack rm build_fe_stack
docker stack rm deploy_be_stack
docker stack rm deploy_fe_stack
docker stack rm default_stack
```

### Testing TEMP

```bash
docker stack deploy -c docker-compose.yml build_agents_stack -d
docker stack ls # zobraziť stacky
```

Vypnutie kontajnerov:

```bash
docker stack rm build_agents_stack
```

### Orchestrácia kontajnerov TODO (kubernetes/docker swarm)

Máme nad správaním kontajnerov väčšiu kontrolu a viac možností. TODO pokračovať.

## Inštalácia Kubernetes

Postupovať podľa oficiálnej dokumentácie: [Kubernetes](https://kubernetes.io/docs/tasks/tools/install-kubectl-linux/)

## Vytvorenie clusteru

Nainštalovať [minikube](https://minikube.sigs.k8s.io/docs/start/?arch=%2Flinux%2Fx86-64%2Fstable%2Fbinary+download)

Vytvoriť cluster:

```bash
minikube start
```

## Nainštalovanie KEDA

```bash
kubectl apply --server-side -f https://github.com/kedacore/keda/releases/download/v2.17.0/keda-2.17.0-core.yaml
```

## Odinštalovanie KEDA

```bash
kubectl delete --purge keda
```


