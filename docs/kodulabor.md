---
tags:
  - Info
  - Monitooring
---

# Töökeskkond

Kasutad samu kolme Proxmoxi sõlme, mis automatiseerimise kursusel. Uut masinat ei ole vaja.

| Masin | Roll |
|---|---|
| Sinu arvuti | VS Code, terminal, Ansible, Git, brauser |
| `proxmox1` | keskserver: logiserver (rsyslog), seiresüsteemid (Docker Compose) |
| `proxmox2`, `proxmox3` | jälgitavad masinad |

*Tabel 1. Kes mida teeb*

## Kontrolli SSH-ühendust ja Ansible'i

Kodust töötades ühenda enne VPN. Seejärel käivita oma arvutis:

```bash
for h in proxmox1 proxmox2 proxmox3; do
  ssh $h hostname
done
```

Iga käsk väljastab masina hostinime ja parooli ei küsita, sest ühendus kasutab SSH-võtit. Kui mõni ühendus ei õnnestu, tee läbi automatiseerimise kursuse [1. nädala praktikum](https://hkhk-automation.github.io/devops/week01/lab/) (SSH-võti ja `~/.ssh/config`).

```bash
ansible all -i proxmox1,proxmox2,proxmox3, -m ping
```

Väljundis on kolm `pong`-i. Koma loendi lõpus näitab Ansible'ile, et `-i` järel on masinate loend, mitte inventarifaili nimi.

## Pordid

Monitooringusüsteemid töötavad sõlmes `proxmox1`, agendid ja exporter'id jälgitavates masinates. Veebiliidese avad brauseris aadressil `http://<proxmox1-IP>:<port>`. Kasuta IP-aadressi, mille said automatiseerimise kursusel.

| Teenus | Port | Masin | Brauseris | Alates |
|---|---|---|---|---|
| rsyslog (logide vastuvõtt) | 514/tcp | `proxmox1` | ei | N1 |
| Zabbix veebiliides | 8080/tcp | `proxmox1` | jah | N2 |
| Zabbix agent | 10050/tcp | `proxmox2`, `proxmox3` | ei | N4 |
| Prometheus | 9090/tcp | `proxmox1` | jah | N5 |
| node_exporter | 9100/tcp | `proxmox2`, `proxmox3` | ei | N5 |
| Grafana | 3000/tcp | `proxmox1` | jah | N6 |
| Alertmanager | 9093/tcp | `proxmox1` | jah | N6 |
| InfluxDB | 8086/tcp | `proxmox1` | ei | N7 |
| Loki | 3100/tcp | `proxmox1` | ei | N8 |
| OpenSearch Dashboards | 5601/tcp | `proxmox1` | jah | N9 |
| Jaeger | 16686/tcp | `proxmox1` | jah | N10 |
| Uptime Kuma | 3001/tcp | `proxmox1` | jah | N11 |

*Tabel 2. Teenused ja pordid*

## Mälu

Iga seiresüsteem vajab `proxmox1`-l 0,5–2 GB mälu. Iga praktikumi alguses on kirjas, millised süsteemid peavad töötama. Ülejäänud peata nende kaustas käsuga `docker compose stop`, siis jäävad andmed alles. Kontrolli `ssh proxmox1 free -h`, veerg `available`. Kui see on alla 3 GB, anna õpetajale teada.
