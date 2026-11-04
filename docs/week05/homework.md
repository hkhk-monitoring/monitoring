---
tags:
  - Kodutöö
  - Monitooring
  - Ansible
---

# Kodutöö: oma mõõdik node_exporterisse

node_exporter avaldab masina näite, kuid mõnikord on vaja mõõta midagi, mida kasutatav exporter vaikimisi ei avalda. Kodutöös lisad mõlemasse masinasse oma mõõdiku: kausta `/var/log` kettaruumikasutuse baitides. Mõõdiku kirjutab skript faili ja node_exporter avaldab selle koos teiste mõõdikutega. Kodutöö on boonus.

Eeldus on praktikumi osad 4 ja 5: node_exporter on paigaldatud playbook'iga ja Prometheus küsib mõlemat masinat. Tähtaja näed Classroom 50-s.

## Osa 1 · Mõõdik failist

node_exporteril on **textfile collector** ([textfile collector](https://github.com/prometheus/node_exporter#textfile-collector)). See loeb kaustast kõik `.prom` laiendiga failid ja avaldab nende sisu aadressil `/metrics`. Kausta annad node_exporterile käivitamisel võtmega `--collector.textfile.directory`.

Faili sisu on sama vorming, mida nägid praktikumi osas 3:

```text
# HELP logide_maht_baitides Kausta /var/log kettaruumikasutus baitides.
# TYPE logide_maht_baitides gauge
logide_maht_baitides 48213760
```

Kirjuta skript `konf/logimaht.sh`, mis:

- arvutab kausta `/var/log` kettaruumikasutuse baitides käsuga `du -s -B1 /var/log`;
- kirjutab ülaltoodud kolm rida kõigepealt ajutisse faili samas kaustas, näiteks `logid.prom.$$`. Ajutise faili nimi ei tohi lõppeda `.prom`-iga, sest siis loeks node_exporter ka poolikut faili;
- annab valmis failile õigused `0644`, et node_exporteri kasutaja saaks seda lugeda;
- nimetab ajutise faili ümber nimeks `/var/lib/node_exporter/textfile/logid.prom` (`mv`).

Kui `du` ebaõnnestub, peab skript lõppema veaga ega tohi viimast korrektset `logid.prom` faili üle kirjutada.

Ümbernimetamine on vajalik, sest node_exporter võib faili lugeda just sel hetkel, kui skript seda kirjutab. `mv` samas failisüsteemis vahetab faili korraga välja, nii et node_exporter näeb kas vana või uut faili, mitte poolikut. Faili `logid.prom` repositooriumisse ei lisata, see tekib masinas.

## Osa 2 · Playbook

Skripti käivitab cron kasutajana `root`, et kõik logikaustad oleksid loetavad. Kontrolli enne, et cron töötab: `ssh proxmox2 "systemctl is-active crond"`. Kui vastus ei ole `active`, lisa playbook'i pakett `cronie` ja teenus `crond`.

Täienda `konf/node_exporter.yml` nii, et see:

- loob kausta `/var/lib/node_exporter/textfile` (omanik `root`, õigused `0755`);
- lisab unit-faili sisus real `ExecStart` võtme `--collector.textfile.directory=/var/lib/node_exporter/textfile`. Varasemad argumendid jäävad alles. Unit-faili muutus teavitab handler'it, mis laadib systemd seaded uuesti (`daemon_reload: true`) ja taaskäivitab node_exporteri;
- kopeerib skripti `/usr/local/bin/logimaht.sh` (omanik `root`, õigused `0755`);
- käivitab skripti iga 5 minuti järel kasutajana `root` (`ansible.builtin.cron`).

Käivita playbook kaks korda. Kui esimene käivitus õnnestus ja masinaid pole vahepeal muudetud, on teisel korral `changed=0`.

## Osa 3 · Kontrolli ja päri

Kontrolli andmeteed kolmes kohas. Pane kirja faili muutmisaeg ja kontrolli 5 minuti pärast uuesti, et cron uuendas faili:

```bash
for h in proxmox2 proxmox3; do
  echo "== $h"
  ssh $h "stat -c %y /var/lib/node_exporter/textfile/logid.prom; cat /var/lib/node_exporter/textfile/logid.prom"
  ssh $h "curl -fsS localhost:9100/metrics | grep '^logide_maht_baitides'"
done
```

??? success "Oodatav tulemus"
    Mõlema masina kohta muutmisaeg, faili kolm rida ja `/metrics` väljundist sama rida. Teisel kontrollil on muutmisaeg uuem.

Kirjuta Prometheuses päring, mis näitab mõlema masina `/var/log` kettaruumikasutust mebibaitides (MiB, jaga `1024 * 1024`-ga). Salvesta sama päringu tulemus, `<sinu päring>` asemele kirjuta oma päring:

```bash
ssh proxmox1 "curl -fsS localhost:9090/api/v1/query --data-urlencode 'query=<sinu päring>'" > logid/kodutoo-paring.json
cat logid/kodutoo-paring.json
```

??? success "Oodatav tulemus"
    `"status":"success"` ja kaks tulemust, kummalgi eri `instance` ja arv mebibaitides.

## Töö esitamine

Repositooriumis on `konf/logimaht.sh`, täiendatud `konf/node_exporter.yml` ja `logid/kodutoo-paring.json`. Failis `BOONUS.md` kirjuta iga `_vastus_` asemele lühike vastus:

1. sinu päring mebibaitide jaoks;
2. kummas masinas on `/var/log` kettaruumikasutus suurem ja kuidas uuriksid, kui kiiresti see muutub? See on gauge, mitte counter: vaata funktsioone [`delta()` ja `deriv()`](https://prometheus.io/docs/prometheus/latest/querying/functions/). Mida muudab tulemuses logrotate?
3. skript lakkab töötamast, aga viimane `logid.prom` jääb alles. Kas Prometheuse värske mõõtmisaeg tõendab, et kausta mahtu mõõdeti hiljuti?

Oma arvutis repositooriumi kaustas:

```bash
git status
git add konf/logimaht.sh konf/node_exporter.yml logid/kodutoo-paring.json BOONUS.md
git commit -m "Kodutöö 5: oma mõõdik"
git push
```

Tulemuse näed Classroom 50-s.
