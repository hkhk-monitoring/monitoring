---
tags:
  - Monitooring
  - Prometheus
  - Grafana
  - Alertmanager
  - Praktikum
---

# Praktikum: töölaud ja alarm

N5-s käivitasid `proxmox1`-s Prometheuse, mis kogub mõõdikuid `proxmox2` ja `proxmox3` node_exporteritelt. Täna lisad samasse Compose'i projekti Grafana ja Alertmanageri. Grafanas teed töölaua, kus rippmenüüst saab valida masina. Prometheusesse kirjutad kolm alarmireeglit ja Alertmanager saadab teate kursuse Discordi kanalisse `#it-24`.

Lõpus tekitad kaks riket: peatad node_exporteri ja koormad protsessorit. Mõlemal korral jälgid alarmi teekonda Prometheusest Discordini.

**Edenemine:** laboritahvel <http://192.168.125.187:8092/> (VPN-iga).

??? abstract "Õpiväljundid"
    Pärast loengut ja praktikumi oskad:

    1. lisada Grafana Compose'i projekti ja kirjeldada Prometheuse andmeallika failiga;
    2. koostada töölaua paneelid õige ühiku ja legendiga ning kasutada muutujat `$instance`;
    3. kirjutada Prometheuse alarmireeglid ja kontrollida neid käsuga `promtool check rules`;
    4. seadistada Alertmanageri grupeerimise ja Discordi vastuvõtja nii, et webhooki aadress ei ole repositooriumis;
    5. tekitada rikke ja jälgida alarmi olekuid Pending ja Firing ning teadet Discordis.

<figure markdown="span">
  ![proxmox1 Docker Compose projektis Prometheus pordil 9090, Grafana pordil 3000 ja Alertmanager pordil 9093 ning saladuse fail; proxmox2 ja proxmox3 node_exporter pordil 9100; sinu arvutist brauser ja Git; Alertmanager saadab teate internetis olevasse Discordi pordil 443](../images/n06_topoloogia.svg)
  <figcaption>Joonis 6.5. Praktikumi topoloogia (Talvik, 2026).</figcaption>
</figure>

Esimesed failid on näidatud tervikuna, järgmised kirjutad nõuete järgi ise. Näidislahendus on kokkuvolditud plokis. Kui tuleb veateade, ava plokk, mis algab sõnaga **Kui**.

## Osa 1 · Repositoorium ja algseis

Kasutatavad versioonid on Prometheus 3.15.1, Grafana 13.2.6 ja Alertmanager 0.35.0. Kõik kolm töötavad `proxmox1`-s konteinerites.

