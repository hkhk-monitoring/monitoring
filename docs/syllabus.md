---
tags:
  - Info
  - Monitooring
---

# Kursuse ülevaade

Kursusel on 13 kohtumist, 50 akadeemilist tundi kontaktõpet ja 15 tundi iseseisvat tööd. Eeldused on Linuxi käsurida, SSH, Docker Compose ja Ansible'i alused.

Kasutad samu Proxmoxi sõlmi nagu automatiseerimise kursusel. Sõlmes `proxmox1` töötavad monitooringusüsteemid, `proxmox2` ja `proxmox3` on jälgitavad masinad. Ansible'i ja Giti käivitad oma arvutis. Täpsemalt on see kirjas lehel [Töökeskkond](kodulabor.md).

## Kursuse õpiväljundid

Kursuse lõpuks oskad:

1. selgitada logimise, monitooringu ja jälgimise (tracing) erinevust ning seda, kuidas need koos annavad süsteemist tervikpildi (observability);
2. koguda, hoida ja otsida logisid nii ühes masinas kui ka keskses süsteemis;
3. koguda masinate ja teenuste mõõdikuid nii pull- kui ka push-mudeliga ning teha neist töölaua;
4. seadistada alarme, mis jõuavad inimeseni ja mille järgi saab tegutseda;
5. jälgida päringu teekonda läbi mitme teenuse ning siduda jälje logi ja mõõdikuga;
6. leida oma monitooringust rikke ja turvasündmuse ning kirjeldada neid intsidendiraportis;
7. valida olukorrale sobiva tööriista ja põhjendada valikut.

## Kursuse neli osa

??? note "Tabel 0.1. Kursuse osad"
    | Osa | Mida küsib | Kohtumised | Tunnid |
    |---|---|---|---:|
    | Logging | Mis juhtus? | 1, 8, 9 | 12 |
    | Monitoring | Kui palju ja kui kaua? | 2–7 | 18 |
    | Tracing | Kus päring aega kulutas? | 10 | 4 |
    | Observability | Miks see juhtus? (kõik koos) | 11, 12, 13 | 16 |

## Kohtumised ühe pilguga

??? note "Tabel 0.2. Kohtumised (1 tund = 45 min)"
    | Nr | h | Osa | Mõisteplokk | Tööriistad | Loeng / praktikum (min) |
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

Iga kohtumine lõpeb 10–15-minutilise kokkuvõttega.

Praktikum koosneb osadest. Esimestes osades on sammud ette antud, viimastes kasutad sama oskust muudetud olukorras iseseisvalt. Iga praktikumi lõpus on lisaülesanded, kergest raskeni.

Sõlme `proxmox1` mälu on piiratud. Iga praktikumi alguses on kirjas, millised varasemad süsteemid peavad töötama ja millised peatada. Peatamiseks kasuta käsku `docker compose stop`, siis jäävad andmed alles.

## 1. Masina logid ja keskne logiserver

**4 h · Logging**

**Mida õpime**

- Miks monitoorida: rike tuleks avastada enne, kui kasutaja sellest teatab.
- Logide liigid: süsteemi-, autentimis-, kerneli- ja rakenduse logid. Kus need asuvad (`/var/log`, journald).
- `journalctl` monitooringu vaatest: filtrid teenuse, raskusastme ja ajavahemiku järgi, `-f`.
- Syslogi raskusastmed (severity) ja allikad (facility).
- rsyslog: kuidas reeglid logi õigesse faili suunavad, oma reegel ja mall.
- logrotate: miks logid kasvavad üle pea, konfiguratsioon (`daily`, `rotate`, `compress`, `postrotate`), kontroll `-d`-ga.
- Keskne logiserver: rsyslog võtab vastu (TCP/UDP 514), kliendid saadavad.

**Pärast kohtumist oskad:**

