---
tags:
  - Info
  - Monitooring
---

# Töökeskkond ja eelkontroll

Kasutad automatiseerimise kursusest tuttavaid laborimasinaid `proxmox1`, `proxmox2` ja `proxmox3`. Enne esimest praktikumi kontrolli VPN-i, SSH-ühendusi ja Ansible'i ligipääsu. Kui keskkond puudub, taasta see automatiseerimise kursuse [töökeskkonna juhendi](https://hkhk-automation.github.io/devops/kodulabor/) järgi.

## 1. Masinad ja nende rollid

`proxmox1`, `proxmox2` ja `proxmox3` on kooli Proxmoxis töötavad virtuaalmasinad (AlmaLinux 9). Nimed on SSH aliased sinu `~/.ssh/config`-is.

| Masin | Roll |
|---|---|
| Sinu arvuti | VS Code, terminal, Ansible, Git, brauser |
| `proxmox1` | keskserver: logiserver (rsyslog), seiresüsteemid (Docker Compose) |
| `proxmox2`, `proxmox3` | jälgitavad masinad: agendid ja exporter'id |

## 2. Ühenda kooli võrku

Koolis on laborimasinad otse kättesaadavad. Kodust töötades ühenda enne VPN. VPN-i profiili annab õpetaja.

## 3. Kontrolli SSH-ühendusi

Käivita oma arvutis:

```bash
for h in proxmox1 proxmox2 proxmox3; do
  ssh $h hostname
done
```

??? success "Oodatav tulemus"
    Iga käsk väljastab masina hostinime. Parooli ei küsita, sest ühendus kasutab SSH-võtit.

??? warning "Kui mõni ühendus ei õnnestu"
    Kontrolli, et VPN on ühendatud. Seejärel tee läbi automatiseerimise kursuse [1. nädala praktikum](https://hkhk-automation.github.io/devops/week01/lab/) (SSH-võti ja `~/.ssh/config`). Ära jätka enne, kui kõik kolm ühendust töötavad.

## 4. Kontrolli Ansible'i ligipääsu

```bash
ansible all -i proxmox1,proxmox2,proxmox3, -m ping
```

Koma loendi lõpus näitab Ansible'ile, et `-i` järel on masinate loend, mitte inventarifaili nimi.

??? success "Oodatav tulemus"
    Väljundis on kolm rida olekuga `SUCCESS` ja `"ping": "pong"`.

## 5. Millal oled valmis?

Oled valmis, kui pääsed SSH-ga kõigisse kolme laborimasinasse ja Ansible'i kontroll õnnestub kõigi kolme puhul. Monitooringuteenused paigaldad vastavates praktikumides.

## 6. Teenuste peatamine ja taaskäivitamine

`proxmox1` mälu on piiratud. Iga praktikumi alguses on kirjas, millised teenused peavad töötama ja millised peatada. Enne uue seirekomplekti käivitamist kontrolli saadaval mälu:

```bash
ssh proxmox1 free -h
```

Kui veerus `available` on alla 3 GB, peata mittevajalikud teenused või anna õpetajale teada.

Teenuse ajutiseks peatamiseks kasuta selle Compose'i projekti kaustas käsku `docker compose stop`. See peatab konteinerid, kuid ei eemalda neid ega nende andmeköiteid. Käsk `docker compose start` käivitab olemasolevad konteinerid uuesti. Pärast käivitamist kontrolli teenuse valmisolekut vastava praktikumi järgi ([docker compose stop](https://docs.docker.com/reference/cli/docker/compose/stop/)).

!!! warning "`docker compose down -v` kustutab andmed"
    Võti `-v` eemaldab ka andmeköited, näiteks Zabbixi andmebaasi koos kõigi hostidega. Kasuta seda ainult siis, kui tahad teenuse andmed teadlikult kustutada.

## Teenused ja ühendused

Tabel on kursuse teatmik. Kõiki teenusi ei pea korraga käivitama ega kõiki porte enne kursuse algust avama. Veebiliidese avad brauseris aadressil `http://<proxmox1-IP>:<port>`.

??? note "Tabel 1. Teenused, pordid ja kes ühendub"
    | Teenus | Sihtmasin | Sihtport | Kes ühendub | Alates |
    |---|---|---|---|---|
    | rsyslog, logide vastuvõtt | `proxmox1` | 514/tcp | `proxmox2` ja `proxmox3` rsyslog | N1 |
    | Zabbixi veebiliides | `proxmox1` | 8080/tcp | sinu brauser | N2 |
    | Zabbixi passiivsed kontrollid | `proxmox2`, `proxmox3` | 10050/tcp | Zabbixi server | N4 |
    | Zabbixi aktiivsed kontrollid | `proxmox1` | 10051/tcp | `proxmox3` agent | N4 |
    | Prometheus | `proxmox1` | 9090/tcp | sinu brauser | N5 |
    | node_exporter | `proxmox2`, `proxmox3` | 9100/tcp | Prometheus | N5 |
    | Grafana | `proxmox1` | 3000/tcp | sinu brauser | N6 |
    | Alertmanager | `proxmox1` | 9093/tcp | sinu brauser, Prometheus | N6 |
    | InfluxDB | `proxmox1` | 8086/tcp | Telegraf | N7 |
    | Loki | `proxmox1` | 3100/tcp | Grafana Alloy | N8 |
    | OpenSearch Dashboards | `proxmox1` | 5601/tcp | sinu brauser | N9 |
    | Jaeger | `proxmox1` | 16686/tcp | sinu brauser | N10 |
    | Uptime Kuma | `proxmox1` | 3001/tcp | sinu brauser | N11 |
