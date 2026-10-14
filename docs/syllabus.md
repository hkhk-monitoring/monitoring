---
tags:
  - Info
  - Monitooring
---

# Monitooring - kursuse ülevaade

**Maht:** 50 akadeemilist tundi kontaktõpet + 15 tundi iseseisvat tööd · 13 kohtumist
**Eeldused:** Linuxi käsurida, SSH, Docker Compose, Ansible alused
**Laborikeskkond:** samad Proxmoxi sõlmed, mis automatiseerimise kursusel: `proxmox1` kannab monitooringusüsteeme, `proxmox2` ja `proxmox3` on jälgitavad masinad. Ansible ja Git jooksevad sinu arvutis. Vt [Töökeskkond](kodulabor.md).

## Kursuse õpiväljundid

Kursuse lõpuks õppija:

1. selgitab, mis vahe on logimisel, monitooringul ja jälgimisel (tracing) ning kuidas need kolm koos annavad süsteemist tervikpildi (observability);
2. kogub, hoiab ja otsib logisid nii ühes masinas kui ka keskses süsteemis;
3. kogub masinate ja teenuste mõõdikuid nii agendi- kui ka pull-mudeliga ning teeb neist töölaua;
4. seadistab alarmid, mis jõuavad inimeseni ja millest on tegelikult kasu;
5. jälgib päringu teekonda läbi mitme teenuse ja seob jälje logi ning mõõdikuga;
6. leiab oma monitooringust rikke ja turvasündmuse ning kirjeldab seda intsidendiraportis;
7. valib olukorrale sobiva tööriista ja põhjendab valikut.

## Kursuse neli osa

| Osa | Mida küsib | Kohtumised | Tunnid |
|---|---|---|---:|
| **Logging** | Mis juhtus? | 1, 8, 9 | 12 |
| **Monitoring** | Kui palju ja kui kaua? | 2-7 | 18 |
| **Tracing** | Kus päring aega kulutas? | 10 | 4 |
| **Observability** | Miks see juhtus? (kõik koos) | 11, 12, 13 | 16 |

*Tabel 0.1. Kursuse osad*

## Kohtumised ühe pilguga

| Nr | h | Osa | Mõisteplokk | Tööriistad | Loeng / labor (min) |
|---:|---:|---|---|---|---|
| 1 | 4 | Logging | Masina logid ja keskne logiserver | journald, rsyslog, logrotate | 35 / 125 |
| 2 | 2 | Monitoring | Keskne jälgimissüsteem | Zabbix server | 20 / 60 |
| 3 | 2 | Monitoring | Mõõdik, aegrida, agent *(veebiõpe)* | top, free, df, stress-ng, Zabbix | 20 / 60 |
| 4 | 2 | Monitoring | Agent räägib serverile | Zabbix agent 2, Ansible | 20 / 60 |
| 5 | 4 | Monitoring | Server küsib ise | Prometheus, node_exporter, PromQL | 35 / 125 |
| 6 | 4 | Monitoring | Numbrid pildiks ja alarm | Grafana, Alertmanager | 35 / 125 |
| 7 | 4 | Monitoring | Aegrea andmebaas teisiti | Telegraf, InfluxDB 3 | 35 / 125 |
| 8 | 2 | Logging | Logid sildi järgi | Loki, Grafana Alloy | 20 / 60 |
| 9 | 6 | Logging | Logid täisotsinguga | Elasticsearch/OpenSearch, Kibana/Dashboards | 45 / 200 |
| 10 | 4 | Tracing | Päringu teekond | OpenTelemetry, Jaeger/Tempo | 35 / 125 |
| 11 | 4 | Observability | Kolm sammast koos ja kas üldse töötab | Blackbox exporter, Uptime Kuma | 35 / 125 |
| 12 | 4 | Observability | Turvamonitooring ja intsident | Wazuh | 35 / 125 |
| 13 | 8 | Observability | Lõputöö ja kaitsmine | oma valik | 15 / 240 + 90 kaitsmisi |
| | **50** | | | | |

*Tabel 0.2. Kohtumised (1 tund = 45 min). Iga kohtumine lõpeb 10-15-minutilise kokkuvõttega. *

