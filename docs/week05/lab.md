---
tags:
  - Monitooring
  - Ansible
  - Praktikum
---

# Praktikum: server küsib mõõdikuid

Täna paigaldad node_exporteri kõigepealt käsitsi `proxmox2`-sse ja seejärel playbook'iga mõlemasse jälgitavasse masinasse, käivitad `proxmox1`-s Prometheuse ja leiad PromQL-iga vastuse küsimusele: millises masinas on ressursse kõige vähem alles?

**Edenemine:** laboritahvel <http://192.168.125.187:8092/> (VPN-iga).

??? abstract "Õpiväljundid"
    Pärast loengut ja praktikumi oskad:

    1. paigaldada node_exporteri ametlikust väljalaskest systemd teenusena ja kontrollida aadressi `/metrics`;
    2. kirjutada playbook'i, mis paigaldab node_exporteri mitmesse masinasse ja annab teisel käivitusel `changed=0`;
    3. käivitada Prometheuse Docker Compose'iga, kontrollida **Targets**-lehelt, et target'id on olekus `UP`, ja leida seal viimase kogumise viga, kui target on `DOWN`;
    4. koostada ja kohandada PromQL-i päringuid saadaval oleva mälu, failisüsteemi vaba ruumi ja protsessori kasutuse uurimiseks ning selgitada tulemuste ühikuid ja ulatust;
    5. selgitada, kes avab ühenduse ja milline komponent tagastab väärtused Zabbixi agendi ja Prometheuse puhul.

<figure markdown="span">
  ![Sinu arvutist paigaldab Ansible SSH kaudu node_exporteri proxmox2 ja proxmox3 masinasse, kus port 9100 on lahti; proxmox1 Prometheus kogub neilt iga 15 sekundi järel; brauser avab Prometheuse pordil 9090](../images/n05_topoloogia.svg)
  <figcaption>Joonis 5.9. Praktikumi topoloogia: masinad, pordid ja ühendused (Talvik, 2026).</figcaption>
</figure>

Rida **Ennusta** tähendab, et enne käsku mõtled läbi, mis juhtub. Ennustuse kirjutad README-sse. Vastus on kokkuvolditud plokis.

## Osa 1 · Repositoorium ja mälu

Töötad neljas kohas. Kasutatavad versioonid on node_exporter 1.12.1 ja Prometheus 3.15.1, jälgitavates masinates on AlmaLinux 9.

??? note "Tabel 5.3. Kus mida teed"
    | Koht | Mis seal töötab | Mida seal teed | Eeltingimus |
    |---|---|---|---|
    | Sinu arvuti | repositoorium, Ansible | kirjutad playbook'i ja seaded, käivitad `ansible-playbook`, salvestad tõendid | Ansible ja kollektsioon `ansible.posix` |
    | `proxmox1` | Prometheus (Docker Compose) | käivitad Prometheuse | Docker ja Docker Compose töötavad |
    | `proxmox2`, `proxmox3` | node_exporter (systemd teenus) | paigaldad node_exporteri, `proxmox2`-s esmalt käsitsi | AlmaLinux 9, tulemüür `firewalld` töötab |
    | Brauser | Prometheuse veebiliides | vaatad Targets-lehte ja kirjutad päringuid | koolis laborivõrk, kodust VPN |

Kontrolli eeltingimusi oma arvutist:

```bash
ansible-galaxy collection list ansible.posix
ssh proxmox1 "docker compose version"
for h in proxmox2 proxmox3; do ssh $h "sudo firewall-cmd --state; sudo firewall-cmd --get-default-zone"; done
```

??? success "Oodatav tulemus"
    Kollektsiooni `ansible.posix` rida, Docker Compose'i versioon ning mõlema masina kohta `running` ja vaiketsoon (tavaliselt `public`). Kui kollektsioon puudub, paigalda see: `ansible-galaxy collection install ansible.posix`.

Prometheuse veebiliides ja API on autentimiseta: igaüks, kes pordini 9090 jõuab, näeb kõiki andmeid. Ära ava neid internetti. Praktikumis kasutad neid ainult laborivõrgus, kodust VPN-iga.