Ava Classroom 50 link ([Praktikum 6 - Töölaud ja alarm](https://classroom50.org/hkhk-monitoring/it24-monitooring/assignments)) ja klooni oma repositoorium:

```bash
git clone <sinu-repo-URL>
cd <repo-kaust>
ls -a konf
```

??? success "Oodatav tulemus"
    ```text
    .  ..  alus  .gitkeep
    ```

    Kaustas `konf/alus/` on N5 näidisfailid neile, kelle N5 Prometheus ei tööta. Fail `.gitignore` repositooriumi juurkaustas hoiab kausta `saladus/` repositooriumist väljas.

Kontrolli, et N5 tulemus töötab: Prometheus vastab ja mõlemad node_exporterid on olekus `up`.

```bash
ssh proxmox1 "cd ~/prometheus && docker compose ps"
ssh proxmox1 "curl -fsS localhost:9090/api/v1/targets" | grep -o '"health":"[a-z]*"'
```

??? success "Oodatav tulemus"
    Konteiner `prometheus-prometheus-1` on olekus `Up` ja väljundis on kolm rida `"health":"up"`.

??? warning "Kui N5 Prometheus ei tööta või kausta `~/prometheus` pole"
    Tee algseis valmis starteri näidisfailidega. Playbook paigaldab node_exporteri mõlemasse masinasse, nagu N5 osas 4:

    ```bash
    ansible-galaxy collection install ansible.posix
    ansible-playbook -i proxmox2,proxmox3, konf/alus/node_exporter.yml
    ```

    Kopeeri Prometheuse failid repositooriumi kausta `konf/`. Asenda failis `konf/config/prometheus.yml` kaks kohta `<proxmox2-IP>` ja `<proxmox3-IP>` masinate laborivõrgu aadressidega (`ssh proxmox2 hostname -I`). Seejärel kopeeri failid `proxmox1`-sse ja käivita:

    ```bash
    mkdir -p konf/config
    cp konf/alus/compose.yaml konf/
    cp konf/alus/prometheus.yml konf/config/
    ssh proxmox1 "mkdir -p ~/prometheus"
    scp -r konf/compose.yaml konf/config proxmox1:prometheus/
    ssh proxmox1 "cd ~/prometheus && docker compose up -d"
    ```

    Kontrolli uuesti Targets-lehelt, et mõlemad node_exporterid on `UP`, ja jätka osaga 2. Järgmise sammu kopeerimiskäsu jäta vahele, sest failid on juba repositooriumis.

Kogu Compose'i projekt peab olema repositooriumis, et automaatkontroll näeks seadistust tervikuna. Kopeeri N5 failid `proxmox1`-st repositooriumi kausta `konf/`:

```bash
scp proxmox1:prometheus/compose.yaml konf/
scp -r proxmox1:prometheus/config konf/
ls konf konf/config
```

??? success "Oodatav tulemus"
    Kaustas `konf/` on `compose.yaml` ja kaust `config`, mille sees on `prometheus.yml`. Edaspidi muudad faile repositooriumis ja kopeerid need `proxmox1`-sse ühe käsuga.

Grafana vajab umbes 150 MB ja Alertmanager umbes 30 MB mälu. Kontrolli, et `proxmox1`-s on veerus `available` vähemalt 600 MB:

```bash
ssh proxmox1 "free -h"
```

Kui mälu on vähem, peata N2 Zabbix samamoodi nagu N5 osas 1: `ssh proxmox1 "cd ~/zabbix && docker compose stop"`.

## Osa 2 · Grafana

Grafana küsib andmeid Prometheuselt. Andmeallika kirjeldad failiga, et see tekiks igas uues Grafana konteineris ise ([Provisioning, Data sources](https://grafana.com/docs/grafana/latest/administration/provisioning/#data-sources)).

Loo fail `konf/grafana/prometheus.yml`:

???+ example "Fail `konf/grafana/prometheus.yml`"
    ```yaml
    apiVersion: 1

    datasources:
      - name: Prometheus
        type: prometheus
        access: proxy
        url: http://prometheus:9090
        isDefault: true
    ```

Aadress on `http://prometheus:9090`, sest Compose'i võrgus leiab Grafana Prometheuse teenuse nime järgi.

Lisa faili `konf/compose.yaml` teenus `grafana` ([Run Grafana Docker image](https://grafana.com/docs/grafana/latest/setup-grafana/installation/docker/)). Nõuded:

- image `grafana/grafana:13.2.6`, port `3000:3000`, `restart: unless-stopped`;
- kaust `./grafana` on konteineris kaustas `/etc/grafana/provisioning/datasources`, ainult lugemiseks;
- nimega andmeköide `grafana-data` on konteineris kaustas `/var/lib/grafana`, nii et töölauad ja parool jäävad alles ka siis, kui konteiner luuakse uuesti;
- `grafana-data` on lisatud ka faili lõpus olevasse plokki `volumes:`.

??? tip "Vihje"
    Teenus `grafana` on samal taandel kui `prometheus` ja samal kujul: `image`, `ports`, `volumes`, `restart`.

??? example "Näidislahendus: teenus grafana"
    ```yaml
      grafana:
        image: grafana/grafana:13.2.6
        ports:
          - "3000:3000"
        volumes:
          - ./grafana:/etc/grafana/provisioning/datasources:ro
          - grafana-data:/var/lib/grafana
        restart: unless-stopped
    ```

    ```yaml
    volumes:
      prometheus-data:
      grafana-data:
    ```

Kopeeri failid `proxmox1`-sse ja käivita. Sama kopeerimiskäsku kasutad praktikumi jooksul iga muudatuse järel:

```bash
scp -r konf/compose.yaml konf/config konf/grafana proxmox1:prometheus/
ssh proxmox1 "cd ~/prometheus && docker compose up -d && docker compose ps"
```

??? question "Kas `docker compose up -d` taaskäivitab ka Prometheuse konteineri?"
    Mõtle enne käsu käivitamist läbi, mis Compose'i failis muutus.

    ??? success "Vastus"
        Ei. Compose loob uue konteineri ainult teenusele, mille kirjeldus muutus. Prometheuse kirjeldus jäi samaks, väljundis on selle kohta `Running`.

Ava brauseris `http://<proxmox1-IP>:3000`. Esimene sisselogimine on kasutajanime ja parooliga `admin`, Grafana palub kohe uue parooli. Ava **Connections → Data sources → Prometheus** ja vajuta lehe allosas **Test**.

??? success "Oodatav tulemus"
    Teade **Successfully queried the Prometheus API**. Failiga lisatud andmeallikat veebiliideses muuta ei saa, seepärast on seal nupu **Save & test** asemel ainult **Test**.

??? warning "Kui andmeallikat pole või test annab vea"
    Vaata logi: `ssh proxmox1 "cd ~/prometheus && docker compose logs grafana | grep -i provisioning"`. Kontrolli, et fail on `proxmox1`-s kaustas `~/prometheus/grafana/` ja et aadress on `http://prometheus:9090`, mitte `localhost`. Kui logis on `permission denied`, kasutab Docker SELinuxi: lisa ühendusele märge `:ro,Z` (`./grafana:/etc/grafana/provisioning/datasources:ro,Z`).

## Osa 3 · Töölaud

Töölaual on kolm paneeli N5 päringutega: saadaval mälu, protsessori kasutus ja juurfailisüsteemi vaba ruum. Rippmenüüst valid, millise masina andmeid paneelid näitavad.

### 3.1 Esimene paneel

Tee uus töölaud: **Dashboards → New → New dashboard**, seejärel **Add visualization**. Andmeallikas on **Prometheus**. Lülita päringuväli režiimi **Code** ja kirjuta päring:

```text
node_memory_MemAvailable_bytes{job="node"}
```

Seadista paneel:

1. paremal **Title**: `Saadaval mälu`;
2. paremal **Standard options → Unit**: **bytes(IEC)**;
3. päringu all **Options → Legend**: **Custom**, väärtus `{{instance}}`.

Vajuta **Save dashboard**, nimi `N6`, ja tule töölauale tagasi (**Back to dashboard**).

??? success "Oodatav tulemus"
    Paneelil on kaks joont, kummagi masina kohta üks. Teljel on ühik MiB või GiB, legendis masinate aadressid koos pordiga.

### 3.2 Kaks paneeli veel

Lisa töölauale veel kaks paneeli (**Add → Visualization**). Päringud on N5 osa 6 päringud, mis annavad ühe rea masina kohta:

- `Protsessori kasutus`: protsessori kasutus protsentides, ühik **Percent (0-100)**;
- `Juurfailisüsteemi vaba ruum`: juurfailisüsteemi vaba ruum protsentides, ühik **Percent (0-100)**, visualiseering **Gauge**.

Mõlemal paneelil on legend `{{instance}}`. Salvesta töölaud.

??? example "Näidislahendus: päringud"
    ```text
    100 * (1 - avg by (instance) (rate(node_cpu_seconds_total{mode="idle"}[1m])))
    ```

    ```text
    100 * node_filesystem_avail_bytes{mountpoint="/"} / node_filesystem_size_bytes{mountpoint="/"}
    ```

### 3.3 Muutuja instance

Töölaua seadetes tee muutuja, mille väärtused on masinate aadressid ([Variables](https://grafana.com/docs/grafana/latest/dashboards/variables/add-template-variables/)):

1. **Edit → Settings → Variables → Add variable**;
2. **Variable type**: **Query**, **Name**: `instance`, **Data source**: **Prometheus**;
3. **Query type**: **Label values**, **Label**: `instance`, **Metric**: `up`, **Label filters**: `job = node`;
4. allosas **Preview of values** peab olema kaks aadressi, vajuta **Back to list** ja salvesta töölaud.

Töölaua ülaossa tekib rippmenüü `instance`. Paneelid seda veel ei kasuta. Lisa igasse kolme päringusse filter `instance="$instance"`, nii et paneel näitab ainult valitud masinat.

??? tip "Vihje"
    Filter läheb iga mõõdiku nime järele loogeliste sulgude sisse. Kui sulgudes on juba silt, eralda filtrid komaga. Protsessori ja ketta päringus on kaks mõõdikut, filter läheb mõlema juurde.

??? example "Näidislahendus: päringud muutujaga"
    ```text
    node_memory_MemAvailable_bytes{job="node", instance="$instance"}
    ```

    ```text
    100 * (1 - avg by (instance) (rate(node_cpu_seconds_total{mode="idle", instance="$instance"}[1m])))
    ```

    ```text
    100 * node_filesystem_avail_bytes{mountpoint="/", instance="$instance"} / node_filesystem_size_bytes{mountpoint="/", instance="$instance"}
    ```

Vaheta rippmenüüs masinat.

??? success "Oodatav tulemus"
    Kõik kolm paneeli näitavad ainult valitud masinat ja muutuvad korraga.

### 3.4 Töölaud repositooriumi

Töölaud on Grafana andmebaasis. Et see oleks repositooriumis, ekspordi see JSON-ina. Vali töölaua ülaribal **Export → Export as code**, ava **Advanced options** ja pane **Model** väärtuseks **Classic**. Vaikimisi kuju **V2 Resource** on Grafana uue API kuju, automaatkontroll ootab klassikalist töölaua JSON-i. Vali **Copy to clipboard**, loo repositooriumis fail `konf/toolaud.json` ja kleebi sisu sinna.

```bash
grep -c '\$instance' konf/toolaud.json
```

??? success "Oodatav tulemus"
    Vähemalt 3: iga paneeli päringus on `$instance`.

## Osa 4 · Alarmireeglid

Reeglid on eraldi failis `konf/config/reeglid.yml`. Kaust `config` on konteineris kaustas `/etc/prometheus`, seega näeb Prometheus faili sama kausta kaudu kui `prometheus.yml`.

### 4.1 Esimene reegel

Esimene reegel on N5 osa 6.4 päring: juurfailisüsteemis on vaba ruumi alla 20%.

???+ example "Fail `konf/config/reeglid.yml`"
    ```yaml
    groups:
      - name: masinad
        rules:
          - alert: KettaruumOtsas
            expr: 100 * node_filesystem_avail_bytes{mountpoint="/"} / node_filesystem_size_bytes{mountpoint="/"} < 20
            for: 5m
            labels:
              severity: hoiatus
            annotations:
              summary: "{{ $labels.instance }}: juurfailisüsteemis on vaba ruumi {{ $value | printf \"%.0f\" }}%"
    ```

Kirjas `{{ $value | printf "%.0f" }}` on tingimuse väärtus täisarvuks ümardatud. Jutumärgid on teksti sees, seepärast on nende ees kaldkriips.

### 4.2 Kaks reeglit veel

Lisa samasse loendisse `rules` kaks reeglit. Nõuded:

- `ProtsessorKoormatud`: protsessori kasutus on üle 80% vähemalt 1 minuti, `severity: hoiatus`, `summary` ütleb masina ja kasutuse protsendi;
- `MasinEiVasta`: job'i `node` target ei vasta (`up` väärtus 0) vähemalt 1 minuti, `severity: kriitiline`, `summary` ütleb masina.

??? tip "Vihje"
    Protsessori tingimus on osa 3.2 päring ilma muutujata, mille lõppu on lisatud võrdlus. N5 lisaülesandes 2 kirjutasid päringu, mis tagastab ainult target'id, mille kogumine ebaõnnestus.

??? example "Näidislahendus: kaks reeglit"
    ```yaml
          - alert: ProtsessorKoormatud
            expr: 100 * (1 - avg by (instance) (rate(node_cpu_seconds_total{mode="idle"}[1m]))) > 80
            for: 1m
            labels:
              severity: hoiatus
            annotations:
              summary: "{{ $labels.instance }}: protsessori kasutus {{ $value | printf \"%.0f\" }}%"

          - alert: MasinEiVasta
            expr: up{job="node"} == 0
            for: 1m
            labels:
              severity: kriitiline
            annotations:
              summary: "{{ $labels.instance }}: Prometheus ei saa mõõdikuid kätte"
    ```

### 4.3 Reeglid Prometheusesse

Prometheus loeb reeglifaili, kui selle nimi on `prometheus.yml`-is võtme `rule_files` all. Lisa faili `konf/config/prometheus.yml` plokk `global` järele, samale tasemele:

???+ example "Failiosa: rule_files"
    ```yaml
    rule_files:
      - reeglid.yml
    ```

Suhteline nimi tähendab faili samas kaustas, kus on `prometheus.yml`. Lisa plokki `global` ka rida `evaluation_interval: 15s`, mis ütleb, kui tihti Prometheus reegleid hindab.

Kopeeri failid `proxmox1`-sse ja kontrolli reegleid enne kasutamist. Prometheuse image'is on tööriist `promtool`, mis kontrollib reeglifaili süntaksit ja päringuid:

```bash
scp -r konf/compose.yaml konf/config konf/grafana proxmox1:prometheus/
ssh proxmox1 "cd ~/prometheus && docker compose exec prometheus promtool check rules /etc/prometheus/reeglid.yml"
```

??? success "Oodatav tulemus"
    ```text
    Checking /etc/prometheus/reeglid.yml
      SUCCESS: 3 rules found
    ```

??? warning "Kui `promtool` annab vea"
    Veateade ütleb rea numbri. Tavalised põhjused: taane on erinev teiste reeglitega, `for` väärtusel puudub ühik (`1m`, mitte `1`) või PromQL-is on sulg puudu. Kontrolli päringut enne Prometheuse veebiliideses **Query**.

Prometheus loeb seaded ainult käivitamisel. Taaskäivita konteiner ja ava veebiliideses **Alerts**:

```bash
ssh proxmox1 "cd ~/prometheus && docker compose restart prometheus"
```

??? success "Oodatav tulemus"
    Lehel **Alerts** on rühm `masinad` ja selles kolm reeglit olekus **Inactive**. Kui mõni reegel on juba **Pending** või **Firing**, kehtib selle tingimus kohe, näiteks ketas on tõesti peaaegu täis.

## Osa 5 · Alertmanager ja Discord

Alertmanager saab alarmid Prometheuselt ja saadab teate Discordi kanalisse `#it-24`. Webhooki aadress on saladus. Õpetaja on selle kopeerinud `proxmox1`-sse faili `~/prometheus/saladus/discord_url`. Kontrolli, et fail on olemas, aga ära näita selle sisu ekraanil:

```bash
ssh proxmox1 "ls -l ~/prometheus/saladus/"
```

??? success "Oodatav tulemus"
    Rida `-rw-r--r-- ... discord_url`. Fail on loetav kõigile, sest Alertmanager töötab konteineris kasutajana `nobody`. Teised kasutajad faili ei näe, sest kodukaust on suletud.

??? warning "Kui faili `discord_url` pole"
    Ütle õpetajale. Seni saad teha osa 5 lõpuni ja osas 6 jälgida alarme Alertmanageri veebiliideses, Discordi teade tuleb pärast faili lisamist.

### 5.1 Alertmanageri seaded

Loo fail `konf/alertmanager/alertmanager.yml`. Vastuvõtja on antud: Alertmanager loeb webhooki aadressi failist, mitte seadetest ([discord_config](https://prometheus.io/docs/alerting/latest/configuration/#discord_config)).

???+ example "Failiosa: receivers"
    ```yaml
    receivers:
      - name: discord
        discord_configs:
          - webhook_url_file: /saladus/discord_url
    ```

Marsruudi `route` kirjuta ise faili algusesse ([route](https://prometheus.io/docs/alerting/latest/configuration/#route)). Nõuded:

- kõik alarmid lähevad vastuvõtjale `discord`;
- sama nimega alarmid (`alertname`) tulevad ühe teatena;
- esimene teade tuleb 30 sekundi jooksul, grupi muutusest teatatakse kõige varem 5 minuti pärast ja kestvat alarmi korratakse 4 tunni järel.

??? tip "Vihje"
    Vaata loengu tabelit 6.3. Võtmed on `receiver`, `group_by`, `group_wait`, `group_interval` ja `repeat_interval`.

??? example "Näidislahendus: route"
    ```yaml
    route:
      receiver: discord
      group_by: [alertname]
      group_wait: 30s
      group_interval: 5m
      repeat_interval: 4h
    ```

### 5.2 Teenus alertmanager

Lisa faili `konf/compose.yaml` teenus `alertmanager`. Nõuded:

- image `prom/alertmanager:v0.35.0`, port `9093:9093`, `restart: unless-stopped`;
- kaust `./alertmanager` on konteineris kaustas `/etc/alertmanager`, ainult lugemiseks: image'i vaikimisi käsk loeb faili `/etc/alertmanager/alertmanager.yml`;
- kaust `./saladus` on konteineris kaustas `/saladus`, ainult lugemiseks;
- nimega andmeköide `alertmanager-data` on konteineris kaustas `/alertmanager` ja on lisatud faili lõpus olevasse plokki `volumes:`.

??? example "Näidislahendus: teenus alertmanager"
    ```yaml
      alertmanager:
        image: prom/alertmanager:v0.35.0
        ports:
          - "9093:9093"
        volumes:
          - ./alertmanager:/etc/alertmanager:ro
          - ./saladus:/saladus:ro
          - alertmanager-data:/alertmanager
        restart: unless-stopped
    ```

    ```yaml
    volumes:
      prometheus-data:
      grafana-data:
      alertmanager-data:
    ```

### 5.3 Prometheus saadab alarmid Alertmanagerile

Prometheus peab teadma, kuhu Firing olekus alarmid saata. Lisa faili `konf/config/prometheus.yml` plokk `alerting` ([alertmanager_config](https://prometheus.io/docs/prometheus/latest/configuration/configuration/#alertmanager_config)):

???+ example "Failiosa: alerting"
    ```yaml
    alerting:
      alertmanagers:
        - static_configs:
            - targets: ["alertmanager:9093"]
    ```

Kopeeri failid, käivita uus teenus ja taaskäivita Prometheus, et see loeks muudetud seaded:

```bash
scp -r konf/compose.yaml konf/config konf/grafana konf/alertmanager proxmox1:prometheus/
ssh proxmox1 "cd ~/prometheus && docker compose up -d && docker compose restart prometheus && docker compose ps"
ssh proxmox1 "curl -fsS localhost:9090/api/v1/alertmanagers"
```

??? success "Oodatav tulemus"
    Kolm konteinerit olekus `Up`. API vastuses on `activeAlertmanagers` all aadress `http://alertmanager:9093/api/v2/alerts`. Ava brauseris `http://<proxmox1-IP>:9093`: Alertmanageri veebiliides on tühi, sest ükski alarm ei ole Firing.

??? warning "Kui alertmanager taaskäivitub pidevalt"
    Vaata logi: `ssh proxmox1 "cd ~/prometheus && docker compose logs alertmanager | tail"`. Rida `error reading webhook_url_file` või `no such file` tähendab, et faili `~/prometheus/saladus/discord_url` pole või ühendus `./saladus:/saladus` on vale. Seadete süntaksi kontrollib `docker compose run --rm alertmanager amtool check-config /etc/alertmanager/alertmanager.yml`. SELinuxi korral lisa ühendustele märge `:ro,Z`.

## Osa 6 · Kaks riket

Nüüd tekitad rikke ja jälgid, kuidas alarm liigub Prometheusest Alertmanagerisse ja sealt Discordi. Hoia brauseris lahti kolm vahekaarti: Prometheuse **Alerts**, Alertmanageri veebiliides ja Discordi kanal `#it-24`.

### 6.1 Masin ei vasta

??? question "Mitu minutit läheb node_exporteri peatamisest Discordi teateni?"
    Arvesta, kui tihti Prometheus kogub ja reegleid hindab (15 s), mis on reegli `for` ja mis on `group_wait`.

    ??? success "Vastus"
        Umbes kaks minutit. Kogumine ebaõnnestub järgmisel kogumisel, reegel on 1 minuti olekus Pending, siis Firing. Alertmanager ootab enne esimest teadet 30 sekundit. Lisaks võib kuluda kuni 15 sekundit, kuni reeglit järgmine kord hinnatakse.

Peata `proxmox3`-s node_exporter ja pane kirja kellaaeg:

```bash
date +%T; ssh proxmox3 "sudo systemctl stop node_exporter"
```

Värskenda Prometheuse **Alerts** lehte. Kui `MasinEiVasta` on olekus **Firing**, salvesta alarmide nimekiri tõendiks:

```bash
ssh proxmox1 "curl -fsS localhost:9090/api/v1/alerts" > logid/n6-masin.json
grep -o '"alertname":"[A-Za-z]*"\|"state":"[a-z]*"' logid/n6-masin.json
```

??? success "Oodatav tulemus"
    Read `"alertname":"MasinEiVasta"` ja `"state":"firing"`. Discordi kanalisse tuleb teade pealkirjaga `[FIRING:1] MasinEiVasta`, mille all on sildid ja `summary` tekst. Teate saatja nimi on see, mille õpetaja webhookile andis.

Käivita node_exporter uuesti ja jälgi, mis Discordi tuleb:

```bash
ssh proxmox3 "sudo systemctl start node_exporter"
```

??? success "Oodatav tulemus"
    Umbes minuti jooksul läheb alarm Prometheuses tagasi olekusse Inactive ja Discordi tuleb teade `[RESOLVED] MasinEiVasta`. Alertmanager saadab lahenemise teate, sest Discordi vastuvõtja vaikimisi väärtus on `send_resolved: true`.

### 6.2 Protsessor on koormatud

Ava Grafana töölaud ja vali rippmenüüst `proxmox2` aadress. Tekita `proxmox2`-s kolmeks minutiks koormus. `stress-ng` paigaldasid N5 osas 1:

```bash
date +%T; ssh proxmox2 'stress-ng --cpu $(nproc) --timeout 180s'; date +%T
```

Teises terminalis jälgi alarmi olekut. Kui `ProtsessorKoormatud` on Prometheuses olekus **Firing** ja on jõudnud Alertmanagerisse, salvesta Alertmanageri vaade tõendiks:

```bash
ssh proxmox1 "curl -fsS localhost:9093/api/v2/alerts" > logid/n6-protsessor.json
grep -o '"alertname":"[A-Za-z]*"' logid/n6-protsessor.json
```

??? success "Oodatav tulemus"
    Grafana paneelil tõuseb protsessori kasutus 100 lähedale. Umbes 1,5 minuti pärast on reegel Pending, siis Firing. Failis on `"alertname":"ProtsessorKoormatud"`. Discordi tuleb teade, ja pärast katse lõppu teade `[RESOLVED]`.

??? warning "Kui alarm on Firing, aga Discordi teadet ei tule"
    Ava Alertmanageri veebiliides: kui alarm on seal, jõudis see kohale ja viga on teate saatmisel. Vaata logi: `ssh proxmox1 "cd ~/prometheus && docker compose logs alertmanager | grep -i discord"`. Rida `unexpected status code 401` või `404` tähendab, et webhooki aadress on vale või kustutatud. Ühenduse viga tähendab, et `proxmox1` ei pääse internetti pordil 443.

??? question "Miks graafik tõusis kohe, aga alarm tuli alles poolteist minutit hiljem?"
    Mõtle, mis on päringus `[1m]` ja mis on reeglis `for: 1m`.

    ??? success "Vastus"
        `rate(...[1m])` on viimase minuti keskmine, seega jõuab väärtus üle 80% alles umbes poole minuti jooksul. Seejärel peab tingimus kehtima veel minuti (`for: 1m`), enne kui alarm on Firing.

## Osa 7 · Kokkuvõte

Vasta README jaotises **Osa 7**:

1. Mitu minutit läks osas 6.1 node_exporteri peatamisest Discordi teateni? Millest see aeg koosnes?
2. Kui `proxmox2` ja `proxmox3` node_exporter peatuksid korraga, mitu Discordi teadet tuleks ja miks?
3. Milline sinu kolmest reeglist on kasutaja seisukohast kõige olulisem ja milline võiks olla töölaua paneel, mitte alarm?

Prometheus, Grafana ja Alertmanager jäävad `proxmox1`-s tööle. N7-s võrdled sama mälunäitu teise kogumisteega.

??? note "Kontrollnimekiri"
    - [ ] Grafana andmeallikas tuleb failist ja test on edukas.
    - [ ] Töölaual on kolm paneeli õige ühikuga ja muutuja `instance`, töölaud on failis `konf/toolaud.json`.
    - [ ] `promtool check rules` leiab 3 reeglit ja need on Prometheuse **Alerts** lehel.
    - [ ] Alertmanager töötab ja Prometheus näeb seda (`activeAlertmanagers`).
    - [ ] Failides `logid/n6-masin.json` ja `logid/n6-protsessor.json` on Firing olekus alarmid.
    - [ ] Discordi kanalisse tuli mõlema rikke kohta FIRING ja RESOLVED teade.
    - [ ] Webhooki aadressi ei ole repositooriumis.

## Töö esitamine

Repositooriumis on Compose'i projekt, reeglid, Alertmanageri seaded, töölaud, tõendid ja README vastused. Kontrolli enne lisamist, et webhooki aadress ei ole ühelgi failil:

```bash
grep -rl "discord.com/api/webhooks" . || echo "aadressi pole"
git status
git add README.md konf logid
git commit -m "Praktikum 6: töölaud ja alarm"
git push
```

Tulemuse näed Classroom 50-s.

## Lisaülesanded

??? example "1 · Valmis töölaud Node Exporter Full"
    Impordi kogukonna töölaud: **Dashboards → New → Import**, ID `1860`, **Load**, andmeallikaks **Prometheus**, **Import** ([Import dashboards](https://grafana.com/docs/grafana/latest/dashboards/build-dashboards/import-dashboards/)). Leia sealt oma masinate mälu ja ketta näit ning ava ühe paneeli **Edit**, et näha selle päringut. Kui ID järgi importimine ebaõnnestub, laadi brauseris lehelt [Node Exporter Full](https://grafana.com/grafana/dashboards/1860) alla JSON-fail ja impordi see.

??? example "2 · Vaigistamine hoolduse ajaks"
    Enne hooldust vaigistatakse alarmid, et teated ei ärataks valvajat. Ava Alertmanageri veebiliides, vali **New Silence** ja tee vaigistus 10 minutiks sildile `instance` väärtusega `proxmox3` aadress ([Silences](https://prometheus.io/docs/alerting/latest/alertmanager/#silences)). Peata `proxmox3` node_exporter. Kas alarm on Prometheuses Firing? Kas Discordi tuleb teade? Käivita node_exporter uuesti ja eemalda vaigistus.

??? example "3 · Üks rike, üks teade"
    Kui masin ei vasta, ei ole selle protsessori ega ketta alarmidel mõtet. Alertmanageri **inhibit rule** vaigistab ühe alarmi, kui teine kehtib ([inhibit_rule](https://prometheus.io/docs/alerting/latest/configuration/#inhibit_rule)). Lisa reegel: kui `MasinEiVasta` on Firing, vaigistatakse sama `instance`-ga alarmid, mille `severity` on `hoiatus`. Kontrolli süntaksit `amtool check-config` käsuga.

??? example "4 · Sama alarm Grafanas"
    Tee Grafanas alarmireegel sama protsessori tingimusega ([Grafana Alerting](https://grafana.com/docs/grafana/latest/alerting/)): **Alerting → Alert rules → New alert rule**. Võrdle Prometheuse reegliga: kus on reegel kirjas, kas see on repositooriumis ja mis juhtub teatega, kui Grafana konteiner seisab.