Neljatunnise kohtumise labor on kahes osas: **A** on juhendatud, pärast pausi tuleb **B**, kus kasutad sama oskust muudetud olukorras. Kuuetunnisel kohtumisel on osad A, B ja C. Iga labori lõpus on lisaülesanded neile, kes saavad varem valmis, kergest päris raskeni.

Igal kohtumisel peatad enne uue süsteemi käivitamist eelmise (`docker compose down`), sest `proxmox1` mälu on piiratud.

---

## 1. Masina logid ja keskne logiserver

**4 h · Logging**

**Mida õpime**

- Miks monitoorida: kasutaja ei tohi olla see, kes rikke esimesena avastab.
- Logide liigid: süsteemi-, autentimis-, kerneli- ja rakenduse logid. Kus need asuvad (`/var/log`, journald).
- `journalctl` monitooringu vaatest: filtrid teenuse, raskusastme ja ajavahemiku järgi, `-f`.
- Syslogi raskusastmed (severity) ja allikad (facility).
- rsyslog: kuidas reeglid logi õigesse faili suunavad, oma reegel ja mall.
- logrotate: miks logid kasvavad üle pea, konfiguratsioon (`daily`, `rotate`, `compress`, `postrotate`), kontroll `-d`-ga.
- Keskne logiserver: rsyslog võtab vastu (TCP/UDP 514), kliendid saadavad.

**Eesmärgid** - õppija:

- leiab `journalctl` abil konkreetse teenuse vead etteantud ajavahemikus;
- seadistab rsyslogi reegli, mis suunab valitud logid eraldi faili;
- koostab teenusele logrotate konfiguratsiooni ja kontrollib seda;
- seadistab `proxmox1` keskseks logiserveriks ja suunab `proxmox2` ning `proxmox3` logid sinna;
- põhjendab, miks keskne logimine on vajalik juba kolme masina puhul.

**Tööriistad:** journald/journalctl, rsyslog, logrotate, logger

---

## 2. Keskne jälgimissüsteem

**2 h · Monitoring**

**Mida õpime**

- Mida monitooringusüsteem teeb: kogub, hoiab, näitab, teavitab.
- Zabbixi ülesehitus: server, andmebaas, veebiliides, agent, proxy.
- Põhimõisted: host, item, trigger, template.
- Zabbixi käivitamine Docker Compose'iga.

**Eesmärgid** - õppija:

- kirjeldab Zabbixi komponente ja nende omavahelist suhtlust;
- käivitab Zabbixi serveri koos andmebaasi ja veebiliidesega;
- lisab esimese hosti ja leiab selle viimased andmed veebiliidesest.

**Tööriistad:** Zabbix 7.0 LTS (server, veebiliides, PostgreSQL), Docker Compose

---

## 3. Mõõdik, aegrida, agent

**2 h · Monitoring · veebiõpe**

**Mida õpime**

- Mõõdik vs sündmus: number ajas vs kirje sellest, mis juhtus.
- Aegrida ja proovivõtu intervall.
- Mõõdikute liigid: gauge ja counter (histogrammi mainime).
- Mida masinas mõõta: USE-meetod (kasutus, küllastus, vead).
- Agendiga ja agendita kogumine.
- Masina numbrite lugemine käsitsi: tavaolek vs koormus.

**Eesmärgid** - õppija:

- eristab gauge'i ja counterit ning toob mõlemast näite;
- rakendab USE-meetodit protsessori, mälu ja ketta kohta;
- mõõdab käsitsi masina tavaoleku ja koormusega oleku ning võrdleb neid;
- loeb Zabbixi graafikult, millal koormus algas ja lõppes.

**Tööriistad:** top/htop, free, df, stress-ng, Zabbixi veebiliides

---

## 4. Agent räägib serverile

**2 h · Monitoring**

**Mida õpime**

- Zabbix agent 2 paigaldamine `proxmox2`-le ja `proxmox3`-le Ansiblega.
- Passiivne ja aktiivne agent.
- Valmis template'i kasutamine.
- Triggerid ja raskusastmed, probleemi tekkimine ja lahenemine.

**Eesmärgid** - õppija:

- paigaldab agendi Ansible playbookiga mitmesse masinasse korraga;
- seob hostid template'iga ja kontrollib, et andmed tulevad;
- loob oma triggeri (nt vaba kettaruum alla 20%) ja näitab, et see läheb probleemi olekusse ja tagasi.

**Tööriistad:** Zabbix agent 2, Ansible, Zabbixi template'id

