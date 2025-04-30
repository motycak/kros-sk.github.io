# Rozbehanie novej Linux mašiny

## Pripojenie cez ssh

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

## Stiahnutie [kros-sk.github.io](https://github.com/Kros-sk/kros-sk.github.io) repozitára

```bash
git clone -b master https://github.com/Kros-sk/kros-sk.github.io.git
```

## Inštalácia Docker

Postupovať podľa oficiálnej dokumentácie: [Docker](https://docs.docker.com/engine/install/ubuntu/)

Nastaviť PAT do Azure DevOps. Bude sa ku nemu pristupovať v [docker-compose.yml](docker-compose.yml). Token musí mať právo `Read & manage` pre scope `Agent Pools`.

```bash
docker swarm init
echo "VYGENEROVANY_TOKEN" | docker secret create azure_pat_token -
docker secret ls # zobraziť secrety
```

## Vybuildovanie a spustenie kontajnerov

```bash
docker-compose up -d
```

## Vypnutie kontajnerov

```bash
docker-compose down
```
