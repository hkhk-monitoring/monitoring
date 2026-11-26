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
  <figcaption>Joonis 6.6. Praktikumi topoloogia (Talvik, 2026).</figcaption>
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

Teate teksti `summary` kirjuta mõlemal reeglil oma sõnadega. Valvaja loeb seda öösel telefonist, seega peab tekstist aru saama ilma graafikut avamata: milline masin, mis juhtus, väärtus ja mida esimesena kontrollida. Masina aadress on `{{ $labels.instance }}`, tingimuse väärtus `{{ $value }}` ([Templating](https://prometheus.io/docs/prometheus/latest/configuration/alerting_rules/#templating)).

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
              summary: "<sinu tekst>"

          - alert: MasinEiVasta
            expr: up{job="node"} == 0
            for: 1m
            labels:
              severity: kriitiline
            annotations:
              summary: "<sinu tekst>"
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

Alertmanager saab alarmid Prometheuselt ja saadab teate Discordi kanalisse `#it-24`. Discord võtab teate vastu webhooki kaudu: aadressi lõpus on token, seega on kogu aadress saladus (loengu joonis 6.5). Õpetaja on selle kopeerinud `proxmox1`-sse faili `~/prometheus/saladus/discord_url`. Kontrolli, et fail on olemas, aga ära näita selle sisu ekraanil:

```bash
ssh proxmox1 "ls -l ~/prometheus/saladus/"
```

??? success "Oodatav tulemus"
    Rida `-rw-r--r-- ... discord_url`. Fail on loetav kõigile, sest Alertmanager töötab konteineris kasutajana `nobody`. Teised kasutajad faili ei näe, sest kodukaust on suletud.

??? warning "Kui faili `discord_url` pole"
    Küsi õpetajalt webhooki aadress ja loo fail ise. Käsk `read -s` loeb aadressi ekraanile näitamata, nii et see ei jää ka käsuajalukku:

    ```bash
    read -rsp "Webhooki aadress: " URL; echo
    printf '%s\n' "$URL" | ssh proxmox1 "mkdir -p ~/prometheus/saladus && cat > ~/prometheus/saladus/discord_url && chmod 644 ~/prometheus/saladus/discord_url"
    unset URL
    ```

### 5.1 Alertmanageri seaded

Loo fail `konf/alertmanager/alertmanager.yml`. Vastuvõtja on antud: Alertmanager loeb webhooki aadressi failist, mitte seadetest ([discord_config](https://prometheus.io/docs/alerting/latest/configuration/#discord_config)).

???+ example "Failiosa: receivers"
    ```yaml
    receivers:
      - name: discord
        discord_configs:
          - webhook_url_file: /saladus/discord_url
            username: mtamm
    ```

Kanalisse `#it-24` saadavad teateid kõik õppijad. Võti `username` paneb teate saatjaks sinu nime: asenda `mtamm` oma Proxmoxi kasutajanimega.

Vaikimisi teates on kõik sildid ja aadress Prometheuse veebiliidesesse, see on pikk ja raskesti loetav. Teate kuju määrab **mall** (template): `title` on pealkiri, `message` on sisu. Mallis on `{{ .Status }}` olek (`firing` või `resolved`), `{{ .CommonLabels.alertname }}` alarmi nimi ja `{{ range .Alerts }}…{{ end }}` käib läbi kõik grupi alarmid. Näited on lehel [Notification template examples](https://prometheus.io/docs/alerting/latest/notification_examples/), Discordi jaoks sobib „Ranging over all received Alerts“.

Kanalis on kõigi õppijate teated, seega peab sinu nimi olema alarmi enda sees, mitte ainult saatja nimes. Prometheus lisab igale alarmile sildid, mis on failis `prometheus.yml` plokis `global` võtme `external_labels` all ([Configuration, global](https://prometheus.io/docs/prometheus/latest/configuration/configuration/#configuration-file)).

Nõuded:

- igal sinu Prometheuse alarmil on silt `oppija`, mille väärtus on sinu Proxmoxi kasutajanimi;
- teate pealkirjas on olek suurtähtedega, sinu nimi ja alarmi nimi, näiteks `FIRING · mtamm · MasinEiVasta`;
- sisus on iga grupi alarmi `summary` eraldi real.

Lisa silt faili `konf/config/prometheus.yml` ja mall samasse `discord_configs` kirjesse.

??? tip "Vihje"
    `external_labels` on `global` all samal taandel kui `scrape_interval` ja selle all on sildid kujul `nimi: väärtus`. Grupi ühine silt on mallis `{{ .CommonLabels.<nimi> }}`. Suurtähed annab funktsioon `toUpper`: `{{ .Status | toUpper }}`. Annotatsioon on ühe alarmi sees kujul `{{ .Annotations.summary }}`. Reavahetus mallis on `{{ "\n" }}`. Mall on YAML-is ühekordsetes jutumärkides.

Kui teade on kanalis, kontrolli, et pealkirjas on sinu nimi.

??? success "Oodatav tulemus"
    ```text
    mtamm
    FIRING · mtamm · MasinEiVasta
    192.168.35.13:9100: Prometheus ei saa mõõdikuid kätte
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

??? warning "Kui alarm on Firing, aga Discordi teadet ei tule"
    Vaata Alertmanageri logist, mis teate saatmisel juhtus:

    ```bash
    ssh proxmox1 "cd ~/prometheus && docker compose logs alertmanager | grep -i discord | tail -5"
    ```

    | Logis | Põhjus | Paranda |
    |---|---|---|
    | `read webhook_url_file` või `no such file` | faili `~/prometheus/saladus/discord_url` ei ole | loo fail ploki „Kui faili `discord_url` pole“ järgi |
    | `401` või `404` | aadress on vale või poolik | kopeeri aadress uuesti tervikuna |
    | `timeout` või `connection refused` | `proxmox1` ei pääse internetti pordil 443 | kontrolli `ssh proxmox1 "curl -sI https://discord.com"` |
    | Discordi kohta ridu pole | alarm ei jõudnud Alertmanagerini | ava `http://<proxmox1-IP>:9093`: kui alarmi pole, kontrolli plokki `alerting` osast 5.3 |

    Pärast faili või seadete parandamist käivita Alertmanager uuesti: `ssh proxmox1 "cd ~/prometheus && docker compose restart alertmanager"`.

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

??? question "Miks graafik tõusis kohe, aga alarm tuli alles poolteist minutit hiljem?"
    Mõtle, mis on päringus `[1m]` ja mis on reeglis `for: 1m`.

    ??? success "Vastus"
        `rate(...[1m])` on viimase minuti keskmine, seega jõuab väärtus üle 80% alles umbes poole minuti jooksul. Seejärel peab tingimus kehtima veel minuti (`for: 1m`), enne kui alarm on Firing.

## Osa 7 · Töölaud edasi

Osas 3 tegid töölaua veebiliideses. Nüüd muudad selle tööriistaks, mida kasutatakse ka valves: töölaud tuleb failist, alarmid on graafikul näha, värv näitab sama läve mis reegel ja teatest saab ühe klikiga õigele graafikule.

### 7.1 Töölaud failist

Veebiliideses tehtud töölaud on Grafana andmebaasis. Kui andmeköide kaob, kaob ka töölaud. Grafana oskab töölauad lugeda failidest samamoodi nagu andmeallika ([Provisioning, Dashboards](https://grafana.com/docs/grafana/latest/administration/provisioning/#dashboards)). Selleks on vaja kahte asja: **pakkuja** (provider) faili, mis ütleb, millisest kaustast töölauad loetakse, ja kausta, kus on töölaudade JSON-failid.

???+ example "Fail `konf/grafana-toolauad/toolauad.yml`"
    ```yaml
    apiVersion: 1

    providers:
      - name: kursus
        folder: IT-24
        type: file
        options:
          path: /etc/grafana/toolauad
    ```

Lisa teenusele `grafana` kaks ühendust, mõlemad ainult lugemiseks:

- kaust `./grafana-toolauad` on konteineris kaustas `/etc/grafana/provisioning/dashboards`;
- kaust `./toolauad` on konteineris kaustas `/etc/grafana/toolauad`.

??? example "Näidislahendus: teenuse grafana ühendused"
    ```yaml
        volumes:
          - ./grafana:/etc/grafana/provisioning/datasources:ro
          - ./grafana-toolauad:/etc/grafana/provisioning/dashboards:ro
          - ./toolauad:/etc/grafana/toolauad:ro
          - grafana-data:/var/lib/grafana
    ```

Failis `konf/toolaud.json` on osa 3 töölaud. Veebiliideses salvestatud töölaual on sama `uid`, seega muuda failis kaks välja, et failist tulev töölaud oleks eraldi: `"uid": "n6-kood"` ja `"title": "N6 koodist"`. Kopeeri failid ja käivita Grafana uuesti:

```bash
ssh proxmox1 "mkdir -p ~/prometheus/toolauad"
scp -r konf/grafana-toolauad proxmox1:prometheus/
scp konf/toolaud.json proxmox1:prometheus/toolauad/
scp konf/compose.yaml proxmox1:prometheus/
ssh proxmox1 "cd ~/prometheus && docker compose up -d grafana"
```

??? success "Oodatav tulemus"
    **Dashboards** all on kaust **IT-24** ja selles töölaud **N6 koodist**. Töölaua ülaosas on märge, et see on failist ja muudatusi veebiliideses salvestada ei saa.

??? question "Kas töölaud jääb alles, kui Grafana andmeköide kustutada?"
    Proovi: `ssh proxmox1 "cd ~/prometheus && docker compose rm -sf grafana && docker volume rm prometheus_grafana-data && docker compose up -d grafana"`. Grafana küsib uuesti parooli `admin` ja `admin`.

    ??? success "Vastus"
        Jääb. Andmeallikas ja töölaud tulevad failidest, mis on repositooriumis. Kadus ainult parool ja veebiliideses tehtud töölaud **N6**. Nii hoitakse töölaudu töökohtades: fail on Gitis ja iga Grafana saab sama töölaua.

Järgmised muudatused teed failis `konf/toolaud.json`. Kõige lihtsam on teha muudatus veebiliideses töölaual **N6**, eksportida see uuesti nagu osas 3.4, muuta `uid` ja `title` ning kopeerida fail `proxmox1`-sse. Grafana loeb kausta uuesti iga 10 sekundi järel.

### 7.2 Alarmid graafikul

Prometheus hoiab iga kehtiva alarmi kohta aegrida `ALERTS`. Grafana **annotatsioon** (annotation) märgib graafikule ajavahemiku, kus päring tagastab tulemuse ([Annotate visualizations](https://grafana.com/docs/grafana/latest/dashboards/build-dashboards/annotate-visualizations/)).

Ava töölaud **N6**, **Edit → Settings → Annotations → New annotation**:

1. **Name**: `Alarmid`, **Data source**: **Prometheus**, värv punane;
2. päring: `ALERTS{alertstate="firing", instance="$instance"}`;
3. **Title**: `{{alertname}}`, salvesta.

Tekita koormuskatse uuesti nagu osas 6.2 ja vaata protsessori paneeli.

??? question "Kui palju hiljem algab punane ala võrreldes graafiku tõusuga?"
    Võrdle punase ala algust kohaga, kus kõver ületab 80%.

    ??? success "Vastus"
        Umbes minut, see on reegli `for: 1m`. Graafik ise tõuseb üle 80% umbes poole minuti jooksul pärast katse algust, sest `rate(...[1m])` on minuti keskmine. Punane ala lõpeb mõni sekund pärast seda, kui kõver langeb alla 80%.

### 7.3 Värv näitab sama läve mis reegel

Lisa töölauale paneel visualiseeringuga **Stat** ja protsessori kasutuse päringuga. Paneeli seadetes ([Thresholds](https://grafana.com/docs/grafana/latest/panels-visualizations/configure-thresholds/)):

- **Thresholds**: põhivärv roheline, `70` kollane, `80` punane;
- **Stat styles → Color mode**: **Background solid**.

Punane läbi on sama mis reeglis `ProtsessorKoormatud`. Kui keegi vaatab töölauda, näeb ta sama piiri, mille järgi alarm tuleb.

??? success "Oodatav tulemus"
    Tavaolukorras on paneel roheline. Koormuskatse ajal muutub see punaseks umbes samal ajal, kui reegel läheb olekusse Pending.

### 7.4 Paneel iga masina kohta

Kui masinaid on palju, tahab valvaja näha kõiki korraga. Grafana oskab paneeli korrata iga muutuja väärtuse kohta ([Repeating panels](https://grafana.com/docs/grafana/latest/panels-visualizations/configure-panel-options/#configure-repeating-panels)).

1. Muutuja `instance` seadetes lülita sisse **Multi-value** ja **Include All option**.
2. Stat-paneeli seadetes **Panel options → Repeat options**: **Repeat by variable** `instance`, suund **Horizontal**.
3. Vali rippmenüüst **All**.

??? success "Oodatav tulemus"
    Stat-paneele on kaks, kummagi masina kohta üks, ja pealkirjas on masina aadress. Kui Prometheusesse lisandub masin, tekib uus paneel ise.

### 7.5 Teatest graafikule

Valvaja saab teate Discordi ja tahab kohe näha selle masina graafikuid. Lisa reeglile `ProtsessorKoormatud` annotatsioon `dashboard`, mis on töölaua aadress koos õige masinaga. Reegli mallis on masina aadress `{{ $labels.instance }}` ([Templating](https://prometheus.io/docs/prometheus/latest/configuration/alerting_rules/#templating)):

```yaml
        annotations:
          summary: "{{ $labels.instance }}: protsessori kasutus {{ $value | printf \"%.0f\" }}%"
          dashboard: "http://<proxmox1-IP>:3000/d/n6-kood?var-instance={{ $labels.instance }}"
```

Lisa Alertmanageri malli `message` sisse iga alarmi juurde ka see link: `{{ .Annotations.dashboard }}`. Kopeeri failid, taaskäivita Prometheus ja Alertmanager ning korda koormuskatset.

??? example "Näidislahendus: message koos lingiga"
    ```yaml
            message: '{{ range .Alerts }}{{ .Annotations.summary }}{{ "\n" }}{{ .Annotations.dashboard }}{{ "\n" }}{{ end }}'
    ```

??? success "Oodatav tulemus"
    Discordi teates on link. Klikk avab töölaua, kus rippmenüüs on juba õige masin.

## Osa 8 · Kokkuvõte

Vasta README jaotises **Osa 8**:

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
    - [ ] Töölaud **N6 koodist** tuleb failist ja sellel on alarmide annotatsioon, Stat-paneel lävenditega ja korduv paneel.
    - [ ] Discordi teates on link töölauale.

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

??? example "5 · Zabbixi andmebaas Grafanas"
    Grafana ei loe ainult Prometheust. PostgreSQL-i andmeallikaga saab teha graafiku otse SQL-päringust ([PostgreSQL data source](https://grafana.com/docs/grafana/latest/datasources/postgres/)). Siin joonistad N4 Zabbixi kettaruumi andmed samale töölauale Prometheuse andmetega.

    Zabbixi andmebaas töötab teises Compose'i projektis (`~/zabbix`) ja selle port ei ole masinast väljas lahti. Grafana pääseb sinna, kui see on ühendatud ka Zabbixi projekti võrku `zabbix_default`.

    1. Käivita Zabbix: `ssh proxmox1 "cd ~/zabbix && docker compose start"`. Kontrolli mälu nagu kodutöös 2.
    2. Tee Grafanale ainult lugemise õigusega andmebaasi kasutaja. Vali oma parool:
        ```bash
        ssh proxmox1 "cd ~/zabbix && docker compose exec -T postgres psql -U zabbix -c \"CREATE ROLE grafana LOGIN PASSWORD '<parool>'; GRANT pg_read_all_data TO grafana;\""
        ```
    3. Lisa failis `konf/compose.yaml` teenusele `grafana` teine võrk ja kirjelda see faili lõpus. Kui Zabbixi projekti `proxmox1`-s pole, ei käivitu Grafana enam: siis eemalda need read.
        ```yaml
          grafana:
            networks: [default, zabbix]

        networks:
          zabbix:
            name: zabbix_default
            external: true
        ```
    4. Kopeeri `compose.yaml` ja käivita `docker compose up -d grafana`. Grafanas **Connections → Data sources → Add → PostgreSQL**: **Host URL** `postgres:5432`, **Database** `zabbix`, **Username** `grafana`, parool, **TLS/SSL Mode** `disable`, **Save & test**.
    5. Lisa töölauale paneel andmeallikaga PostgreSQL, režiim **Code**, vorming **Time series** ([Query editor](https://grafana.com/docs/grafana/latest/datasources/postgres/query-editor/)):
        ```sql
        SELECT to_timestamp(h.clock) AS time, h.value, hs.host AS metric
        FROM history h
        JOIN items i ON i.itemid = h.itemid
        JOIN hosts hs ON hs.hostid = i.hostid
        WHERE i.key_ = 'vfs.fs.size[/,pfree]' AND $__unixEpochFilter(h.clock)
        ORDER BY 1
        ```

    Võrdle seda Prometheuse juurfailisüsteemi paneeliga. Kas väärtused on samad? Kumb päring on lihtsam kirjutada ja miks hoiab Zabbix andmeid SQL-tabelis, Prometheus aga aegridade andmebaasis?