---

## 5. Server küsib ise

**4 h · Monitoring**

**Mida õpime**

- Pull-mudel: exporter avaldab `/metrics`, Prometheus käib neid ise korjamas.
- Scrape intervall, target, label. Iga labelite kombinatsioon on eraldi aegrida.
- node_exporteri paigaldamine Ansiblega.
- PromQL: valik, labelifilter, `rate()`, `sum by`, `avg`, võrdlus.
- Zabbix vs Prometheus: millal kumb.

**Eesmärgid** - õppija:

- selgitab agendi- ja pull-mudeli erinevust;
- seadistab scrape target'id ja kontrollib Targets-lehelt, et kõik on UP;
- kirjutab PromQL päringud protsessori koormuse, mälu kasutuse ja vaba kettaruumi kohta;
- põhjendab, millises olukorras valiks Zabbixi ja millises Prometheuse.

**Tööriistad:** Prometheus, node_exporter, PromQL, Ansible

---

## 6. Numbrid pildiks ja alarm

**4 h · Monitoring**

**Mida õpime**

- Grafana andmeallikad, paneelid, ühikud, muutujad.
- Töölaua disain: mida peab inimene viie sekundiga nägema.
- Alarmireegel, lävend ja `for`-kestus, olekud Pending → Firing.
- Alertmanager: marsruutimine, grupeerimine, vaigistamine.
- Contact point ja hea alarmisõnum (milline masin, mis mõõdik, kui hull, mis ajast).

**Eesmärgid** - õppija:

- ehitab masinate tervise töölaua, kus hosti saab valida muutujaga;
- eemaldab töölaualt paneeli, mis otsust ei toeta, ja põhjendab;
- loob alarmireegli ja näitab oleku muutumist;
- seadistab teavituse, mis jõuab kohale, ja hindab, kas sõnumist saab öösel aru.

**Tööriistad:** Grafana, Alertmanager

---

## 7. Aegrea andmebaas teisiti

**4 h · Monitoring**

**Mida õpime**

- Push-mudel: agent saadab ise andmebaasi.
- Telegraf: sisend- ja väljundpluginad.
- InfluxDB 3: andmebaas, tabelid, säilitusaeg, päringud SQL-i ja InfluxQL-iga.
- InfluxDB Grafana andmeallikana.
- Prometheus vs InfluxDB: pull vs push, millal kumb.

**Eesmärgid** - õppija:

- seadistab Telegrafi saatma masina mõõdikuid InfluxDB-sse;
- teeb InfluxDB-s päringu ja kuvab tulemuse Grafanas;
- võrdleb push- ja pull-mudelit ning toob kummagi kohta sobiva olukorra.

**Tööriistad:** Telegraf, InfluxDB 3 Core, Grafana

---

## 8. Logid sildi järgi

**2 h · Logging**

**Mida õpime**

- Loki ülesehitus: indekseeritakse ainult sildid, mitte logi sisu.
- Grafana Alloy kui kollektor (Promtaili järglane).
- journaldi ja rsyslogi logid Lokisse.
- LogQL: sildifilter, tekstifilter, logiridade arv ajas.

**Eesmärgid** - õppija:

- seadistab Alloy saatma `proxmox2` ja `proxmox3` logid Lokisse;
- kirjutab LogQL päringu, mis leiab kindla teenuse vead;
- selgitab, miks Loki on odavam kui täisindeksiga logisüsteem.

**Tööriistad:** Loki, Grafana Alloy, Grafana

---

## 9. Logid täisotsinguga

**6 h · Logging**

**Mida õpime**

- Elasticsearch/OpenSearch: dokument, indeks, mapping, täisindeks.
- Logide saatmine klastrisse.
- Kibana/OpenSearch Dashboards: otsing, filtrid, visualiseeringud.
- Loki vs Elastic: kulu, kiirus, otsinguvõimalused.
- Logid ja mõõdikud ühel töölaual: logirida mõõdiku hüppe all.

**Eesmärgid** - õppija:

- käivitab ühesõlmelise klastri ja saadab sinna logid;
- otsib logidest päringukeelega ja ehitab visualiseeringu;
- põhjendab, millal valida Loki ja millal Elasticsearch/OpenSearch;
- leiab logirea, mis selgitab mõõdikus nähtud hüpet.

