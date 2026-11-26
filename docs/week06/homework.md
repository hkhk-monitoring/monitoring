---
tags:
  - Kodutöö
  - Monitooring
  - Prometheus
---

# Kodutöö: ketas saab varsti täis

Praktikumi reegel `KettaruumOtsas` teatab, kui vaba ruumi on alla 20%. Kui ketas täitub aeglaselt, võib see piir püsida kuid ja teade tuleb õigel ajal. Kui logifail kasvab kiiresti, võib ketas aga 20% pealt mõne tunniga täis saada, enne kui keegi teadet näeb. Kodutöös kirjutad reegli, mis vaatab täitumise kiirust ja hoiatab, kui ketas saab praeguse kiirusega lähima nelja tunni jooksul täis. Kodutöö on boonus.

Eeldus on praktikumi osad 4 ja 5: reeglid on failis `konf/config/reeglid.yml` ja Alertmanager saadab teated Discordi. Tähtaja näed Classroom 50-s.

## Osa 1 · Ennustav päring

Funktsioon `predict_linear(v[aken], t)` sobitab aknas olevatele väärtustele sirge ja annab väärtuse, mis sellel sirgel on `t` sekundi pärast ([predict_linear](https://prometheus.io/docs/prometheus/latest/querying/functions/#predict_linear)). Kui ennustatud vaba ruum on alla nulli, saab ketas selle aja jooksul täis.

Kirjuta Prometheuse veebiliideses päring, mis näitab iga masina juurfailisüsteemi vaba ruumi nelja tunni pärast, kui ruum väheneb samas tempos nagu viimase 30 minuti jooksul. Pane päring vahekaardile **Graph** ja võrdle seda praeguse vaba ruumiga.

??? tip "Vihje"
    Aken on `[30m]`, aeg sekundites on `4 * 3600`. Mõõdik on sama, mida kasutab reegel `KettaruumOtsas`.

## Osa 2 · Reegel

Lisa faili `konf/config/reeglid.yml` reegel `KettasTaitub`:

- tingimus: osa 1 päringu tulemus on alla nulli;
- `for: 10m`, et lühike suur kirjutamine ei tekitaks teadet;
- `severity: hoiatus` ja `summary`, mis ütleb masina.

Kontrolli faili `promtool check rules` käsuga nagu praktikumi osas 4.3, kopeeri see `proxmox1`-sse ja taaskäivita Prometheus.

Proovi reeglit `proxmox2`-s. Kirjuta 10 minuti jooksul iga minut juurde 300 MB ja jälgi Prometheuse **Alerts** lehel, kas reegel läheb olekusse Pending. Kustuta fail pärast katset:

```bash
ssh proxmox2 'for i in $(seq 1 10); do sudo fallocate -l ${i}00M /var/tmp/katse.bin; sleep 60; done'
ssh proxmox2 "sudo rm /var/tmp/katse.bin"
```

Kui kettal on vaba ruumi palju, ei pruugi 3 GB nelja tunniga ketast täita. Siis muuda katseks aega `4 * 3600` suuremaks ja vaata, millise aja juures tingimus kehtima hakkab.

## Osa 3 · Vastused

Vasta failis `BOONUS.md`:

1. Sinu `KettasTaitub` reegli `expr`.
2. Mis juhtub reegliga pärast seda, kui katsefail on kustutatud? Mitu minutit läheb, kuni tingimus enam ei kehti, ja miks just nii palju?
3. Millal annab `KettaruumOtsas` teate ja `KettasTaitub` mitte? Too näide.
