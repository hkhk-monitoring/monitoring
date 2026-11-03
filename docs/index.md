---
tags:
  - Info
  - Monitooring
---

# Süsteemide monitooring

Õpid koguma logisid, mõõdikuid ja jälgi, uurima rikkeid ning kontrollima taastumist.

[Alusta esimesest nädalast](week01/lecture.md){ .md-button .md-button--primary }
[Kontrolli töökeskkonda](kodulabor.md){ .md-button }

## Mida sa õpid

<div class="grid cards" markdown>

-   **Logid**

    ---

    Kogud sündmused ühte kohta ja leiad vajaliku kirje.

-   **Mõõdikud ja alarmid**

    ---

    Jälgid muutusi, koostad päringuid ja seadistad teavitusi.

-   **Jäljed ja intsidendid**

    ---

    Uurid päringu teekonda ja põhjendad rikke põhjust.

</div>

??? abstract "Kursuse õpiväljundid"
    Kursuse lõpuks oskad:

    1. koguda laborimasinate logid keskserverisse, et juba kogutud kirjed oleksid kättesaadavad ka siis, kui masin rikki läheb;
    2. jälgida masinate olekut ühest kohast ja saada teavitus, kui midagi läheb valesti;
    3. koostada kogutud andmete põhjal päringuid ja teha neist töölaua, mille järgi saab otsustada;
    4. otsida logisid siltide ja logisisu järgi ning võrrelda kasutatud logisüsteemide ressursikulu ja otsinguvõimalusi;
    5. leida ühe päringu teekond läbi mitme teenuse;
    6. uurida turvaintsidenti ja kirjutada sellest raport.

## Teemad nädalate kaupa

Masina näidud → keskne kogumine → päringud ja alarmid → rikke uurimine

| Nädal | Teema | Tööriistad |
|---|---|---|
| N1 | [Masina logid ja keskne logiserver](week01/lecture.md) | journald, rsyslog, logrotate, auditd |
| N2 | [Keskne jälgimissüsteem](week02/lecture.md) | Zabbix, Docker Compose |
| N3 | [Mõõdik, aegrida, agent](week03/lecture.md) · *veebiõpe* | top, free, df, Zabbix Cloud |
| N4 | [Agent suhtleb serveriga](week04/lecture.md) | Zabbix agent 2, Ansible |
| N5 | [Server küsib mõõdikuid](week05/lecture.md) | Prometheus, node_exporter, PromQL |
| N6 | Numbrid pildiks ja alarm | Grafana, Alertmanager |
| N7 | Aegrea andmebaas teisiti | Telegraf, InfluxDB |
| N8 | Logid sildi järgi | Loki, Grafana Alloy |
| N9 | Logid täisotsinguga | OpenSearch |
| N10 | Päringu teekond | OpenTelemetry, Jaeger |
| N11 | Kolm sammast koos ja kas üldse töötab | Blackbox exporter, Uptime Kuma |
| N12 | Turvamonitooring ja intsident | Wazuh |
| N13 | Lõputöö ja kaitsmine | rühma valik |

Ülesannete tähtajad ja esitamise lingid leiad Classroom 50-st.

## Enne esimest praktikumi

!!! info "Kontrolli töökeskkonda"
    - Kontrolli SSH-ühendusi kõigi kolme laborimasinaga (`proxmox1`, `proxmox2`, `proxmox3`).
    - Kontrolli Ansible'i olemasolu ja ligipääsu.
    - Kodust töötades ühenda VPN.

    [Ava töökeskkonna eelkontroll](kodulabor.md)

## AI kasutamine

AI võib aidata sul selgitust leida. Oma lahendust pead oskama ise põhjendada: mida iga käsk ja konfiguratsioon teeb, miks seda kasutad ja kuidas tulemust kontrollisid.

**Lubatud**

- küsida AI-lt, mida käsk, konfiguratsiooni võti või veateade tähendab;
- kasutada juhendi käsuplokke.

**Pole lubatud**

- kasutada AI-agenti, mis muudab faile või käivitab käske sinu eest, ka siis, kui kinnitad selle tegevused ise (näiteks Copiloti agent mode, Codex, Claude Code);
- esitada käsku või konfiguratsiooni, mille toimimist sa ei oska selgitada.

??? note "Kuidas käib oma töö selgitamine?"
    Laboritahvli tähelepanek, näiteks agendi jäljed logis, võib olla põhjus lisakontrolliks. Juhendist kopeeritud käsud ei ole rikkumine. Lisakontrolli teate saad oma repositooriumi issue's: lepi õpetajaga 7 päeva jooksul kokku 2-minutiline suuline kontroll, kus selgitad valitud käsku või konfiguratsiooni ja näitad tulemust. Kui kontrollis ei õnnestu oskust tõendada, teed praktikumi uuesti õpetaja juures. Kui sa ei saa kontrolli ajal osaleda, lepi uus aeg kokku enne tähtaega. Reeglid kehtivad alates N3-st.
