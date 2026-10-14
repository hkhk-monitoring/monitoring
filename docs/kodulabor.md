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

## Kontrolli, et kõik töötab

Sinu arvutis:

```bash
for h in proxmox1 proxmox2 proxmox3; do
  ssh $h hostname
done
```

Kolm nime, parooli ei küsita. Kui ei tööta, tee läbi automatiseerimise kursuse [nädal 1 labor](https://hkhk-automation.github.io/devops/week01/lab/) (SSH-võti ja `~/.ssh/config`).

```bash
ansible all -i proxmox1,proxmox2,proxmox3, -m ping
```

Kolm `pong`-i. Lõpu koma `-i` järel on vajalik.

## Pordid

Alates N2-st avad brauseris teenuseid sõlmes `proxmox1`. Kasuta sõlme IP-d, mille said automatiseerimise kursusel.

| Teenus | Port | Alates |
|---|---|---|
| rsyslog (logide vastuvõtt) | 514/tcp | N1 |
| Zabbix veebiliides | 8080 | N2 |
| Zabbix agent | 10050 | N4 |
| Prometheus | 9090 | N5 |
| node_exporter | 9100 | N5 |
| Grafana | 3000 | N6 |
| Alertmanager | 9093 | N6 |
| InfluxDB | 8086 | N7 |
| Loki | 3100 | N8 |
| OpenSearch Dashboards | 5601 | N9 |
| Jaeger | 16686 | N10 |
| Uptime Kuma | 3001 | N11 |

*Tabel 2. Teenused ja pordid*

## Mälu

Iga seiresüsteem vajab `proxmox1`-l 0,5-2 GB mälu. Korraga jookseb ainult üks: enne uue käivitamist peata eelmine (`docker compose down`). Kontrolli `ssh proxmox1 free -h`, veerg `available`. Kui see on alla 3 GB, anna õpetajale teada.
