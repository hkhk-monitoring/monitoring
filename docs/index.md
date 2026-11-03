# Süsteemide monitooring

[Alusta esimesest nädalast](week01/lecture.md) · [Teemad nädalate kaupa](#teemad-nadalate-kaupa)

## Mida sa õpid

Kursuse lõpuks oskad:

1. koguda laborimasinate logid ühte kohta, et need säiliksid ka siis, kui masin kaob;
2. jälgida masinate olekut ühest kohast ja saada teavitus, kui midagi läheb valesti;
3. koostada kogutud andmete põhjal päringuid ja teha neist töölaua, mille järgi saab otsustada;
4. otsida logidest nii sildi kui ka iga sõna järgi ning võrrelda nende ressursikulu ja otsinguvõimalusi;
5. leida ühe päringu teekond läbi mitme teenuse;
6. uurida turvaintsidenti ja kirjutada sellest raport.

## Teemad nädalate kaupa

| # | Teema | Tööriistad |
|---|---|---|
| N1 | Masina logid ja keskne logiserver | journald, rsyslog, logrotate, auditd |
| N2 | Keskne jälgimissüsteem | Zabbix, Docker Compose |
| N3 | Mõõdik, aegrida, agent *(veebiõpe)* | top, free, df, Zabbix Cloud |
| N4 | Agent suhtleb serveriga | Zabbix agent 2, Ansible |
| N5 | Server küsib mõõdikuid | Prometheus, node_exporter, PromQL |
| N6 | Numbrid pildiks ja alarm | Grafana, Alertmanager |
| N7 | Aegrea andmebaas teisiti | Telegraf, InfluxDB |
| N8 | Logid sildi järgi | Loki, Grafana Alloy |
| N9 | Logid täisotsinguga | OpenSearch |
| N10 | Päringu teekond | OpenTelemetry, Jaeger |
| N11 | Kolm sammast koos ja kas üldse töötab | Blackbox exporter, Uptime Kuma |
| N12 | Turvamonitooring ja intsident | Wazuh |
| N13 | Lõputöö ja kaitsmine | rühma valik |

## Enne esimest tundi

Töökeskkond on sama, mis automatiseerimise kursusel. Enne esimest tundi kontrolli, et:

- `ssh proxmox1`, `ssh proxmox2` ja `ssh proxmox3` töötavad SSH-võtmega ega küsi parooli;
- arvutis on Ansible ja VS Code.

Kui mõni neist ei tööta, järgi lehte [Töökeskkond](kodulabor.md).

Tähtaja näed Classroom 50-s.

## AI praktikumides

| Võib | Ei või | Keelatud |
|---|---|---|
| küsida AI-lt, mida käsk või veateade tähendab | kopeerida AI lahendusi terminali, ilma et saaksid aru, mida need teevad | AI-agendid, mis käivitavad käske sinu masinas (Copilot agent mode, Codex, Claude Code jms) |

Iga käivitatud käsu kohta pead oskama öelda, mida see teeb. Kui laboritahvel näeb agendi jälgi või palju kleebitud teksti, saad repositooriumis issue'i ja näitad 7 päeva jooksul oma tööd suuliselt (2 minutit). Kui seda ei saa, teed praktikumi uuesti tunnis. Kehtib alates N3-st.
