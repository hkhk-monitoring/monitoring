---
tags:
  - Kodutöö
  - Monitooring
  - Ansible
---

# Kodutöö: kas varundus töötas?

Praktikumis kasutasid agendi valmis võtmeid. Agendile saab lisada ka oma võtme: käsu, mille väljundi agent annab serverile. Kodutöös modelleerid varunduse õnnestumise märguannet failiga. Lisad agendile võtme, mis näitab, mitu sekundit on möödunud selle faili viimasest muutmisest, ja seadistad trigger'i, mille tingimuse täitumisel tekib probleem, kui märguanne jääb liiga kauaks uuendamata. Kodutöö on boonus.

Eeldus on praktikumi osad 2 ja 3: `proxmox3`-s töötab aktiivne agent. Tähtaja näed Classroom 50-s.

## Osa 1 · Varunduse asemel märgistusfail

Selles näites tähistab fail `/var/tmp/varundus.ok` edukalt lõppenud varundust. Töökohas uuendaks seda faili varundusskript alles pärast edukat varundust. Siin asendab seda iga 5 minuti järel käivitatav `touch`.

Agendi oma võti on rida `UserParameter=<võti>,<käsk>` ([User parameters](https://www.zabbix.com/documentation/7.0/en/manual/config/items/userparameters)). Loo oma repositooriumis fail `konf/varundus.conf`:

```text
UserParameter=varundus.vanus,echo $(( $(date +%s) - $(stat -c %Y /var/tmp/varundus.ok 2>/dev/null || echo 0) ))
```

Käsk lahutab praegusest ajast faili muutmise aja. Tulemus on märguande vanus sekundites. Kui faili aega ei saa lugeda, kasutab käsk aega 0 ja vanus on väga suur. Nii tõlgendatakse ka puuduvat faili või ligipääsuviga vana märguandena, neid ei eristata.

## Osa 2 · Playbook

Agendi konfiguratsioonifaili lõpus on rida `Include=/etc/zabbix/zabbix_agent2.d/*.conf`. Kõik selle kausta `.conf` failid loetakse agendi seadete hulka. Ajastatud töö vajab masinas töötavat cron'i teenust. Kontrolli mõlemat:

```bash
ssh proxmox3 "sudo grep '^Include' /etc/zabbix/zabbix_agent2.conf; systemctl is-active crond"
```

??? warning "Kui `crond` ei ole `active`"
    AlmaLinuxis on cron paketis `cronie`. Lisa playbook'i ka see: pakett `cronie` (`ansible.builtin.dnf`) ja teenus `crond` olekus `started`, `enabled: true` (`ansible.builtin.service`).

Lisa uus konfiguratsioon ja ajastatud töö mõlemasse masinasse, item'i ja trigger'i lood Zabbixis ainult `proxmox3` jaoks. Lisa faili `konf/agent.yml` kaks ülesannet:

- [`ansible.builtin.copy`](https://docs.ansible.com/ansible/latest/collections/ansible/builtin/copy_module.html) kopeerib `varundus.conf` kausta `/etc/zabbix/zabbix_agent2.d/` (`mode: "0644"`) ja teavitab handler'it `Taaskäivita agent`, sest töötav agent loeb uue võtme alles pärast taaskäivitust;
- [`ansible.builtin.cron`](https://docs.ansible.com/ansible/latest/collections/ansible/builtin/cron_module.html) loob kasutajale `root` kirje nimega `varundus`, mis käivitab iga 5 minuti järel `touch /var/tmp/varundus.ok`.

Uuri enne `cron` moodulit: `ansible-doc ansible.builtin.cron`. Leia, mida teeb parameeter `disabled` ja milleks on kirjel vaja parameetrit `name`.

Käivita playbook ja kontrolli `proxmox3`-s, et agent tunneb uut võtit. Teine käsk käivitab testi agendi kasutajana `zabbix`, sest töötav agent loeb faili samuti selle kasutajana:

```bash
ansible-playbook -i proxmox2,proxmox3, konf/agent.yml
ssh proxmox3 "sudo touch /var/tmp/varundus.ok; sudo -u zabbix zabbix_agent2 -t varundus.vanus"
```

??? success "Oodatav tulemus"
    Väljundis on võti `varundus.vanus` ja nurksulgudes väike arv sekundeid.

??? warning "Kui väljundis on `ZBX_NOTSUPPORTED`"
    Loe veateadet. Kontrolli, kas fail jõudis kausta `/etc/zabbix/zabbix_agent2.d/`, kas rida `Include` on olemas ja kas käsk töötab kasutajana `zabbix`. Test `-t` käivitab eraldi protsessi: see kontrollib võtit kohapeal, mitte seda, kas töötav agent uue võtme laadis.

## Osa 3 · Item ja trigger

`proxmox3` agent on aktiivne, seega peab ka uus item olema aktiivne. **Data collection → Hosts → proxmox3 → Items → Create item**:

- **Name:** `Varunduse vanus`
- **Type:** **Zabbix agent (active)**
- **Key:** `varundus.vanus`
- **Type of information:** **Numeric (unsigned)**
- **Units:** `s`
- **Update interval:** `1m`

Kontrolli **Monitoring → Latest data**, et item'il on väärtus ja **Last check** uueneb. Alles see näitab, et väärtus jõuab agendist serverisse.

Seejärel loo trigger nimega `Varundus on vanem kui 10 minutit`, raskusaste **High**. Avaldise kirjuta ise loengu [§5](lecture.md#5-trigger-avaldis-ja-raskusaste) järgi.

## Osa 4 · Jäta varundus vahele

Enne katset kontrolli lähteolekut: märguande vanus on alla 300 sekundi, **Latest data** näitab värsket väärtust ja sinu trigger on olekus OK. Pane kirja faili viimane muutmisaeg:

```bash
ssh proxmox3 "stat -c %y /var/tmp/varundus.ok; date +%T"
```

Keela cron'i kirje ajutiselt playbook'iga: lisa `cron` ülesandele `disabled: true` ja käivita playbook ainult `proxmox3`-s (`-i proxmox3,`). Pane kirja kellaaeg (`date +%T`). Oota ja vaata **Monitoring → Problems**.

Kui probleem on olemas, taasta cron: muuda ülesandes `disabled: false` ja käivita playbook uuesti. Pane jälle kellaaeg kirja. Ära uuenda faili käsitsi `touch`-iga, sest siis ei tõenda katse, et cron taastus. Oota järgmist cron'i käivitust ja kontrolli, et faili aeg uuenes (`stat -c %y /var/tmp/varundus.ok`) ja probleem lahenes.

Salvesta agendi tõend oma arvutis repositooriumi kaustas:

```bash
ssh proxmox3 "sudo -u zabbix zabbix_agent2 -t varundus.vanus; sudo crontab -l | grep -A1 varundus" > logid/kodutoo-varundus.txt
```

Probleemi elutsükli tõend läheb README-sse (küsimus 5): **Monitoring → Problems**, filtris **Show: History**, rida *Varundus on vanem kui 10 minutit*. Kirjuta sealt host, algusaeg ja lahenemise aeg ning oma kellaajad cron'i keelamise ja taastamise kohta.

??? note "Lõppseis"
    Cron'i kirje on lubatud, märgistusfaili aeg uueneb iga 5 minuti järel, item kogub värskeid väärtusi ja trigger on olekus OK. Probleemi tekkimine ja lahenemine on README-s kirjas. Praktikumi agendiseadistus on alles: pärast kodutööd käivita playbook veel kord ja kontrolli, et mõlema masina väärtused uuenevad.

## Osa 5 · Vasta küsimustele

Vastused lähevad README osasse **Kodutöö** iga `_kodutöö_` asemele:

1. Kirjuta oma trigger'i avaldis.
2. Mitu minutit pärast cron'i keelamist tekkis probleem ja miks just siis? Arvesta faili viimast muutmisaega ja item'i intervalli.
3. Mis juhtub, kui keegi kustutab faili `/var/tmp/varundus.ok`? Kas see on hea või halb?
4. Varundusmasin saab avada ühenduse Zabbixi serveriga, kuid server ei pääse varundusmasinasse. Miks sobib selles võrgus aktiivne kontroll? Kas sama võtit saaks teises võrgus kasutada ka passiivse kontrollina?
5. Probleemi ajalugu: host, algusaeg, lahenemise aeg, cron'i keelamise ja taastamise kellaaeg.
6. Mida see kontroll tõendab ja mida peaksid veel kontrollima, et teada, kas varukoopiast saab andmed taastada?

## Töö esitamine

Repositooriumis on `konf/varundus.conf`, täiendatud `konf/agent.yml`, `logid/kodutoo-varundus.txt` ja README vastused. Oma arvutis repositooriumi kaustas:

```bash
git status
git add konf logid README.md
git commit -m "Kodutöö 4: varunduse vanus"
git push
```

Tulemuse näed Classroom 50-s.
