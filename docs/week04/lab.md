---
tags:
  - Praktikum
  - Monitooring
  - Ansible
---

# Praktikum: agent räägib serverile

Täna paigaldad Zabbix agent 2 kõigepealt käsitsi `proxmox2`-sse ja seejärel Ansible'i playbook'iga mõlemasse jälgitavasse masinasse, seod hostid template'iga ja kirjutad trigger'i, mis teeb probleemi, kui vaba kettaruumi on alla 20%.

**Edenemine:** laboritahvel <http://192.168.125.187:8092/> (VPN-iga).

??? abstract "Õpiväljundid"
    Pärast loengut ja praktikumi oskad:

    1. paigaldada Zabbix agent 2 ametlikust hoidlast ja seadistada `Server`, `ServerActive` ja `Hostname`;
    2. kirjutada playbook'i, mis paigaldab agendi mitmesse masinasse ja annab teisel käivitusel `changed=0`;
    3. siduda hosti passiivse või aktiivse agendi template'iga ja näidata, kumb vajab avatud porti 10050;
    4. luua item'i ja trigger'i, mis teeb probleemi, kui vaba kettaruumi on alla 20%;
    5. tekitada probleemi ja näidata andmebaasist, et see tekkis ja lahenes.

Rida **Ennusta** tähendab, et enne käsku mõtled läbi, mis juhtub. Vastus on kokkuvolditud plokis.

## Osa 1 · Agent käsitsi proxmox2-s

### 1.1 Repositoorium ja Zabbix

