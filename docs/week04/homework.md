---
tags:
  - Kodutöö
  - Monitooring
  - Ansible
---

# Kodutöö: kas varundus töötas?

Praktikumis kasutasid agendi valmis võtmeid. Agendile saab lisada ka oma võtme: käsu, mille väljundi agent annab serverile. Kodutöös teed `proxmox3`-s võtme, mis näitab, mitu sekundit tagasi viimane varundus tehti, lisad selle playbook'iga ja seadistad Zabbixi tegema probleemi, kui varundus jääb vahele. Kodutöö on boonus.

Eeldus on praktikumi osad 2 ja 3: `proxmox3`-s töötab aktiivne agent. Tähtaja näed Classroom 50-s.

## Osa 1 · Varunduse asemel üks fail

Varundusskript kirjutab tavaliselt lõpus faili, et töö sai tehtud. Siin teeb seda iga 5 minuti järel `cron`, mis uuendab faili `/var/tmp/varundus.ok` aega. Pärast iga õnnestunud varundust on faili muutmise aeg uus.

Agendi oma võti on rida `UserParameter=<võti>,<käsk>` ([User parameters](https://www.zabbix.com/documentation/7.0/en/manual/config/items/userparameters)). Loo oma repositooriumis fail `konf/varundus.conf`:

```text
UserParameter=varundus.vanus,echo $(( $(date +%s) - $(stat -c %Y /var/tmp/varundus.ok 2>/dev/null || echo 0) ))
```

Käsk lahutab praegusest ajast faili muutmise aja. Tulemus on varunduse vanus sekundites. Kui faili pole, on vanus väga suur.

## Osa 2 · Playbook

Agendi konfiguratsioonifaili lõpus on rida `Include=/etc/zabbix/zabbix_agent2.d/*.conf`. Kõik selle kausta `.conf` failid loetakse agendi seadete hulka. Kontrolli seda:

```bash
ssh proxmox3 "sudo grep '^Include' /etc/zabbix/zabbix_agent2.conf"
```

Lisa faili `konf/agent.yml` kaks ülesannet:

- [`ansible.builtin.copy`](https://docs.ansible.com/ansible/latest/collections/ansible/builtin/copy_module.html) kopeerib `varundus.conf` kausta `/etc/zabbix/zabbix_agent2.d/` (`mode: "0644"`) ja teavitab handlerit `Taaskäivita agent`;
- [`ansible.builtin.cron`](https://docs.ansible.com/ansible/latest/collections/ansible/builtin/cron_module.html) loob kasutajale `root` kirje nimega `varundus`, mis käivitab iga 5 minuti järel `touch /var/tmp/varundus.ok`.

Uuri enne `cron` moodulit: `ansible-doc ansible.builtin.cron`. Leia, mida teeb parameeter `disabled` ja miks on kirjel vaja parameetrit `name`.

Käivita playbook mõlemas masinas ja kontrolli `proxmox3`-s, et agent tunneb uut võtit:

```bash
ansible-playbook -i proxmox2,proxmox3, konf/agent.yml
ssh proxmox3 "sudo touch /var/tmp/varundus.ok; sudo zabbix_agent2 -t varundus.vanus"
```

Väljundis on võti ja väike arv sekundeid. Kui väljundis on `ZBX_NOTSUPPORTED`, vaata, kas fail jõudis kausta `/etc/zabbix/zabbix_agent2.d/` ja kas agent taaskäivitus.

## Osa 3 · Item ja trigger

`proxmox3` agent on aktiivne, seega peab ka uus item olema aktiivne. **Data collection → Hosts → proxmox3 → Items → Create item**:

- **Name:** `Varunduse vanus`
- **Type:** **Zabbix agent (active)**
- **Key:** `varundus.vanus`
- **Type of information:** **Numeric (unsigned)**
- **Units:** `s`
- **Update interval:** `1m`

Seejärel trigger nimega `Varundus on vanem kui 10 minutit`, raskusaste **High**. Avaldise kirjuta ise loengu [§5](lecture.md#5-trigger-avaldis-ja-raskusaste) järgi.

## Osa 4 · Jäta varundus vahele

Lülita cron'i kirje välja. Tee seda playbook'iga: lisa `cron` ülesandele `disabled: true` ja käivita playbook ainult `proxmox3`-s (`-i proxmox3,`). Oota 10–15 minutit ja vaata **Monitoring → Problems**. Kui probleem on olemas, kustuta `disabled: true`, käivita playbook uuesti ja oota, kuni probleem laheneb.

Salvesta tõend oma arvutis repositooriumi kaustas:

```bash
ssh proxmox3 "sudo zabbix_agent2 -t varundus.vanus; sudo crontab -l | grep -A1 varundus" > logid/kodutoo-varundus.txt
```

## Osa 5 · Vasta küsimustele

Vastused lähevad README osasse **Kodutöö** iga `_kodutöö_` asemele:

1. Kirjuta oma trigger'i avaldis.
2. Mitu minutit pärast cron'i väljalülitamist tekkis probleem ja miks just siis?
3. Mis juhtub, kui keegi kustutab faili `/var/tmp/varundus.ok`? Kas see on hea või halb?
4. Miks sobib see kontroll paremini aktiivsele agendile? Mõtle, kus varundusserverid tavaliselt asuvad.

## Töö esitamine

Repositooriumis on `konf/varundus.conf`, täiendatud `konf/agent.yml`, `logid/kodutoo-varundus.txt` ja README vastused. Oma arvutis repositooriumi kaustas:

```bash
git status
git add konf logid README.md
git commit -m "Kodutöö 4: varunduse vanus"
git push
```

Tulemuse näed Classroom 50-s. Praktikumi kontrollid peavad pärast kodutööd endiselt õnnestuma, sest playbook'i lisandub ainult kaks ülesannet.