- leida `journalctl` abil konkreetse teenuse vead etteantud ajavahemikus;
- seadistada rsyslogi reegli, mis suunab valitud logid eraldi faili;
- koostada teenusele logrotate'i konfiguratsiooni ja seda kontrollida;
- seadistada `proxmox1` keskseks logiserveriks ning suunata `proxmox2` ja `proxmox3` logid sinna;
- põhjendada, miks keskne logimine on vajalik juba kolme masina puhul.

**Tööriistad:** journald/journalctl, rsyslog, logrotate, logger

## 2. Keskne jälgimissüsteem

**2 h · Monitoring**

**Mida õpime**

- Mida monitooringusüsteem teeb: kogub, hoiab, näitab, teavitab.
- Zabbixi ülesehitus: server, andmebaas, veebiliides, agent, proxy.
- Põhimõisted: host, item, trigger, template.
- Zabbixi käivitamine Docker Compose'iga.

**Pärast kohtumist oskad:**

- kirjeldada Zabbixi komponente ja nende omavahelist suhtlust;
- käivitada Zabbixi serveri koos andmebaasi ja veebiliidesega;
- lisada esimese hosti ja leida selle viimased andmed veebiliidesest.

**Tööriistad:** Zabbix 7.0 LTS (server, veebiliides, PostgreSQL), Docker Compose

## 3. Mõõdik, aegrida, agent

**2 h · Monitoring · veebiõpe**

**Mida õpime**

- Mõõdik vs sündmus: number ajas vs kirje sellest, mis juhtus.
- Aegrida ja proovivõtu intervall.
- Mõõdikute liigid: gauge ja counter (histogrammi mainime).
- Mida masinas mõõta: USE-meetod (kasutus, küllastus, vead).
- Agendiga ja agendita kogumine.
- Masina numbrite lugemine käsitsi: tavaolek vs koormus.

**Pärast kohtumist oskad:**

- eristada gauge'i ja counterit ning tuua mõlemast näite;
- rakendada USE-meetodit protsessori, mälu ja ketta kohta;
- mõõta käsitsi masina tavaolekut ja koormusega olekut ning neid võrrelda;
- lugeda Zabbixi graafikult, millal koormus algas ja lõppes.

**Tööriistad:** top/htop, free, df, stress-ng, Zabbixi veebiliides

## 4. Agent räägib serverile

**2 h · Monitoring**

**Mida õpime**

- Zabbix agent 2 paigaldamine `proxmox2`-le ja `proxmox3`-le Ansiblega.
- Passiivne ja aktiivne agent.
- Valmis template'i kasutamine.
- Triggerid ja raskusastmed, probleemi tekkimine ja lahenemine.

**Pärast kohtumist oskad:**

- paigaldada agendi Ansible'i playbook'iga mitmesse masinasse korraga;
- siduda hostid template'iga ja kontrollida, et andmed tulevad;
- luua oma triggeri (näiteks vaba kettaruum alla 20%) ja näidata, et see läheb probleemi olekusse ja tagasi.

**Tööriistad:** Zabbix agent 2, Ansible, Zabbixi template'id

## 5. Server küsib ise

**4 h · Monitoring**

**Mida õpime**

- Pull-mudel: exporter avaldab `/metrics`, Prometheus käib neid ise korjamas.
- Scrape intervall, target, label. Iga labelite kombinatsioon on eraldi aegrida.
- node_exporteri paigaldamine Ansiblega.
- PromQL: valik, labelifilter, `rate()`, `sum by`, `avg`, võrdlus.
- Zabbix vs Prometheus: millal kumb.

**Pärast kohtumist oskad:**

- selgitada, kes alustab andmevahetust Zabbixi passiivse ja aktiivse agendi ning Prometheuse puhul;
- seadistada scrape target'id ja kontrollida **Targets**-lehelt, et need on olekus UP;
- kirjutada PromQL-i päringud protsessori koormuse, mälu kasutuse ja vaba kettaruumi kohta;
- põhjendada, millises olukorras valiksid Zabbixi ja millises Prometheuse.