Ava Classroom 50 link ([Praktikum 5 - Server küsib mõõdikuid](https://classroom50.org/hkhk-monitoring/it24-monitooring/assignments)) ja klooni oma repositoorium. Käivita käsud oma arvutis:

```bash
git clone <sinu-repo-URL>
cd <repo-kaust>
ls
```

??? success "Oodatav tulemus"
    ```text
    README.md  konf  logid
    ```

    README-sse kirjutad ennustused ja vastused. Playbook ja Prometheuse seaded lähevad kausta `konf/`, tõendid kausta `logid/`.

Prometheus vajab `proxmox1`-s umbes 300 MB mälu. Kui seal töötab N2 Zabbix, peata see. Vaata enne, mis selles projektis töötab:

```bash
ssh proxmox1 "test -d ~/zabbix && cd ~/zabbix && docker compose ps"
```

Kui väljundis on Zabbixi konteinerid, peata need ja kontrolli mälu.

!!! warning "Kasuta `stop`, mitte `docker compose down -v`"
    `stop` jätab konteinerid ja andmed alles, hiljem saad Zabbixi käsuga `docker compose start` tagasi. Võti `-v` kustutaks ka andmeköited ja Zabbixi puhul kaoksid kõik hostid ja ajalugu.

```bash
ssh proxmox1 "cd ~/zabbix && docker compose stop"
ssh proxmox1 "free -h"
```

??? success "Oodatav tulemus"
    Kolm rida `Stopped`. Real `Mem:` on veerus `available` vähemalt 1 GB. Kui kausta `~/zabbix` ei olnud, jäta peatamine vahele.

Pane kirja kolme masina IP-aadressid. Neid on vaja Prometheuse seadetes:

```bash
for h in proxmox1 proxmox2 proxmox3; do echo "$h: $(ssh $h hostname -I)"; done
```

Iga masina juures võib olla mitu aadressi. Vali laborivõrgu IPv4-aadress (näiteks `192.168.35.12`), mitte Dockeri sisevõrgu (`172.…`) ega loopback-aadress (`127.…`).

Koormuskatseks osas 6 on vaja programmi `stress-ng`, mis on EPEL-i hoidlas. Paigalda see nüüd `proxmox2`-sse. Kui see on N3-st juba olemas, ei muuda käsk midagi:

```bash
ssh proxmox2 "sudo dnf install -y epel-release && sudo dnf install -y stress-ng && stress-ng --version"
```

## Osa 2 · node_exporter käsitsi proxmox2-s

Enne playbook'i teed paigalduse ühes masinas käsitsi, et näha iga sammu tulemust. node_exporter on üks programmifail. Selle ametlikud väljalasked on GitHubis lehel [node_exporter releases](https://github.com/prometheus/node_exporter/releases). Laadi alla versioon 1.12.1 ja kontrolli kontrollsummat:

```bash
ssh proxmox2
cd /tmp
V=1.12.1
curl -LO https://github.com/prometheus/node_exporter/releases/download/v$V/node_exporter-$V.linux-amd64.tar.gz
curl -LO https://github.com/prometheus/node_exporter/releases/download/v$V/sha256sums.txt
sha256sum --check --ignore-missing sha256sums.txt
```

??? success "Oodatav tulemus"
    `node_exporter-1.12.1.linux-amd64.tar.gz: OK`. Kontrollsumma kinnitab, et allalaaditud fail vastab samal väljalaskelehel avaldatud summale. Allika usaldusväärsust see ei asenda: summa ja fail tulevad samast kohast.

Paki fail lahti, paigalda programm kausta `/usr/local/bin` ja loo talle oma süsteemikasutaja. Teenus ei tööta `root`-ina, sest see ainult loeb masina näite:

```bash
tar xzf node_exporter-$V.linux-amd64.tar.gz
sudo install -m 0755 node_exporter-$V.linux-amd64/node_exporter /usr/local/bin/
sudo useradd --system --no-create-home --shell /sbin/nologin node_exporter
node_exporter --version
```

`install` loob uue faili, seega saab see kausta `/usr/local/bin` SELinuxi sildi. Kui teisaldad faili käsuga `mv`, jääb alles kausta `/tmp` silt ja systemd ei saa programmi käivitada.

systemd käivitab programmi teenusena, kui sellel on unit-fail. Loo fail `/etc/systemd/system/node_exporter.service` (`sudo nano`):

```ini
[Unit]
Description=Prometheus node_exporter
After=network-online.target

[Service]
User=node_exporter
ExecStart=/usr/local/bin/node_exporter
Restart=on-failure

[Install]
WantedBy=multi-user.target
```

Käivita teenus ja kontrolli, et see vastab:

```bash
sudo systemctl daemon-reload
sudo systemctl enable --now node_exporter
systemctl is-active node_exporter
curl -s localhost:9100/metrics | grep '^node_memory_MemAvailable_bytes'
```

??? success "Oodatav tulemus"
    `active` ja rida `node_memory_MemAvailable_bytes 1.47e+09` (sinu arv on teine). See on sama väärtus baitides, mida `free -b` näitab veerus `available`.

??? warning "Kui `systemctl status node_exporter` näitab `status=203/EXEC`"
    systemd ei saa programmi käivitada. Kontrolli SELinuxi silti: `ls -Z /usr/local/bin/node_exporter`. Kui seal on `user_tmp_t`, paranda: `sudo restorecon -v /usr/local/bin/node_exporter`.

**Ennusta:** kas `proxmox1` saab praegu `proxmox2` pordist 9100 mõõdikuid lugeda? Kirjuta ennustus README jaotisse **Osa 2** ja kontrolli `proxmox1`-st. Bash avab TCP-ühenduse aadressile `/dev/tcp/<IP>/<port>`:

```bash
exit
ssh proxmox1 "timeout 3 bash -c '</dev/tcp/<proxmox2-IP>/9100' && echo lahti || echo kinni"
```

??? success "Oodatav tulemus"
    `kinni`: `proxmox1`-st ei õnnestunud TCP-ühendus. Põhjus võib olla tulemüür, vale IP-aadress või teenus, mis ei kuula. node_exporter kuulab (`curl localhost:9100` töötas), seega kontrolli tulemüüri:

    ```bash
    ssh proxmox2 "sudo firewall-cmd --state; sudo firewall-cmd --list-ports"
    ```

    `running` ja port 9100 nimekirjas puudub: tulemüür ei luba seda. Pull-mudelis alustab ühendust server, seega peab port olema lahti jälgitavas masinas. Ava port vaiketsoonis ja kontrolli uuesti:

    ```bash
    ssh proxmox2 "sudo firewall-cmd --permanent --add-port=9100/tcp && sudo firewall-cmd --reload"
    ```

    Nüüd annab kontroll `lahti`. Kui kontroll andis `lahti` juba enne pordi avamist, ei tööta `proxmox2`-s tulemüür.

## Osa 3 · Mida /metrics sisaldab

node_exporter avaldab sadu mõõdikuid. Vaata kolme, mida kasutad hiljem PromQL-is, ja salvesta need tõendiks:

```bash
ssh proxmox2 "curl -fsS localhost:9100/metrics" | grep -E '^node_(cpu_seconds_total|memory_MemAvailable_bytes|memory_MemTotal_bytes|filesystem_avail_bytes)' > logid/n5-metrics.txt
cat logid/n5-metrics.txt
```

**Ennusta:** mitu rida on failis mõõdikul `node_cpu_seconds_total`? Vihje: `ssh proxmox2 nproc`.

```bash
grep -c '^node_cpu_seconds_total' logid/n5-metrics.txt
```

??? success "Oodatav tulemus"
    Loogiliste protsessorite arv korda kaheksa. Selles masinas on iga protsessori kohta kaheksa `mode` väärtust (`idle`, `user`, `system`, `iowait`, `irq`, `softirq`, `nice`, `steal`). Mõõdiku nimi koos siltide väärtustega määrab ühe aegrea.

Leia `proxmox2` väljundist üks gauge ja üks counter koos nende `# TYPE` reaga:

```bash
ssh proxmox2 "curl -fsS localhost:9100/metrics" | grep -E '^# TYPE node_(memory_MemAvailable_bytes|cpu_seconds_total) '
```

Kirjuta README jaotisse **Osa 3** kummagi nimi, tüüp ja ühik. Kuidas tunned counteri ära ka ilma `# TYPE` reata?

## Osa 4 · Sama playbook'iga kahes masinas

`proxmox3` vajab samu samme. Kirjuta need playbook'iks `konf/node_exporter.yml`, mis paigaldab node_exporteri mõlemasse masinasse.

**Ennusta:** milline osa seadistusest on mõlemas masinas sama ja mis võib masinati erineda? Kirjuta vastus README jaotisse **Osa 4**.

**Nõuded (`konf/node_exporter.yml`):**

- laadib alla node_exporteri 1.12.1 väljalaske ja kontrollib kontrollsummat;
- paigaldab programmi `/usr/local/bin/node_exporter`;
- loob süsteemikasutaja `node_exporter`;
- kirjutab unit-faili `/etc/systemd/system/node_exporter.service`, mille sisu on täpselt sama mis osas 2 käsitsi loodud failis, ja taaskäivitab teenuse **ainult siis, kui fail muutus** (handler);
- avab tulemüüri vaiketsoonis pordi `9100/tcp` nii, et see kehtib kohe ja jääb alles ka pärast taaskäivitust (`permanent` ja `immediate`);
- teenus töötab ja käivitub koos masinaga;
- teine käivitus annab `changed=0`, kui esimene käivitus õnnestus, failid kaustas `/tmp` on alles ja masinaid pole vahepeal käsitsi muudetud.

??? note "Tabel 5.4. Playbook'i moodulid"
    | Moodul | Mida teeb | Parameetrid selles playbook'is |
    |---|---|---|
    | [`ansible.builtin.get_url`](https://docs.ansible.com/ansible/latest/collections/ansible/builtin/get_url_module.html) | laadib faili alla ja kontrollib kontrollsummat | `url`, `dest`, `checksum` |
    | [`ansible.builtin.unarchive`](https://docs.ansible.com/ansible/latest/collections/ansible/builtin/unarchive_module.html) | pakib arhiivi lahti | `src`, `dest`, `remote_src`, `creates` |
    | [`ansible.builtin.copy`](https://docs.ansible.com/ansible/latest/collections/ansible/builtin/copy_module.html) | kopeerib faili või kirjutab sisu faili | `src`, `dest`, `remote_src`, `mode`, `content` |
    | [`ansible.builtin.user`](https://docs.ansible.com/ansible/latest/collections/ansible/builtin/user_module.html) | loob kasutaja | `name`, `system`, `shell`, `create_home` |
    | [`ansible.builtin.systemd_service`](https://docs.ansible.com/ansible/latest/collections/ansible/builtin/systemd_service_module.html) | käivitab teenuse, loeb unit-failid uuesti | `name`, `state`, `enabled`, `daemon_reload` |
    | [`ansible.posix.firewalld`](https://docs.ansible.com/ansible/latest/collections/ansible/posix/firewalld_module.html) | avab pordi firewalld-s | `port`, `permanent`, `immediate`, `state` |

Enne kirjutamist uuri allalaadimise moodulit:

```bash
ansible-doc ansible.builtin.get_url
```

Leia parameetri `checksum` juurest, mis kujul saab kontrollsumma anda ja kas selle võib võtta failist veebiaadressil. Kirjuta vastus README jaotisse **Osa 4**.

??? tip "Vihje: playbook'i ülesehitus"
    ```yaml
    - name: node_exporter jälgitavatesse masinatesse
      hosts: all
      become: true
      vars:
        ne_version: "1.12.1"
        ne_name: "node_exporter-{{ ne_version }}.linux-amd64"
        ne_url: "https://github.com/prometheus/node_exporter/releases/download/v{{ ne_version }}"
      tasks:
        - name: Väljalase alla koos kontrollsummaga
          ansible.builtin.get_url:
            url: "{{ ne_url }}/{{ ne_name }}.tar.gz"
            dest: "/tmp/{{ ne_name }}.tar.gz"
            checksum: "sha256:{{ ne_url }}/sha256sums.txt"

        - name: Arhiiv lahti
          ansible.builtin.unarchive:
            src: "/tmp/{{ ne_name }}.tar.gz"
            dest: /tmp
            remote_src: true
            creates: "/tmp/{{ ne_name }}/node_exporter"

        - name: Programm kausta /usr/local/bin
          ansible.builtin.copy:
            src: "/tmp/{{ ne_name }}/node_exporter"
            dest: /usr/local/bin/node_exporter
            remote_src: true
            mode: "0755"

        - name: Unit-fail, sama sisu mis osas 2
          ansible.builtin.copy:
            dest: /etc/systemd/system/node_exporter.service
            mode: "0644"
            content: |
              [Unit]
              Description=Prometheus node_exporter
              After=network-online.target

              [Service]
              User=node_exporter
              ExecStart=/usr/local/bin/node_exporter
              Restart=on-failure

              [Install]
              WantedBy=multi-user.target
          notify: node_exporter uuesti

        # ... kasutaja, teenus, tulemüür

      handlers:
        - name: node_exporter uuesti
          ansible.builtin.systemd_service:
            name: node_exporter
            state: restarted
            daemon_reload: true
    ```

Käivita playbook oma arvutis kaks korda. Teise käivituse väljund läheb tõendiks:

```bash
ansible-playbook -i proxmox2,proxmox3, konf/node_exporter.yml
ansible-playbook -i proxmox2,proxmox3, konf/node_exporter.yml | tee logid/n5-teine-kaivitus.txt
```

??? success "Oodatav tulemus"
    Esimesel käivitusel on `proxmox3` all mitu `changed` ülesannet. `proxmox2`-s tegid osa samme käsitsi, seal on muudatusi vähem. Kui unit-faili sisu erineb käsitsi failist kas või ühe tühiku poolest, on ka `proxmox2`-s unit-fail `changed`. Teisel käivitusel on mõlemal real `changed=0` ja `failed=0`.

??? warning "Kui teisel käivitusel on `changed=1`"
    Tavaliselt on põhjus `command` või `shell` ülesanne, mis käivitub iga kord. Kasuta mooduleid tabelist 5.4. Kui muutub unit-faili ülesanne, kontrolli, et `content:` ei sõltu ajast ega muutujast, mis iga kord muutub.

Kontrolli, et mõlemad masinad vastavad:

```bash
for h in proxmox2 proxmox3; do ssh $h "systemctl is-active node_exporter; curl -fsS localhost:9100/metrics | grep -c '^node_'"; done
```

## Osa 5 · Prometheus proxmox1-s

Prometheus töötab `proxmox1`-s konteineris. Seaded on failis `prometheus.yml`: seal on kirjas, kui tihti ja keda küsida. Loo oma arvutis repositooriumis fail `konf/prometheus.yml`. Asenda IP-aadressid oma masinate omadega:

```yaml
global:
  scrape_interval: 15s

scrape_configs:
  - job_name: prometheus
    static_configs:
      - targets: ["localhost:9090"]

  - job_name: node
    static_configs:
      - targets: ["<proxmox2-IP>:9100", "<proxmox3-IP>:9100"]
```

Loo samasse kausta `konf/compose.yaml`. Image'i silt on kindel versioon, et sama fail annaks ka hiljem sama tulemuse ([prom/prometheus Docker Hubis](https://hub.docker.com/r/prom/prometheus/tags)). Konteinerisse ühendatakse kaust `config/`, mitte üksik fail: kui fail hiljem uuega asendatakse, näeb konteiner kausta kaudu uut faili, üksiku faili ühendus võib jääda vana faili külge:

```yaml
services:
  prometheus:
    image: prom/prometheus:v3.15.1
    ports:
      - "9090:9090"
    volumes:
      - ./config:/etc/prometheus:ro
      - prometheus-data:/prometheus
    restart: unless-stopped

volumes:
  prometheus-data:
```

Kopeeri failid `proxmox1`-sse ja käivita. `prometheus.yml` läheb kausta `~/prometheus/config/`:

```bash
ssh proxmox1 "mkdir -p ~/prometheus/config"
scp konf/compose.yaml proxmox1:prometheus/
scp konf/prometheus.yml proxmox1:prometheus/config/
ssh proxmox1 "cd ~/prometheus && docker compose up -d && docker compose ps"
```

??? success "Oodatav tulemus"
    Konteiner `prometheus-prometheus-1` on olekus `Up`. Ava brauseris `http://<proxmox1-IP>:9090`.

??? warning "Kui konteiner taaskäivitub ja logis on `permission denied` või `no such file` faili `prometheus.yml` kohta"
    Vaata logi: `ssh proxmox1 "cd ~/prometheus && docker compose logs prometheus | tail"`. Kontrolli, et fail on kaustas `~/prometheus/config/` ja on loetav (`ls -l ~/prometheus/config`): Prometheus töötab konteineris kasutajana `nobody`. Kui Docker kasutab SELinuxi, lisa kaustale märge `:ro,Z` (`./config:/etc/prometheus:ro,Z`) ja käivita uuesti `docker compose up -d`.

Ava veebiliideses **Status → Target health**. Seal on kolm target'it: Prometheus ise ja kaks node_exporterit. Leia mõlema node_exporteri juurest olek, **Last scrape** ja **Error**. Kirjuta README jaotisse **Osa 5**, mis kinnitab, et Prometheus kogub mõlemast masinast.

??? success "Oodatav tulemus"
    Mõlemad on olekus `UP`, **Last scrape** on alla 15 sekundi tagasi ja **Error** on tühi. Kui mõni on `DOWN`, vaata **Error** veergu ja loengu 4. peatüki samme.

Salvesta Prometheuse vaade tõendiks. Failis on laborimasinate IP-aadressid, muud tundlikku seal pole:

```bash
ssh proxmox1 "curl -fsS localhost:9090/api/v1/targets" > logid/n5-targets.json
grep -o '"health":"[a-z]*"' logid/n5-targets.json
```

??? success "Oodatav tulemus"
    Kolm rida `"health":"up"`: Prometheus ise ja kaks node_exporterit. Failis on iga target'i juures ka `lastScrape`.

### 5.1 Kogumisvea katse

Nüüd tekitad kogumisvea meelega ja leiad selle Prometheusest.

**Ennusta:** mis olek, **Error** ja `up` väärtus on `proxmox3` target'il, kui peatad seal node_exporteri? Kirjuta ennustus README jaotisse **Osa 5**.

Peata `proxmox3`-s node_exporter:

```bash
ssh proxmox3 "sudo systemctl stop node_exporter"
```

Oota vähemalt 15 sekundit, et Prometheus jõuaks järgmise kogumiseni. Värskenda Targets-lehte ja leia `proxmox3` juurest **Error** väli. Salvesta tõend, kui target on `DOWN`:

```bash
ssh proxmox1 "curl -fsS localhost:9090/api/v1/targets" > logid/n5-viga.json
```

??? success "Oodatav tulemus"
    `proxmox3` on `DOWN` ja **Error** on näiteks `Get "http://192.168.35.13:9100/metrics": dial tcp 192.168.35.13:9100: connect: connection refused`. Päring `up` annab `proxmox3` kohta 0. Failis `logid/n5-viga.json` on selle target'i juures `"health":"down"` ja `lastError`.

Taasta soovitud olek playbook'iga. Playbook nõuab, et teenus on olekus `started`, seega käivitab see node_exporteri uuesti:

```bash
ansible-playbook -i proxmox2,proxmox3, konf/node_exporter.yml
```

Kontrolli Targets-lehelt, et mõlemad on jälle `UP`. Kirjuta README jaotisse **Osa 5**, milline **Error** tekst oli ja mida see ütles.

## Osa 6 · Kolm küsimust PromQL-iga

Ava veebiliideses **Query**. Kirjuta päring, vajuta **Execute** ja vaata vahekaarte **Table** ja **Graph**. Iga küsimus lisab päringukeelest ühe osa, selgitus on loengu 5. peatükis.

### 6.1 Kui palju mälu on masinas saadaval?

Vali mõõdik. Kirjuta ainult mõõdiku nimi:

```text
node_memory_MemAvailable_bytes
```

Miks tagastab üks mõõdiku nimi mitu tulemust? Kirjuta vastus README jaotisse **Osa 6**.

Piira tulemus ühe masinaga:

```text
node_memory_MemAvailable_bytes{instance="<proxmox2-IP>:9100"}
```

Kontrolli ühikut. Mis ühikus on väärtus ja kui palju on see gigabaitides?

**Ennusta:** masinas on ka mõõdik `node_memory_MemFree_bytes`. Kas `MemAvailable` on suurem või väiksem kui `MemFree`? Kontrolli mõlemat ja kirjuta README jaotisse **Osa 6**, mida nende erinevus näitab.

Arvuta osakaal. Muuda päringut nii, et see näitab iga masina kohta saadaval mälu protsentides kogu mälust (`node_memory_MemTotal_bytes`). Kirjuta päring ja tulemus iga masina kohta README jaotisse **Osa 6**.

??? success "Oodatav tulemus"
    Mõõdiku nimi annab rea iga target'i kohta, sest silt `instance` on erinev. Väärtus on baitides, näiteks `1.47e+09` on umbes 1,4 GiB. `MemAvailable` on suurem. `MemFree` jätab välja puhvri- ja vahemälu, mille tuum vajadusel vabastab. `MemAvailable` on tuuma hinnang mälule, mille uued programmid saavad ilma saalimiseta, mitte garantii igale programmile. Osakaalu päring annab iga masina kohta arvu 0 ja 100 vahel.

### 6.2 Millises masinas on juurfailisüsteemis kõige vähem vaba ruumi?

Selle päringu koostad ise. Vaja on kahte mõõdikut: `node_filesystem_avail_bytes` ja `node_filesystem_size_bytes`. Kirjuta kõigepealt ainult esimese nimi ja vaata, mitu rida tuleb iga masina kohta.

Kirjuta README jaotisse **Osa 6**:

1. päring, mis annab iga masina juurfailisüsteemi (`/`) vaba ruumi protsentides;
2. kummas masinas on vaba ruumi vähem ja kui palju;
3. mida sellest järeldad ja mille põhjal saaksid öelda, et see on probleem.

??? tip "Vihje"
    Iga failisüsteemi kohta on eraldi rida, silt `mountpoint` ütleb, mis failisüsteem see on. Sildifilter käib mõlema mõõdiku juurde.

### 6.3 Kuidas muutub protsessori kasutus koormuskatse ajal?

Protsessori kasutuse päring koosneb neljast osast. Käivita need ükshaaval ja kirjuta README jaotisse **Osa 6**, mida iga osa tulemus näitab ja mis on selle ühik:

```text
node_cpu_seconds_total{mode="idle"}
rate(node_cpu_seconds_total{mode="idle"}[1m])
avg by (instance) (rate(node_cpu_seconds_total{mode="idle"}[1m]))
100 * (1 - avg by (instance) (rate(node_cpu_seconds_total{mode="idle"}[1m])))
```

??? success "Oodatav tulemus"
    1. Counter: iga loogilise protsessori jõudeaeg sekundites alates masina käivitusest, suured kasvavad arvud.
    2. Iga protsessori jõudeaja kasv sekundis viimase minuti aknas, arv 0 ja 1 vahel.
    3. Sama, aga keskmine üle protsessorite, üks arv masina kohta.
    4. Protsent, mis on arvutatud jõudeaja osakaalust: 100 miinus jõudeaja protsent. See kehtib viimase minuti akna kohta, mitte ühe hetke kohta.

Pane viimane päring vahekaardile **Graph** ja tekita `proxmox2`-s 60 sekundiks koormus (`stress-ng` paigaldasid osas 1). `$(nproc)` on masina loogiliste protsessorite arv, igaühele tuleb üks koormav protsess. Käsk näitab katse algus- ja lõpuaega:

```bash
date +%T; ssh proxmox2 'stress-ng --cpu $(nproc) --timeout 60s'; date +%T
```

Kirjuta README jaotisse **Osa 6** protsessori kasutus enne katset, katse ajal ja pärast katset. Kas graafiku muutus algas ja lõppes täpselt samal hetkel kui katse? Mis seda selgitab?

??? success "Oodatav tulemus"
    Enne ja pärast on kasutus mõne protsendi juures, katse ajal 100 lähedal. Servad on kaldu ja nihkes. Prometheus kogub iga 15 sekundi järel ja `rate(...[1m])` on viimase minuti keskmine, seega jõuab muutus graafikule täielikult alles umbes minuti jooksul.

### 6.4 Võrdlus

Kirjuta päring, mis tagastab ainult masinad, kus juurfailisüsteemis on vaba ruumi alla 90%. Kirjuta päring README jaotisse **Osa 6**. N6-s saab sellisest päringust alarmireegel.

## Osa 7 · Kokkuvõte

Vasta README jaotises **Osa 7**:

1. Kes avab ühenduse ja milline komponent tagastab väärtused Zabbixi passiivse kontrolli, Zabbixi aktiivse kontrolli ja Prometheuse puhul? Millise pordi peab igal juhul avama ja millises masinas?
2. Millises masinas on ressursse kõige vähem alles? Põhjenda osa 6 kolme küsimuse tulemustega.
3. N4-s kogus andmeid Zabbix, täna Prometheus. Kumba eelistaksid nende kahe masina jälgimiseks? Põhjenda ühe asjaga, mida oma katsetes tegid või nägid.

Prometheus `proxmox1`-s ja node_exporter `proxmox2`-s ning `proxmox3`-s jäävad tööle. N6 alustab neist: Grafana loeb Prometheuse andmeid ja alarmireegel tuleb päringust 6.4.

??? note "Kontrollnimekiri"
    - [ ] node_exporter töötab `proxmox2`-s ja `proxmox3`-s ning käivitub koos masinaga.
    - [ ] Playbook'i teine käivitus annab mõlemas masinas `changed=0`.
    - [ ] Prometheus töötab `proxmox1`-s ja Targets-lehel on mõlemad node_exporterid olekus `UP`.
    - [ ] Kogumisvea katse on tehtud, tõend on failis `logid/n5-viga.json` ja node_exporter on uuesti käivitatud.
    - [ ] README-s on osade 2, 3, 5 ja 6 ennustused ja vastused, osa 6 kolme küsimuse päringud koos ühiku ja selgitusega ning vastus küsimusele, millises masinas on ressursse kõige vähem alles.
    - [ ] Prometheus ja node_exporterid jäävad N6 jaoks tööle.

## Töö esitamine

Repositooriumis on playbook, Prometheuse seaded, tõendid kaustas `logid/` ja README vastused. Vaata `git status` väljund enne lisamist läbi: repositooriumisse ei lähe paroole ega SSH-võtmeid.

```bash
git status
git add README.md konf logid
git commit -m "Praktikum 5: server küsib mõõdikuid"
git push
```

Tulemuse näed Classroom 50-s.

## Lisaülesanded

??? example "1 · Oma silt"
    Lisa `prometheus.yml`-is target'itele silt `roll`: `proxmox2` on `veeb`, `proxmox3` on `andmebaas` (vaata `static_configs` võtit `labels` dokumentatsioonist [static_config](https://prometheus.io/docs/prometheus/latest/configuration/configuration/#static_config)). Kopeeri fail uuesti kausta `proxmox1:prometheus/config/`. Kontrolli, et konteiner näeb uut faili: `ssh proxmox1 "cd ~/prometheus && docker compose exec prometheus cat /etc/prometheus/prometheus.yml"`. Seejärel loe seaded uuesti ilma taaskäivituseta: `ssh proxmox1 "cd ~/prometheus && docker compose kill -s HUP prometheus"`. Kirjuta päring, mis näitab ainult rolli `veeb` vaba mälu.

??? example "2 · Kas target vastab"
    Kirjuta päring, mis tagastab ainult target'id, mille kogumine ebaõnnestus (`up == 0`). **Ennusta** enne katset: kui tihti Prometheus target'it küsib (`scrape_interval`) ja kui kaua ta vastust ootab (`scrape_timeout`, vaikimisi 10 s)? Peata `proxmox2`-s node_exporter ja kontrolli. Kui kaua läheb, enne kui päring midagi tagastab? Kas see on igal katsel sama?

??? example "3 · Mitu aegrida"
    Päring `count({__name__=~"node_.*"})` loeb kõik node_exporteri aegread. Mitu neid on? Leia päringuga `topk(5, count by (__name__) ({__name__=~"node_.*"}))`, millistel mõõdikutel on kõige rohkem aegridu ja miks.
