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
| `proxmox1` | seiresüsteem: Prometheus, Grafana, hiljem Loki (Docker Compose) |
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

Alates N8-st avad brauseris teenuseid sõlmes `proxmox1`. Kasuta sõlme IP-d, mille said automatiseerimise kursusel.

| Teenus | Port | Alates |
|---|---|---|
| Prometheus | 9090 | N8 |
| node_exporter | 9100 | N8 |
| Grafana | 3000 | N10 |
| Alertmanager | 9093 | N13 |
| Loki | 3100 | N15 |

*Tabel 2. Teenused ja pordid*

## Mälu

Seiresüsteem vajab `proxmox1`-l kursuse lõpuks umbes 1,5 GB mälu. Kontrolli `ssh proxmox1 free -h`, veerg `available`. Kui see on alla 2 GB, anna õpetajale teada.