**Tööriistad:** Prometheus, node_exporter, PromQL, Ansible

## 6. Numbrid pildiks ja alarm

**4 h · Monitoring**

**Mida õpime**

- Grafana andmeallikad, paneelid, ühikud, muutujad.
- Töölaua disain: mida peab inimene viie sekundiga nägema.
- Alarmireegel, lävend ja `for`-kestus, olekud Pending → Firing.
- Alertmanager: marsruutimine, grupeerimine, vaigistamine.
- Contact point ja hea alarmisõnum (milline masin, mis mõõdik, kui hull, mis ajast).

**Pärast kohtumist oskad:**

- ehitada masinate tervise töölaua, kus hosti saab valida muutujaga;
- eemaldada töölaualt paneeli, mis otsust ei toeta, ja seda põhjendada;
- luua alarmireegli ja näidata oleku muutumist;
- seadistada teavituse, mis jõuab kohale, ja hinnata, kas sõnumist saab öösel aru.

**Tööriistad:** Grafana, Alertmanager

## 7. Aegrea andmebaas teisiti

**4 h · Monitoring**

**Mida õpime**

- Push-mudel: agent saadab ise andmebaasi.
- Telegraf: sisend- ja väljundpluginad.
- InfluxDB 3: andmebaas, tabelid, säilitusaeg, päringud SQL-i ja InfluxQL-iga.
- InfluxDB Grafana andmeallikana.
- Prometheus vs InfluxDB: pull vs push, millal kumb.

**Pärast kohtumist oskad:**

- seadistada Telegrafi saatma masina mõõdikuid InfluxDB-sse;
- teha InfluxDB-s päringu ja kuvada tulemuse Grafanas;
- võrrelda push- ja pull-mudelit ning tuua kummagi kohta sobiva olukorra.

**Tööriistad:** Telegraf, InfluxDB 3 Core, Grafana

## 8. Logid sildi järgi

**2 h · Logging**

**Mida õpime**

- Loki ülesehitus: indekseeritakse ainult sildid, mitte logi sisu.
- Grafana Alloy kui kollektor (Promtaili järglane).
- journaldi ja rsyslogi logid Lokisse.
- LogQL: sildifilter, tekstifilter, logiridade arv ajas.

**Pärast kohtumist oskad:**

- seadistada Alloy saatma `proxmox2` ja `proxmox3` logid Lokisse;
- kirjutada LogQL-i päringu, mis leiab kindla teenuse vead;
- selgitada, kuidas indekseerimise viis mõjutab logisüsteemi ressursikulu ja otsinguvõimalusi.

**Tööriistad:** Loki, Grafana Alloy, Grafana

## 9. Logid täisotsinguga

**6 h · Logging**

**Mida õpime**

- Elasticsearch/OpenSearch: dokument, indeks, mapping, täisindeks.
- Logide saatmine klastrisse.
- Kibana/OpenSearch Dashboards: otsing, filtrid, visualiseeringud.
- Loki vs Elastic: kulu, kiirus, otsinguvõimalused.
- Logid ja mõõdikud ühel töölaual: logirida mõõdiku hüppe all.

**Pärast kohtumist oskad:**

- käivitada ühesõlmelise klastri ja saata sinna logid;
- otsida logidest päringukeelega ja ehitada visualiseeringu;
- põhjendada, millal valida Loki ja millal Elasticsearch või OpenSearch;
- leida logirea, mis selgitab mõõdikus nähtud hüpet.

**Tööriistad:** Elasticsearch või OpenSearch, Kibana või OpenSearch Dashboards, logisaatja, Grafana

## 10. Päringu teekond

**4 h · Tracing**

**Mida õpime**

