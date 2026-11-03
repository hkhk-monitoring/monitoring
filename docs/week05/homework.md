---
tags:
  - Kodutöö
  - Monitooring
  - Ansible
---

# Kodutöö: oma mõõdik node_exporterisse

node_exporter avaldab masina näite, kuid mõnikord on vaja mõõta midagi, mida ükski exporter ei paku. Kodutöös lisad mõlemasse masinasse oma mõõdiku: kausta `/var/log` maht baitides. Mõõdiku kirjutab skript faili ja node_exporter avaldab selle koos teiste mõõdikutega. Kodutöö on boonus.

Eeldus on praktikumi osad 4 ja 5: node_exporter on paigaldatud playbook'iga ja Prometheus küsib mõlemat masinat. Tähtaja näed Classroom 50-s.

## Osa 1 · Mõõdik failist

node_exporteril on **textfile collector** ([textfile collector](https://github.com/prometheus/node_exporter#textfile-collector)). See loeb kaustast kõik `.prom` laiendiga failid ja avaldab nende sisu aadressil `/metrics`. Kausta annad node_exporterile käivitamisel võtmega `--collector.textfile.directory`.

Faili sisu on sama vorming, mida nägid praktikumi osas 3:

```text
# HELP logide_maht_baitides Kausta /var/log maht baitides.
# TYPE logide_maht_baitides gauge
logide_maht_baitides 48213760
```

Kirjuta skript `konf/logimaht.sh`, mis:

- arvutab kausta `/var/log` mahu baitides (`du -sb`);
- kirjutab ülaltoodud kolm rida kõigepealt ajutisse faili samas kaustas;
- nimetab ajutise faili ümber nimeks `/var/lib/node_exporter/textfile/logid.prom` (`mv`).

Ümbernimetamine on vajalik, sest node_exporter võib faili lugeda just sel hetkel, kui skript seda kirjutab. `mv` samas failisüsteemis vahetab faili korraga välja, nii et node_exporter näeb kas vana või uut faili, mitte poolikut.

## Osa 2 · Playbook

Täienda `konf/node_exporter.yml` nii, et see:

- loob kausta `/var/lib/node_exporter/textfile`;
- lisab unit-faili real `ExecStart` võtme `--collector.textfile.directory=/var/lib/node_exporter/textfile` (handler taaskäivitab teenuse);
- kopeerib skripti `/usr/local/bin/logimaht.sh`;
- käivitab skripti iga 5 minuti järel (`ansible.builtin.cron`).

Käivita playbook kaks korda. Teisel korral peab olema `changed=0`.

## Osa 3 · Päring

Oota 5 minutit ja kirjuta Prometheuses päring, mis näitab mõlema masina logide mahtu megabaitides. Salvesta tulemus:

```bash
ssh proxmox1 "curl -s localhost:9090/api/v1/query --data-urlencode 'query=logide_maht_baitides'" > logid/kodutoo-paring.json
```

Vasta README jaotises **Kodutöö**:

1. Kirjuta oma päring megabaitide jaoks.
2. Kumb masin kirjutab rohkem logisid? Kuidas saaksid päringuga näha, kui kiiresti logide maht kasvab?
3. Miks kirjutab skript esmalt ajutisse faili?

## Töö esitamine

Skript, täiendatud playbook, päringu tulemus ja vastused on samas repositooriumis, kus praktikum 4.

```bash
git status
git add konf/logimaht.sh konf/node_exporter.yml logid/kodutoo-paring.json README.md
git commit -m "Kodutöö 5: oma mõõdik"
git push
```

Tulemuse näed Classroom 50-s.