Ava Classroom 50 link ([Praktikum 4 - Agent räägib serverile](https://classroom50.org/hkhk-monitoring/it24-monitooring/assignments)) ja klooni oma repositoorium:

```bash
git clone <sinu-repo-url>
cd <sinu-repo>
ls
```

??? success "Oodatav tulemus"

    ```text
    README.md  konf  logid
    ```

    `README.md`-sse kirjutad vastused, pealkirjad on juba olemas. Playbook läheb kausta `konf/`, tõendid kausta `logid/`.

Zabbix peab `proxmox1`-s töötama. Kui peatasid selle N2 lõpus käsuga `docker compose stop`, käivita see uuesti. Kontrolli ka, et `proxmox2` ja `proxmox3` tulemüür on sees, sest selle osa katse sõltub sellest:

```bash
ssh proxmox1 "cd ~/zabbix && docker compose start && docker compose ps"
ssh proxmox1 "hostname -I | cut -d' ' -f1"
ssh proxmox2 "sudo firewall-cmd --state"
ssh proxmox3 "sudo firewall-cmd --state"
```

??? success "Oodatav tulemus"

    Kolm konteinerit olekus `Up`, siis `proxmox1` IP (näiteks `192.168.35.11`) ja kaks korda `running`. IP läheb agendi seadetesse. Veebiliides on aadressil `http://<proxmox1-IP>:8080` ja seal on hostid `proxmox2` ja `proxmox3` template'iga *ICMP Ping*.

??? warning "Kui näed `FirewallD is not running`"
    Masinas pole tulemüür sees. Käivita see: `sudo systemctl enable --now firewalld`. SSH on vaikimisi lubatud.

### 1.2 Agendi paigaldus

Enne automatiseerimist teed paigalduse ühes masinas käsitsi, et näha iga sammu tulemust. Osas 2 kirjutad samad sammud playbook'iks.

Agent tuleb Zabbix 7.0 ametlikust hoidlast ([Download and install Zabbix](https://www.zabbix.com/download?zabbix=7.0&os_distribution=alma_linux&os_version=9&components=agent_2&db=&ws=)). Pakett `zabbix-release` lisab hoidla kirjelduse ja allkirja võtme. Kui masinas on EPEL, välistab teine rida sealt Zabbixi paketid, et `dnf` ei võtaks vanemat versiooni:

```bash
ssh proxmox2
sudo dnf install -y https://repo.zabbix.com/zabbix/7.0/alma/9/x86_64/zabbix-release-latest-7.0.el9.noarch.rpm
[ -f /etc/yum.repos.d/epel.repo ] && ! grep -q 'excludepkgs=zabbix' /etc/yum.repos.d/epel.repo && sudo sed -i '/^\[epel\]/a excludepkgs=zabbix*' /etc/yum.repos.d/epel.repo
sudo dnf install -y zabbix-agent2
rpm -q zabbix-agent2
```

??? success "Oodatav tulemus"

    `zabbix-agent2-7.0.32-release1.el9.x86_64` (või uuem 7.0). Kui versioon algab `6.`, tuli pakett EPEL-ist: kontrolli `grep excludepkgs /etc/yum.repos.d/epel.repo` ja paigalda uuesti.

Agendi konfiguratsioonifailis on vaikimisi `Server=127.0.0.1`, `ServerActive=127.0.0.1` ja `Hostname=Zabbix server` (loengu [tabel 4.1](lecture.md#2-agendi-paigaldus-ja-kolm-seadet)). Asenda need. `P1` asemele kirjuta `proxmox1` IP:

```bash
P1=192.168.35.11
sudo sed -i -e "s/^Server=.*/Server=$P1/" -e "s/^ServerActive=.*/ServerActive=$P1/" -e "s/^Hostname=.*/Hostname=proxmox2/" /etc/zabbix/zabbix_agent2.conf
sudo grep -E '^(Server|ServerActive|Hostname)=' /etc/zabbix/zabbix_agent2.conf
```

Käivita agent ja kontrolli, et see kuulab porti 10050 ja oskab ketta vaba ruumi lugeda:

```bash
sudo systemctl enable --now zabbix-agent2
systemctl is-active zabbix-agent2
ss -ltn | grep 10050
sudo zabbix_agent2 -t 'vfs.fs.size[/,pfree]'
exit
```

??? success "Oodatav tulemus"

    `active`, rida `LISTEN ... 0.0.0.0:10050` (või `*:10050`) ja võti koos väärtusega, näiteks `vfs.fs.size[/,pfree]  [s|71.42]`. See on juurfailisüsteemi vaba ruum protsentides. Kirjuta see README-sse, osas 5 läheb seda vaja.

### 1.3 Ühendus serverist agendini

Agent kuulab. Nüüd kontrolli `proxmox1`-st, kas server saab `proxmox2` porti 10050 ühendust. Bash avab TCP-ühenduse aadressile `/dev/tcp/<IP>/<port>`, seega pole eraldi tööriista vaja. `<proxmox2-IP>` leiad käsuga `ssh proxmox2 hostname -I`.

**Ennusta:** kas `proxmox1` saab `proxmox2` porti 10050 ühendust?

```bash
ssh proxmox1 "timeout 3 bash -c '</dev/tcp/<proxmox2-IP>/10050' && echo lahti || echo kinni"
```

??? success "Oodatav tulemus"

    `kinni` ja võib-olla `No route to host`. Agent kuulab, aga `proxmox2` tulemüür ei lase ühendust temani. Ava port:

    ```bash
    ssh proxmox2 "sudo firewall-cmd --permanent --add-port=10050/tcp && sudo firewall-cmd --reload"
    ```

    Korda kontrolli: nüüd on vastus `lahti`.

**Küsimus (README):** miks oli port kinni, kuigi `ss` näitas, et agent kuulab?

Veebiliideses on `proxmox2` juures ZBX endiselt hall. Hostil on ainult template *ICMP Ping* ja selles pole ühtegi agendi item'it, seega server ei küsi agendilt veel midagi. See muutub osas 3.

## Osa 2 · Sama playbook'iga kahes masinas

`proxmox3` vajab samu samme, ainult `Hostname` on teine. Käsitsi kordamise asemel kirjutad need playbook'iks. Playbook kirjeldab soovitud olekut kõigi masinate jaoks ja `Hostname` tuleb masinate loendist (`-i`) muutujaga `inventory_hostname`.

**Nõuded (`konf/agent.yml`):**

- impordib Zabbixi allkirja võtme `https://repo.zabbix.com/RPM-GPG-KEY-ZABBIX-B5333005` ja paigaldab hoidla paketi (sama URL mis osas 1);
- kui `/etc/yum.repos.d/epel.repo` on olemas, lisab sinna rea `excludepkgs=zabbix*`;
- paigaldab `zabbix-agent2`;
- paneb failis `/etc/zabbix/zabbix_agent2.conf` paika `Server`, `ServerActive` ja `Hostname` ning taaskäivitab agendi **ainult siis, kui fail muutus** (handler);
- avab tulemüüris pordi `10050/tcp` nii, et see jääb alles ka pärast taaskäivitust;
- agent töötab ja käivitub koos masinaga;
- teine käivitus annab `changed=0`.

Uued moodulid on tabelis 4.5.

??? note "Tabel 4.5. Playbook'i moodulid"
    | Moodul | Mida teeb | Parameetrid selles playbook'is |
    |---|---|---|
    | [`ansible.builtin.rpm_key`](https://docs.ansible.com/ansible/latest/collections/ansible/builtin/rpm_key_module.html) | impordib paketihalduri allkirja võtme | `key`, `state` |
    | [`ansible.builtin.dnf`](https://docs.ansible.com/ansible/latest/collections/ansible/builtin/dnf_module.html) | paigaldab paketi nimest või URL-ist | `name`, `state` |
    | [`ansible.builtin.stat`](https://docs.ansible.com/ansible/latest/collections/ansible/builtin/stat_module.html) | uurib, kas fail on olemas, midagi ei muuda | `path` |
    | [`ansible.builtin.lineinfile`](https://docs.ansible.com/ansible/latest/collections/ansible/builtin/lineinfile_module.html) | tagab, et failis on üks kindel rida | `path`, `regexp`, `line`, `insertafter` |
    | [`ansible.posix.firewalld`](https://docs.ansible.com/ansible/latest/collections/ansible/posix/firewalld_module.html) | avab või sulgeb pordi firewalld-s | `port`, `permanent`, `immediate`, `state` |
    | [`ansible.builtin.service`](https://docs.ansible.com/ansible/latest/collections/ansible/builtin/service_module.html) | käivitab teenuse ja lisab selle käivitusse | `name`, `state`, `enabled` |


`register`, `when`, `loop` ja `notify` on ülesande võtmesõnad, mooduli parameetrite hulka need ei kuulu. `register` salvestab mooduli tulemuse muutujasse, `when` jätab ülesande vahele, kui tingimus pole tõene, ja `loop` kordab ülesannet iga loendi elemendi jaoks.

Enne kirjutamist uuri tulemüüri moodulit:

```bash
ansible-doc ansible.posix.firewalld
```

Leia, mida teeb `immediate` ja mis juhtub, kui paned ainult `permanent: true`. Kirjuta vastus README-sse.

??? tip "Vihje: playbook'i ülesehitus"

    ```yaml
    - name: Zabbix agent 2 jälgitavatesse masinatesse
      hosts: all
      become: true
      vars:
        zabbix_server: 192.168.35.11        # proxmox1 IP
      tasks:
        - name: Zabbixi pakettide allkirja võti
          ansible.builtin.rpm_key:
            key: https://repo.zabbix.com/RPM-GPG-KEY-ZABBIX-B5333005
            state: present

        - name: Zabbix 7.0 repositoorium
          ansible.builtin.dnf:
            name: https://repo.zabbix.com/zabbix/7.0/alma/9/x86_64/zabbix-release-latest-7.0.el9.noarch.rpm
            state: present

        - name: Kas EPEL on olemas
          ansible.builtin.stat:
            path: /etc/yum.repos.d/epel.repo
          register: epel

        - name: EPEL ei paku Zabbixi pakette
          ansible.builtin.lineinfile:
            path: /etc/yum.repos.d/epel.repo
            insertafter: '^\[epel\]'
            line: excludepkgs=zabbix*
          when: epel.stat.exists

        # ... pakett zabbix-agent2

        - name: Agendi seaded
          ansible.builtin.lineinfile:
            path: /etc/zabbix/zabbix_agent2.conf
            regexp: "^{{ item.key }}="
            line: "{{ item.key }}={{ item.value }}"
          loop:
            - { key: Server, value: "{{ zabbix_server }}" }
            # ... ServerActive ja Hostname
          notify: Taaskäivita agent

        # ... port 10050/tcp tulemüüris (tabel 4.5)
        # ... teenus zabbix-agent2 töötab ja käivitub koos masinaga

      handlers:
        - name: Taaskäivita agent
          ansible.builtin.service:
            name: zabbix-agent2
            state: restarted
    ```
    `regexp: "^Server="` ei leia rida `ServerActive=`, sest pärast sõna `Server` peab kohe tulema `=`.

**Ennusta:** `proxmox2` on osa 1 järel juba soovitud olekus, `proxmox3`-s pole midagi tehtud. Mida näitab `PLAY RECAP` kummagi kohta?

```bash
ansible-playbook -i proxmox2,proxmox3, konf/agent.yml
```

??? success "Oodatav tulemus"

    `proxmox2`: `changed=0` (või `1`, kui osas 1 jäi EPEL-i rida lisamata). `proxmox3`: enamik ülesandeid on `changed`, sest need tehti esimest korda, ja lõpus taaskäivitas handler agendi. Mõlemal `failed=0`.

Käivita playbook teist korda ja salvesta väljund. Teine käivitus näitab, et playbook ei muuda masinaid, mis on juba soovitud olekus:

```bash
ansible-playbook -i proxmox2,proxmox3, konf/agent.yml | tee logid/a2-teine-kaivitus.txt
```

??? success "Oodatav tulemus"

    `PLAY RECAP` all kaks rida, mõlemas `changed=0` ja `failed=0`. Kui kuskil on `changed=1`, vaata, mis ülesanne muutis midagi ka teisel korral, ja paranda see.

Salvesta mõlema masina agendi olek tõendiks:

```bash
for h in proxmox2 proxmox3; do
  echo "== $h"
  ssh $h "systemctl is-active zabbix-agent2; ss -ltn | grep 10050; sudo grep -E '^(Server|ServerActive|Hostname)=' /etc/zabbix/zabbix_agent2.conf"
done > logid/a2-agendid.txt
cat logid/a2-agendid.txt
```

??? success "Oodatav tulemus"

    Kummagi masina kohta `active`, pordi 10050 rida ja kolm seadet. `Hostname` on `proxmox2` ja `proxmox3`, `Server` ja `ServerActive` on `proxmox1` IP.

??? warning "Kui näed `Failed to validate GPG signature for zabbix-release`"
    Ansible kontrollib ka URL-ist paigaldatava paketi allkirja. Ülesanne `rpm_key` peab olema enne hoidla paketi ülesannet.

**Küsimus (README):** miks oli esimesel käivitusel `proxmox2` ja `proxmox3` `changed` arv erinev?

## Osa 3 · Template'id: passiivne ja aktiivne

Agent töötab mõlemas masinas, aga server ei küsi temalt veel midagi. Template annab hostile item'id ja trigger'id. `proxmox2` saab passiivse agendi template'i ja `proxmox3` aktiivse oma (loengu [tabel 4.2](lecture.md#3-passiivne-ja-aktiivne-agent)).

**Data collection → Hosts → proxmox2**, väljal **Templates** kirjuta `Linux by` ja vali **Linux by Zabbix agent**. *ICMP Ping* jääb alles. **Update**.

**Data collection → Hosts → proxmox3**, vali **Linux by Zabbix agent active**. **Update**.

Oota 1-2 minutit ja ava **Monitoring → Latest data**, filtris **Hosts:** `proxmox2` ja `proxmox3`.

??? success "Oodatav tulemus"

    Mõlemal hostil on kümneid uusi ridu: *Load average (1m avg)*, *Available memory*, *CPU utilization* ja teised. Kettaruumi ja võrguliideste read loob template discovery-reeglitega, mis käivituvad kord tunnis, seega võivad need veel puududa. Kiiremini saad nii: **Data collection → Hosts → proxmox2 → Discovery**, vali reeglid ja **Execute now**. **Data collection → Hosts** lehel on `proxmox2` juures ZBX roheline. Zabbix 7.0 näitab samas veerus ka aktiivse agendi olekut, seega on roheline ka `proxmox3` juures.

Ava **Data collection → Hosts → proxmox2 → Items** ja sama `proxmox3` kohta. Vaata veergu **Type**.

Kui mõni host jääb andmeteta, alusta agendi logist `/var/log/zabbix/zabbix_agent2.log` (`sudo tail -20 /var/log/zabbix/zabbix_agent2.log`).

??? warning "Kui `proxmox2` ZBX on punane, kuigi port on lahti"
    Otsi agendi logist sõna `rejected`. Seal on aadress, kust päring tuli, ja aadressid, mis on seades `Server`. Need peavad klappima. Pärast seadete muutmist taaskäivita agent (playbook teeb seda handleriga).

??? warning "Kui `proxmox3` andmeid ei tule"
    Otsi agendi logist sõna `not found`. Kui server ei leidnud hosti, ei klapi agendi `Hostname` veebiliidese väljaga **Host name** (ka suur- ja väiketäht loevad). Kui logis on `cannot connect`, kontrolli `proxmox3`-st: `timeout 3 bash -c '</dev/tcp/<proxmox1-IP>/10051' && echo lahti` ja `proxmox1`-s `docker compose ps`.

**Küsimus (README):** mis on veerus **Type** `proxmox2` ja `proxmox3` item'ite erinevus ja mida see tähendab selle kohta, kes ühenduse avab?

## Osa 4 · Kes avab ühenduse

Passiivne agent vajab avatud porti 10050, aktiivne ei vaja. Kontrolli seda katsega. Järgmine käsk sulgeb pordi mõlemas masinas ainult praeguseks, `--permanent` seadet see ei muuda:

```bash
ansible all -i proxmox2,proxmox3, -b -m ansible.builtin.command -a "firewall-cmd --remove-port=10050/tcp"
```

**Ennusta:** kumma hosti andmed lakkavad tulemast?

Oota 4–5 minutit. Vahepeal võid alustada osa 5 esimese sammuga. Siis vaata **Data collection → Hosts** ja **Monitoring → Problems**.

??? success "Oodatav tulemus"

    `proxmox2` juures läheb ZBX punaseks ja **Problems** alla tuleb *Linux: Zabbix agent is not available*. Server ei pääse porti 10050. `proxmox3` andmed tulevad edasi (**Latest data**, veerg **Last check**), sest aktiivne agent avab ühenduse ise serveri porti 10051.

Masina tegelik olek erineb nüüd sellest, mida playbook kirjeldab. Sellist erinevust nimetatakse **triiviks** (configuration drift): masinat muudeti käsitsi ja muudatus jäi märkamata.

**Ennusta:** mida teeb playbook, kui käivitad selle nüüd uuesti?

```bash
ansible-playbook -i proxmox2,proxmox3, konf/agent.yml
```

??? success "Oodatav tulemus"

    Ülesanne *Passiivse agendi port tulemüüris* on mõlemas masinas `changed`, kõik teised `ok`. Moodul nägi, et port puudub tulemüüri töötavast seadistusest, ja lisas selle tagasi (`immediate: true`). Mõne minuti pärast on `proxmox2` ZBX jälle roheline ja probleem lahenes.

**Küsimus (README):** miks tulid `proxmox3` andmed edasi ja kuidas playbook'i uus käivitus triivi parandas?

## Osa 5 · Oma trigger: vaba kettaruum alla 20%

Template'is on ketta trigger'id juba olemas, aga nende piiri ja raskusastme on valinud Zabbix. Selles osas teed oma item'i ja trigger'i, tekitad probleemi ja vaatad, kuidas see laheneb.

### 5.1 Item

 **Data collection → Hosts → proxmox2 → Items → Create item** ([Item'i loomine](https://www.zabbix.com/documentation/7.0/en/manual/config/items/item)):

- **Name:** `Vaba kettaruum /`
- **Type:** **Zabbix agent**
- **Key:** `vfs.fs.size[/,pfree]` (sama võti, mida kontrollisid osas 1 käsuga `zabbix_agent2 -t`)
- **Type of information:** **Numeric (float)**
- **Units:** `%`
- **Update interval:** `30s`
- **Add**. Väärtust näed poole minuti pärast **Monitoring → Latest data** all.

??? warning "Kui item on olekus Not supported"
    Võti on vale. Hõljuta hiirt punase ikooni kohal, seal on põhjus. Kontrolli võtit masina seest: `sudo zabbix_agent2 -t '<võti>'`.

### 5.2 Trigger

 **Data collection → Hosts → proxmox2 → Triggers → Create trigger** ([Trigger'i loomine](https://www.zabbix.com/documentation/7.0/en/manual/config/triggers/trigger)):

- **Name:** `Vaba kettaruum alla 20%`
- **Severity:** **Warning**
- **Expression:** `last(/proxmox2/vfs.fs.size[/,pfree])<20`
- **Add**

Avaldise võid ka koostada nupuga **Add** välja **Expression** kõrval: vali item, funktsioon `last()`, tingimus `<` ja väärtus `20`.

### 5.3 Täida ketas

Selleks, et probleem tekiks, peab vaba ruumi olema alla 20%. `fallocate` loob faili, mis võtab kettal ruumi kohe, ilma andmeid kirjutamata. Järgmine arvutus jätab vabaks umbes 15%:

```bash
ssh proxmox2
df -h /
vaba=$(df --output=avail -B1 / | tail -1); kokku=$(df --output=size -B1 / | tail -1)
taida=$(( vaba - kokku * 15 / 100 ))
echo "Täidan $(( taida / 1024 / 1024 )) MB"
sudo fallocate -l "$taida" /ketas-tais
df -h /
```

??? success "Oodatav tulemus"

    Teine `df` näitab veerus `Use%` umbes 85%. Kui `echo` näitab negatiivset arvu, on vaba ruumi juba alla 15% ja trigger peaks probleemi tegema ka ilma täitmata: jäta `fallocate` vahele.

**Ennusta:** item'i intervall on 30 sekundit. Millal ilmub probleem **Monitoring → Problems** alla?

Ava **Monitoring → Problems** ja oota.

??? success "Oodatav tulemus"

    Minuti jooksul ilmub rida **Host** `proxmox2`, **Problem** *Vaba kettaruum alla 20%*, **Severity** **Warning**. Võib tulla ka template'i trigger *FS [/]: Space is low*, sest see kontrollib sama asja oma piiriga.

### 5.4 Paranda

Kustuta fail ja vaata, kuidas probleem laheneb:

```bash
sudo rm /ketas-tais
df -h /
exit
```

Oota minut ja vali **Monitoring → Problems** filtris **Show: History**.

??? success "Oodatav tulemus"

    *Vaba kettaruum alla 20%* on olekus **RESOLVED** ja veerus **Duration** on näha, kui kaua see kestis.

### 5.5 Tõend andmebaasist

Zabbix hoiab template'ide seoseid ja probleeme andmebaasis. Oma arvutis repositooriumi kaustas:

```bash
ssh proxmox1 "cd ~/zabbix && docker compose exec -T postgres psql -U zabbix -c \"SELECT h.host, t.host AS template FROM hosts h JOIN hosts_templates ht ON ht.hostid = h.hostid JOIN hosts t ON t.hostid = ht.templateid WHERE h.host LIKE 'proxmox%' ORDER BY 1, 2;\" -c \"SELECT name, severity, to_timestamp(clock) AS algas, to_timestamp(NULLIF(r_clock, 0)) AS lahenes FROM problem WHERE name LIKE '%kettaruum%' ORDER BY clock;\"" > logid/a5-andmebaas.txt
cat logid/a5-andmebaas.txt
```

??? success "Oodatav tulemus"

    Esimeses tabelis on `proxmox2` juures *ICMP Ping* ja *Linux by Zabbix agent*, `proxmox3` juures *ICMP Ping* ja *Linux by Zabbix agent active*. Teises tabelis on *Vaba kettaruum alla 20%*, `severity` on `2` (Warning) ning olemas on nii `algas` kui ka `lahenes`. Kui `lahenes` on tühi, pole probleem veel lahenenud: kontrolli, et `/ketas-tais` on kustutatud, ja oota veel minut. Salvesta tõend samal päeval, sest Zabbix kustutab lahenenud probleemid sellest tabelist umbes ööpäeva pärast.

**Küsimus (README):** mitu minutit kulus täitmisest probleemini ja kustutamisest lahenemiseni? Miks see ei juhtunud kohe?

## Töö esitamine

Repositooriumis on README vastused, playbook `konf/agent.yml` ja kolm tõendifaili. Oma arvutis repositooriumi kaustas:

```bash
git status
git add README.md konf logid
git commit -m "Praktikum 4: agent räägib serverile"
git push
```

Tulemuse näed Classroom 50-s.

Agendid jäävad masinatesse alles ja Zabbix võib tööle jääda. Kui pead Zabbixi peatama, kasuta `docker compose stop`. Käsk `docker compose down -v` kustutab andmebaasi koos kõigi hostidega.

Kodutöö: [Kas varundus töötas?](homework.md)

## Lisaülesanded

??? example "1 · Hüsterees"
    Kui vaba ruum kõigub 20% ümber, tekib ja laheneb probleem iga 30 sekundi järel. Ava oma trigger, vali **OK event generation: Recovery expression** ja kirjuta `last(/proxmox2/vfs.fs.size[/,pfree])>25` ([hüsterees](https://www.zabbix.com/documentation/7.0/en/manual/config/triggers/expression#hysteresis)). Täida ketas nii, et vaba jääb 15%. Siis kustuta fail ja loo uus, mis jätab vabaks 22% (osa 5.3 arvutuses `15` asemel `22`). Mis olekus on probleem ja miks?

??? example "2 · Template'i piir hosti makroga"
    Template'i ketta trigger kasutab makrot `{$VFS.FS.PUSED.MAX.WARN}` (vaikimisi 80). Ava **Data collection → Hosts → proxmox3 → Macros → Inherited and host macros** ja muuda see `proxmox3` jaoks 50 peale. Kas `proxmox3` juures tekib probleem? Miks on makro parem kui template'i muutmine?

??? example "3 · Agent ka proxmox1-sse"
    Host **Zabbix server** on N2-st saati punane, sest seal pole agenti. Lisa `proxmox1` playbook'i käsule (`-i proxmox1,proxmox2,proxmox3,`) ja muuda hosti **Zabbix server** liidese IP `proxmox1` IP-ks. Kas ZBX läheb roheliseks? Vaata `proxmox1`-s `sudo tail /var/log/zabbix/zabbix_agent2.log`. Server töötab konteineris ja ühendus konteinerist sama masina IP-le ei läbi Dockeri aadressi asendust. Millise aadressi pead lisama seadesse `Server` (vihje: `docker network inspect zabbix_default`)?