- Miks logidest ja mõõdikutest ei piisa, kui päring läbib mitut teenust.
- Trace, span, trace ID, konteksti edasiandmine.
- OpenTelemetry: SDK, kollektor, OTLP.
- Valmis näidisrakenduse jälgede vaatamine Jaegeris või Tempos.

**Pärast kohtumist oskad:**

- selgitada joonise abil trace'i ja spani mõistet;
- käivitada OpenTelemetry kollektori ja jälgede taustasüsteemi;
- leida aeglase päringu ja spani, mis aja ära kulutas.

**Tööriistad:** OpenTelemetry Collector, Jaeger 2 või Tempo 3, näidisrakendus

## 11. Kolm sammast koos ja kas üldse töötab

**4 h · Observability**

**Mida õpime**

- Korrelatsioon: trace ID logireas, mõõdikust jäljeni ja jäljest logini.
- Blackbox vs whitebox: väljast vaatamine vs seest mõõtmine.
- Blackbox exporter (HTTP, ICMP) ja Uptime Kuma.
- Lihtne teenuse kättesaadavuse näitaja: mitu protsenti päringuid õnnestus.

**Pärast kohtumist oskad:**

- jälgida üht viga läbi kõigi kolme samba: mõõdiku hüppest jäljeni ja jäljest logireani;
- seadistada kättesaadavuse kontrolli ja alarmi teenuse kadumise kohta;
- selgitada, mida näeb blackbox-kontroll, kuid ei näe protsessori mõõdik.

**Tööriistad:** Grafana, Loki, Jaeger/Tempo, Blackbox exporter, Uptime Kuma

## 12. Turvamonitooring ja intsident

**4 h · Observability**

**Mida õpime**

- SIEM: turvasündmuste kogumine ja seostamine.
- Wazuh: manager, indexer, dashboard, agent; reeglid ja tasemed. Wazuhi server on üks ühine (õpetaja oma), õppijad paigaldavad oma masinatesse agendid.
- SSH brute force'i tuvastamine.
- Intsidendiharjutus: õpetaja tekitab rikkeid, õppijad leiavad need oma monitooringust.
- Intsidendiraport: mis juhtus, millal, kuidas avastati, põhjus, parandus.

**Pärast kohtumist oskad:**

- selgitada, mille poolest SIEM erineb tavalisest logisüsteemist;
- paigaldada Wazuhi agendi oma masinatesse ja leida ühisest serverist brute force'i hoiatuse;
- leida etteantud rikked oma monitooringust ja nimetada põhjuse;
- kirjutada lühikese intsidendiraporti.

**Tööriistad:** Wazuh ja kõik varem kasutatud süsteemid

## 13. Lõputöö ja kaitsmine

**8 h · Observability**

Rühmas on 2–3 inimest. Iga rühm saab süsteemi ja ehitab sellele tervikliku jälgimise.

**Nõuded**

- masinate ja teenuse mõõdikud;
- töölaud, millest saab viie sekundiga aru, kas süsteem on terve;
- vähemalt kaks alarmi, mis jõuavad inimeseni;
- kesksed ja otsitavad logid;
- vähemalt üks jälg või kättesaadavuse kontroll;
- üks intsident läbi mängitud: hüpe töölaual → alarm → logirida → põhjus.

**Pärast kohtumist oskad:**

- kavandada ja ehitada etteantud süsteemile jälgimise;
- põhjendada iga tööriista valikut;
- näidata töötavat süsteemi ja vastata küsimustele.

**Kaitsmine:** 8 minutit demo + 2 minutit küsimusi rühma kohta.

## Iseseisev töö

Kohtumiste 1–12 järel on kodutöö, igaüks umbes ühe tunni jagu. Enne kohtumist 13 on lõputöö ettevalmistus, umbes kolm tundi. Kokku on iseseisvat tööd 15 tundi.

Kohtumine 3 on veebiõpe. Õpetajat kõrval pole, seetõttu on selle nädala materjalis selgitust rohkem ja iga sammu järel on kontrollpunkt.