**Tööriistad:** Elasticsearch või OpenSearch, Kibana või OpenSearch Dashboards, logisaatja, Grafana

---

## 10. Päringu teekond

**4 h · Tracing**

**Mida õpime**

- Miks logidest ja mõõdikutest ei piisa, kui päring läbib mitut teenust.
- Trace, span, trace ID, konteksti edasiandmine.
- OpenTelemetry: SDK, kollektor, OTLP.
- Valmis näidisrakenduse jälgede vaatamine Jaegeris või Tempos.

**Eesmärgid** - õppija:

- selgitab trace'i ja spani mõistet joonise abil;
- käivitab OpenTelemetry kollektori ja jälgede taustasüsteemi;
- leiab aeglase päringu ja spani, mis aja ära kulutas.

**Tööriistad:** OpenTelemetry Collector, Jaeger 2 või Tempo 3, näidisrakendus

---

## 11. Kolm sammast koos ja kas üldse töötab

**4 h · Observability**

**Mida õpime**

- Korrelatsioon: trace ID logireas, mõõdikust jäljeni ja jäljest logini.
- Blackbox vs whitebox: väljast vaatamine vs seest mõõtmine.
- Blackbox exporter (HTTP, ICMP) ja Uptime Kuma.
- Lihtne teenuse kättesaadavuse näitaja: mitu protsenti päringuid õnnestus.

**Eesmärgid** - õppija:

- jälgib ühe vea läbi kõigi kolme samba: mõõdiku hüpe → jälg → logirida;
- seadistab kättesaadavuse kontrolli ja alarmi teenuse kadumise kohta;
- selgitab, mida blackbox-kontroll näeb, mida protsessori mõõdik kunagi ei näe.

**Tööriistad:** Grafana, Loki, Jaeger/Tempo, Blackbox exporter, Uptime Kuma

---

## 12. Turvamonitooring ja intsident

**4 h · Observability**

**Mida õpime**

- SIEM: turvasündmuste kogumine ja seostamine.
- Wazuh: manager, indexer, dashboard, agent; reeglid ja tasemed. Wazuhi server on üks ühine (õpetaja oma), õppijad paigaldavad oma masinatesse agendid.
- SSH brute force'i tuvastamine.
- Intsidendiharjutus: õpetaja tekitab rikkeid, õppijad leiavad need oma monitooringust.
- Intsidendiraport: mis juhtus, millal, kuidas avastati, põhjus, parandus.

**Eesmärgid** - õppija:

- selgitab, mille poolest SIEM erineb tavalisest logisüsteemist;
- paigaldab Wazuh agendi oma masinatesse ja leiab ühisest serverist brute force'i hoiatuse;
- leiab etteantud rikked oma monitooringust ja nimetab põhjuse;
- kirjutab lühikese intsidendiraporti.

**Tööriistad:** Wazuh ja kõik varem kasutatud süsteemid

---

## 13. Lõputöö ja kaitsmine

**8 h · Observability**

Rühmad 2-3 inimest. Iga rühm saab süsteemi ja ehitab sellele tervikliku jälgimise.

**Nõuded**

- masinate ja teenuse mõõdikud;
- töölaud, millest saab viie sekundiga aru, kas süsteem on terve;
- vähemalt kaks alarmi, mis jõuavad inimeseni;
- kesksed ja otsitavad logid;
- vähemalt üks jälg või kättesaadavuse kontroll;
- üks intsident läbi mängitud: hüpe töölaual → alarm → logirida → põhjus.

**Eesmärgid** - õppija:

- kavandab ja ehitab etteantud süsteemile jälgimise;
- põhjendab iga tööriista valikut;
- demonstreerib töötavat süsteemi ja vastab küsimustele.

**Kaitsmine:** 8 minutit demo + 2 minutit küsimusi rühma kohta.

---

## Iseseisev töö

Igal kohtumisel on kodutöö umbes 1 tunni jagu. Kohtumise 13 eel on lisaks umbes 3 tundi lõputöö ettevalmistust. Igal laboril on lisaülesanded neile, kes tahavad edasi minna.

Kohtumine 3 on veebiõppe nädal. Õpetajat pole kõrval, seega on loeng ja labor kirjutatud täiesti iseseisvaks läbitöötamiseks: selgitust on rohkem ja iga sammu järel on kontrollpunkt.
