# Süsteemide monitooring

[Alusta esimesest nädalast](week01/lecture.md) · [Teemad nädalate kaupa](#teemad-nadalate-kaupa)

## Mida sa õpid

Kursuse lõpuks oskad:

1. koguda laborimasinate logid keskserverisse, et juba kogutud kirjed oleksid kättesaadavad ka siis, kui masin rikki läheb;
2. jälgida masinate olekut ühest kohast ja saada teavitus, kui midagi läheb valesti;
3. koostada kogutud andmete põhjal päringuid ja teha neist töölaua, mille järgi saab otsustada;
4. otsida logisid siltide ja logisisu järgi ning võrrelda kasutatud logisüsteemide ressursikulu ja otsinguvõimalusi;
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

- `ssh proxmox1`, `ssh proxmox2` ja `ssh proxmox3` töötavad SSH-võtmega autentides;
- arvutis on Ansible ja VS Code.

Kui mõni neist ei tööta, järgi lehte [Töökeskkond](kodulabor.md).

Ülesannete tähtajad ja esitamise lingid leiad Classroom 50-st.

## AI praktikumides

| Võib | Ei või | Kuidas tõendad oma tööd |
|---|---|---|
| küsida AI-lt, mida käsk, konfiguratsiooni võti või veateade tähendab | kasutada AI-agenti, mis muudab faile või käivitab käske sinu eest, ka siis, kui kinnitad selle tegevused ise (näiteks Copiloti agent mode, Codex, Claude Code) | iga esitatud käsu ja konfiguratsiooni kohta oskad öelda, mida see teeb, miks seda kasutad ja kuidas tulemust kontrollisid |

Laboritahvli tähelepanek, näiteks agendi jäljed logis, võib olla põhjus lisakontrolliks. Juhendist kopeeritud käsud ei ole rikkumine. Lisakontrolli teate saad oma repositooriumi issue's: lepi õpetajaga 7 päeva jooksul kokku 2-minutiline suuline kontroll, kus selgitad valitud käsku või konfiguratsiooni ja näitad tulemust. Kui kontrollis ei õnnestu oskust tõendada, teed praktikumi uuesti õpetaja juures. Kui sa ei saa kontrolli ajal osaleda, lepi uus aeg kokku enne tähtaega. Kehtib alates N3-st.
