---
tags:
  - Labor
  - Monitooring
  - Zabbix
  - Docker
---

# K2 · Praktikum: Zabbix valvab

Kati e-pood oli öösel 40 minutit maas ja keegi ei teadnud. Täna paned `proxmox1`-s tööle Zabbixi, mis kontrollib iga minut, kas `proxmox2` ja `proxmox3` vastavad. Ühe masina aadressi kirjutad meelega valesti ja vaatad, kuidas Zabbix probleemi ise üles leiab ja pärast parandust lahendatuks märgib.

<figure markdown="span">
  ![Zabbixi osad proxmox1-s: veebiliides, server ja PostgreSQL; server pingib proxmox2 ja proxmox3](../images/n02_zabbix_osad.svg)
  <figcaption>Joonis 2.4. Labori ülesehitus. Täna töötab ping, agent tuleb K4-s.</figcaption>
</figure>

Labor võtab umbes 60 minutit. Osad A1–A5 teeme klassis. Lisaülesanded on neile, kes jõuavad varem valmis. Oodatav tulemus ja vihjed on kinnistes plokkides: tee enne ise ja siis võrdle.

??? abstract "Õpiväljundid"

    Praktikumi lõpuks oskad:

    1. käivitada Zabbixi serveri, andmebaasi ja veebiliidese Docker Compose'iga;
    2. leida, miks konteiner ei käivitu, kui port on juba kasutusel;
    3. lisada hosti, panna sellele template'i külge ja leida selle viimased andmed;
    4. tekitada probleemi, leida see veebiliidesest ja näha, kuidas see pärast parandust lahenduks märgitakse;
    5. näidata andmebaasist, et Zabbix hoiab hoste ja probleeme seal, kust neid hiljem uuesti leiab.

## Enne alustamist

Ava õpetaja jagatud Classroom 50 link ([Lab 02 - Zabbix valvab](https://classroom50.org/hkhk-monitoring/it24-monitooring/assignments)) ja klooni oma repo:

```bash
git clone <sinu-repo-url>
cd <sinu-repo>
ls -R
```

??? success "Oodatav tulemus"

    ```text
    .:
    README.md  konf  logid
    ```

    `README.md`-sse kirjutad ennustused ja vastused, pealkirjad on juba olemas. `konf/` ja `logid/` on tõendite jaoks.

Zabbix vajab `proxmox1`-s Dockerit (automatiseerimise kursuse N5) ja umbes 300 MB vaba mälu. Pane kirja ka kõigi kolme masina IP-d, sest Zabbix räägib masinatega IP kaudu, nimesid `proxmox2` ja `proxmox3` ta ei tea:

```bash
ssh proxmox1 "docker --version; free -h | grep Mem"
for h in proxmox1 proxmox2 proxmox3; do echo "$h $(ssh $h hostname -I | cut -d' ' -f1)"; done
```

??? success "Oodatav tulemus"

    Dockeri versioon ja mälurida, kus veerg `available` on vähemalt 1 GB. Seejärel kolm rida, näiteks `proxmox2 192.168.35.12`. Need IP-d lähevad osades A4 ja A5 Zabbixisse.

!!! tip "Kui `docker: command not found` või `permission denied`"
    Docker puudub või sinu kasutaja pole grupis `docker`. Tee automatiseerimise [N5 Osa 0](https://hkhk-automation.github.io/devops/week05/lab/) ja logi `proxmox1`-sse uuesti sisse.

## A · Juhendatud osa

### A1 · Manuaalist Compose'i failiks

Selle sammu lõpuks on `proxmox1`-s Compose'i fail, mille image'id ja seaded leidsid ise Zabbixi manuaalist. Tööl ei anna keegi sulle valmis faili: on manuaal ja sina. Seepärast õpime kõigepealt manuaali lugema.

Zabbixi manuaal on suur, PDF-ina üle 2000 lehekülje. Seda ei loeta algusest lõpuni, sealt **otsitakse**.

!!! tip "Soovitatav töökäik: kuidas manuaalist otsida"
    1. **Õige versioon:** veebis aadressis peab olema `/documentation/7.0/`. PDF: [Zabbix_Documentation_7.0.en.pdf](https://www.zabbix.com/documentation/7.0/downloads/Zabbix_Documentation_7.0.en.pdf) (~50 MB), laadi alla ja hoia labori ajal lahti.
    2. **Otsi täpse sõnaga:** muutuja nimi (`ZBX_SERVER_HOST`), item'i võti (`icmpping`), menüü nimi (`Latest data`). PDF-is **Ctrl+F**, veebis lehe ülaosa otsingukast. Täpne sõna leiab õige koha, „how to install“ leiab sada kohta.
    3. **Lehe sees:** veebis **On this page** on lehe sisukord, PDF-is vasakul järjehoidjad (bookmarks).
    4. **Näited:** koodiplokid on enamasti kohe kopeeritavad, aga kontrolli paroole, porte ja versiooni.

**1. Ava õige versioon.** Ava [Zabbixi manuaal: Installation from containers](https://www.zabbix.com/documentation/7.0/en/manual/installation/containers). Vaata lehe ülaosa: seal on versiooni valik. Kui otsingumootor viib sind lehele, kus on kirjas **7.4 (current)**, vaheta see **7.0** peale. Meil on 7.0 LTS ja versioonide vahel muutuvad image'ite sildid, seaded ja menüüd.

!!! warning "Tähelepanu: „current“ ei ole sinu versioon"
    Manuaali link, kus aadressis on `/current/`, näitab alati kõige uuemat versiooni. Kui manuaal ütleb midagi, mida sinu Zabbixis pole, kontrolli kõigepealt versiooni. Pane järjehoidjasse `/documentation/7.0/` aadress.

**2. Leia image'id.** Lehe paremal (või ülal) on **On this page**, see on lehe sisukord. Ava **Available Docker images**. Tabelis on igal Zabbixi osal oma image. Leia:

- serveri image, mis kasutab **PostgreSQL**-i;
- veebiliidese image, mis kasutab **Nginx**-i ja **PostgreSQL**-i.

**3. Leia silt (tag).** Ava **Image tags**. Seal on silt kujul `zabbix/<image>:<os>-<version>`. Meie valik: OS **alpine** (väike image) ja konkreetne versioon **7.0.32**. Sildi `latest` asemel kirjutad alati konkreetse versiooni, siis ei uuene Zabbix sinu teadmata. Uusimaid 7.0 versioone näed Docker Hubis, link on samas tabelis.

**4. Tõlgi `docker run` Compose'iks.** Ava **Docker (manual deployment) → Deploy Zabbix server (PostgreSQL) with SNMP traps**. Seal käivitatakse andmebaas, server ja veebiliides ükshaaval `docker run` käskudega. Iga `-e NIMI="väärtus"` on keskkonnamuutuja. Compose'is läheb sama asi teenuse alla `environment:` sektsiooni. Manuaali märkus ütleb ka, et `ZBX_SERVER_HOST` vastab Zabbixi seadele `Server`.

??? success "Oodatav tulemus"

    | Mis | Leid manuaalist |
    |---|---|
    | Server | `zabbix/zabbix-server-pgsql` |
    | Veebiliides | `zabbix/zabbix-web-nginx-pgsql` |
    | Silt | `alpine-7.0.32` |
    | Andmebaasi seaded | `DB_SERVER_HOST`, `POSTGRES_USER`, `POSTGRES_PASSWORD`, `POSTGRES_DB` |
    | Veebiliides leiab serveri | `ZBX_SERVER_HOST` |
    | Veebiliidese port konteineris | `8080` (`-p 80:8080`) |

Ava oma repos (see, mille Enne alustamist osas kloonisid) fail `README.md`. Seal on iga sammu jaoks pealkiri ja küsimused. Jaotises **A1** kirjuta `_vastus_` asemele, mis image'id ja sildi leidsid ning mis manuaali osast (pealkiri).

Nüüd tee fail valmis. Ühenda `proxmox1`-ga ja loo kaust:

```bash
ssh proxmox1
mkdir -p ~/zabbix && cd ~/zabbix
```

Andmebaasi parool läheb faili `.env`, mitte Compose'i faili (automatiseerimise N6 Osa 6):

```bash
echo "ZBX_DB_PASSWORD=$(openssl rand -hex 12)" > .env
cat .env
```

Loo `compose.yaml` (VS Code Remote-SSH või `nano compose.yaml`). Kolm kohta `<...>` täida manuaalist leitud image'i ja sildiga:

```yaml
services:
  postgres:
    image: postgres:16-alpine
    environment:
      POSTGRES_USER: zabbix
      POSTGRES_PASSWORD: ${ZBX_DB_PASSWORD}
      POSTGRES_DB: zabbix
    volumes:
      - zbx-db:/var/lib/postgresql/data

  zabbix-server:
    image: <serveri image>:<silt>
    environment:
      DB_SERVER_HOST: postgres
      POSTGRES_USER: zabbix
      POSTGRES_PASSWORD: ${ZBX_DB_PASSWORD}
      POSTGRES_DB: zabbix
    ports:
      - "10051:10051"
    depends_on:
      - postgres

  zabbix-web:
    image: <veebiliidese image>:<silt>
    environment:
      ZBX_SERVER_HOST: <serveri teenuse nimi selles failis>
      DB_SERVER_HOST: postgres
      POSTGRES_USER: zabbix
      POSTGRES_PASSWORD: ${ZBX_DB_PASSWORD}
      POSTGRES_DB: zabbix
      PHP_TZ: Europe/Tallinn
    ports:
      - "8080:8080"
    depends_on:
      - zabbix-server

volumes:
  zbx-db:
```

Mis on manuaali näitest erinev ja miks:

- `DB_SERVER_HOST: postgres`: manuaalis on konteineri nimi `postgres-server`, meil on teenuse nimi `postgres`. Compose'is räägivad teenused omavahel teenuse nime järgi (automatiseerimise N6 Osa 3).
- `${ZBX_DB_PASSWORD}`: manuaalis on parool `zabbix_pwd` otse käsus. Manuaal ise ütleb, et asenda see tugeva parooliga. Meil tuleb see `.env`-ist.
- `8080:8080`: manuaalis on `-p 80:8080`, aga `proxmox1` port 80 võib olla automatiseerimise N3 nginx-i käes.
- `10051`: port, kuhu agendid K4-s andmeid saadavad ([Requirements: pordid](https://www.zabbix.com/documentation/7.0/en/manual/installation/requirements)).
- Kõik ülejäänud seaded on manuaalis [Environment variables](https://www.zabbix.com/documentation/7.0/en/manual/installation/containers#environment-variables) ja iga image'i Docker Hubi lehel.

??? tip "Vihje: kas fail on õige?"
    `docker compose config` loeb faili, asendab muutujad `.env`-ist ja näitab lõpptulemust. Kui failis on viga või `<...>` on täitmata, ütleb ta seda kohe, ilma et midagi käivitaks.

??? question "Ennusta (kirjuta README-sse enne järgmist sammu)"
    Kolm teenust kasutavad sama parooli. Mis juhtuks, kui `zabbix-server` all oleks parool vale, aga veebiliidese all õige? Kas veebiliides avaneks?

### A2 · Port on kinni

Selle sammu lõpuks töötavad kõik kolm konteinerit. Enne seda näed viga, mida laboris tuleb ette kõige sagedamini.

Kujutle, et automatiseerimise N6 stack jäi `proxmox1`-s käima. See kasutab porti 8080. Tekita sama olukord, isegi kui sul N6 stack ei käi:

```bash
docker run -d --name ankur -p 8080:80 nginx:1.27
docker compose up -d
docker compose ps -a
```

??? success "Oodatav tulemus"

    ```text
    Error response from daemon: ... Bind for 0.0.0.0:8080 failed: port is already allocated
    ```

    `docker compose ps -a`: `postgres` ja `zabbix-server` on `Up`, aga `zabbix-web` on olekus `Created`. Konteiner on loodud, aga käivitada ei saanud.

??? question "Diagnoosi"
    Kes hoiab porti 8080? Leia see kahel viisil: `docker ps` (konteinerite pordid) ja `sudo ss -ltnp | grep 8080` (kõik, mis masinas kuulab). Miks tasub osata mõlemat?

Paranda: peata see, kes porti hoiab, ja käivita uuesti. Kui sul käib N6 stack, peata see kaustas `~/lab06` käsuga `docker compose down`.

```bash
docker rm -f ankur
docker compose up -d
docker compose ps
```

??? success "Oodatav tulemus"

    Kolm rida, kõik `Up`. `zabbix-web` real on `0.0.0.0:8080->8080/tcp`.

!!! warning "Tähelepanu: esimene käivitus võtab 1–2 minutit"
    Esimesel käivitusel loob server andmebaasi tabelid. Konteinerid on juba `Up`, aga sisse logida veel ei saa: leht võib näidata `Database error`. Vaata, mis toimub: `docker compose logs -f zabbix-server`. Kui näed `Database schema successfully created` või `server #0 started`, on valmis (**Ctrl+C**, et logist välja tulla). Manuaal ütleb sama: [typically within 1–3 minutes](https://www.zabbix.com/documentation/7.0/en/manual/installation/containers#docker-compose).

Salvesta tõend oma arvutis repo kaustas (`exit`, et `proxmox1`-st välja tulla):

```bash
ssh proxmox1 "cd ~/zabbix && docker compose ps" > logid/a2-compose-ps.txt
scp proxmox1:zabbix/compose.yaml konf/
```

Faili `.env` **ei kopeeri** reposse.

### A3 · Esimene sisselogimine

Selle sammu lõpuks oled veebiliideses sees, vaikimisi parool on vahetatud ja tead, miks host „Zabbix server“ on punane.

Ava brauseris `http://<proxmox1-IP>:8080`. Kasutaja **Admin**, parool **zabbix**.

!!! warning "Tähelepanu: vaheta parool kohe"
    `Admin / zabbix` on kirjas igas Zabbixi juhendis ([Basic configuration](https://www.zabbix.com/documentation/7.0/en/manual/quickstart/basic_config)) ja iga ründaja proovib seda esimesena. Ülal paremal **User settings → Profile → Change password** ([User profile](https://www.zabbix.com/documentation/7.0/en/manual/web_interface/user_profile)). Pane uus parool kirja, aga mitte reposse.

!!! tip "Kui leht ei avane"
    Kontrolli `ssh proxmox1 "curl -s -o /dev/null -w '%{http_code}' localhost:8080"`. Kui see annab `200`, töötab Zabbix ja viga on võrgus sinu ja `proxmox1` vahel: kas VPN on sees, kas IP on õige? Kui see ei anna `200`, vaata `docker compose logs zabbix-web`.

Ava **Data collection → Hosts** ([Hosts](https://www.zabbix.com/documentation/7.0/en/manual/web_interface/frontend_sections/data_collection/hosts)). Seal on juba üks host: **Zabbix server**. Veerus **Availability** on punane **ZBX**.

??? question "Diagnoosi"
    Hõljuta hiirt punase ZBX kohal. Zabbix proovib ühendust võtta agendiga aadressil `127.0.0.1:10050`. Miks see ei õnnestu? (Vihje: mitu konteinerit sul on ja kas mõni neist on agent? Vaata [loengu §3](lecture.md#3-zabbix-kes-kellega-raagib).)

Ava **Monitoring → Latest data** ja vali host **Zabbix server**. Osal item'itel on väärtus olemas, näiteks `Zabbix server: Utilization of configuration syncer internal processes`.

??? success "Oodatav tulemus"

    ZBX on punane, sest agenti pole: see tuleb K4-s. Server mõõdab aga iseennast ([sisemised item'id](https://www.zabbix.com/documentation/7.0/en/manual/config/items/itemtypes/internal)), neid saab ilma agendita. Mõnel real on väärtus, teistel on tühi, sest need ootavad agenti.

### A4 · Esimene host: proxmox2

Selle sammu lõpuks pingib Zabbix iga minut `proxmox2`-te ja sa näed vastuse aega. Hosti lisamine on manuaalis [Configuring a host](https://www.zabbix.com/documentation/7.0/en/manual/config/hosts/host), template'id [Templates](https://www.zabbix.com/documentation/7.0/en/manual/config/templates).

**Data collection → Hosts → Create host**:

- **Host name:** `proxmox2`
- **Templates:** kirjuta `ICMP` ja vali **ICMP Ping**
- **Host groups:** **Linux servers**
- **Interfaces → Add → Agent**, **IP address:** `proxmox2` IP (Enne alustamist osast)
- **Add**

Enne kui veebiliideses ootad, kontrolli serveri seest, kas ping üldse läbi läheb. Zabbix kasutab pingimiseks programmi `fping` ([ICMP ping kontrollid](https://www.zabbix.com/documentation/7.0/en/manual/config/items/itemtypes/simple_checks#icmpping)) ja see on serveri konteineris olemas:

```bash
cd ~/zabbix && docker compose exec zabbix-server fping <proxmox2-IP>
```

??? success "Oodatav tulemus"

    `192.168.35.12 is alive`. Kui siit tuleb `is alive`, tuleb ka veebiliidesesse 1 (Up). Nii tead minutiga, kas viga on võrgus või Zabbixi seadistuses, ilma veebiliideses ootamata.

Ava **Monitoring → Latest data** ([Latest data](https://www.zabbix.com/documentation/7.0/en/manual/web_interface/frontend_sections/monitoring/latest_data)), filtris **Hosts:** `proxmox2`, **Apply**. Oota minut ja värskenda.

??? success "Oodatav tulemus"

    Kolm rida template'ist *ICMP Ping*:

    | Name | Last value |
    |---|---|
    | ICMP ping | Up (1) |
    | ICMP loss | 0 % |
    | ICMP response time | mõni ms |

    Ühe rea kõrval vajuta **Graph**: see on sama number ajas, iga minuti kohta üks punkt.

**Otsi manuaalist:** ava [Simple checks](https://www.zabbix.com/documentation/7.0/en/manual/config/items/itemtypes/simple_checks) või otsi PDF-ist `icmpping`. Mida tähendab tagastatud väärtus `0` ja mida `1`? Mis on parameeter `count` ja mis on selle vaikeväärtus? Kirjuta README-sse.

??? question "Mõtle"
    Interface'i tüüp on **Agent**, aga agenti `proxmox2`-s pole. Miks ping ikkagi töötab? Mida ütleb see sulle selle kohta, kust Zabbix pingi saadab?

### A5 · Probleem, mis tekib ja laheneb ise

Selle sammu lõpuks oled näinud probleemi täit elutsüklit: tekib, on näha, laheneb.

Lisa samamoodi teine host **`proxmox3`**, template **ICMP Ping**, aga IP aadressi viimane number kirjuta **meelega valesti** (näiteks `.254`), nagu juhtub, kui IP kopeeritakse vanast tabelist.

??? question "Ennusta (README)"
    Mis juhtub? Kas Zabbix ütleb viga kohe, kui vajutad **Add**? Kui ei, siis millal ja kus?

Kontrolli serveri seest sama käsuga nagu A4-s: `docker compose exec zabbix-server fping <vale-IP>`. Mida see ütleb?

Ava **Monitoring → Problems** ([Problems](https://www.zabbix.com/documentation/7.0/en/manual/web_interface/frontend_sections/monitoring/problems)) ja oota 1–2 minutit.

??? success "Oodatav tulemus"

    Ilmub rida, kus **Host** on `proxmox3`, **Problem** on *Unavailable by ICMP ping* ja **Severity** on **High**. Veerus **Duration** loeb aeg üles.

    Sama nimekirja võib tulla ka rida **Zabbix server**: *Linux: Zabbix agent is not available*. See on oodatud: agenti veel pole (A3), selle paneme K4-s.

    Kohe ei tulnud, sest [trigger](https://www.zabbix.com/documentation/7.0/en/manual/config/triggers) ootab kolm järjestikust nurjunud pingi ([loengu §5](lecture.md#5-probleemi-elutsukkel)). Zabbix ei tea, et IP on vale: tema jaoks on see masin, mis ei vasta.

**Otsi manuaalist:** trigger'i tingimuse leiad **Data collection → Templates → ICMP Ping → Triggers**. Seal on avaldis funktsiooniga `max(...)`. Otsi manuaalist (PDF-is Ctrl+F `max(/host/key`, veebis [History functions](https://www.zabbix.com/documentation/7.0/en/manual/appendix/functions/history)), mida see funktsioon teeb, ja kirjuta README-sse ühe lausega, millal see trigger probleemi tekitab.

Paranda: **Data collection → Hosts → proxmox3**, pane õige IP, **Update**. Oota 1–2 minutit ja vaata **Monitoring → Problems**. Filtris vali **Show: History**.

??? success "Oodatav tulemus"

    Probleem on kadunud aktiivsete probleemide hulgast. History vaates on see olemas: **Status** on **RESOLVED** ([sündmused ja nende olekud](https://www.zabbix.com/documentation/7.0/en/manual/config/events)) ja näha on, kui kaua see kestis.

Zabbix hoiab kõike andmebaasis. Võta sealt tõend, et mõlemad hostid on olemas ja probleem tekkis ning lahenes. Oma arvutis repo kaustas:

```bash
ssh proxmox1 "cd ~/zabbix && docker compose exec -T postgres psql -U zabbix -c \"SELECT host FROM hosts WHERE host LIKE 'proxmox%' ORDER BY host;\" -c \"SELECT name, to_timestamp(clock) AS algas, to_timestamp(r_clock) AS lahenes FROM problem ORDER BY clock;\"" > logid/a5-andmebaas.txt
cat logid/a5-andmebaas.txt
```

??? success "Oodatav tulemus"

    Esimeses tabelis on `proxmox2` ja `proxmox3`. Teises on rida *Unavailable by ICMP ping*, kus on olemas nii `algas` kui ka `lahenes`. Kui `lahenes` on tühi, pole probleem veel lahenenud: kontrolli IP-d ja oota veel minut.

??? question "Mõtle"
    Sa pole kunagi andmebaasi midagi kirjutanud, ometi on seal sinu hostid ja probleem koos kellaaegadega. Kes need sinna kirjutas? Mis juhtub nende andmetega, kui teed `docker compose down`? Aga `docker compose down -v`?

## Esitamine

Kirjuta README-sse vastused ja ennustused, siis oma arvutis repo kaustas:

```bash
ls konf logid
git add README.md konf logid
git commit -m "Labor 2: Zabbix valvab"
git push
```

Mõne minuti pärast näed GitHubis **Actions** all tulemust. Punase kontrolli korral loe väljundit, paranda, commit, push.

??? note "Automaatkontroll (100 punkti)"

    | Kontroll | Punkte |
    |---|---|
    | K1. Failid olemas ja pole tühjad | 10 |
    | K2. `compose.yaml`: kolm teenust, Zabbix 7.0 kindla versiooniga, parool muutujast | 20 |
    | K3. `compose.yaml` käivitub ja veebiliides vastab (autograder käivitab selle ise) | 25 |
    | K4. `a2-compose-ps.txt`: kolm konteinerit `Up`, veebiliides pordil 8080 | 15 |
    | K5. `a5-andmebaas.txt`: `proxmox2`, `proxmox3` ja lahenenud probleem | 20 |
    | K6. `README.md`: ennustused ja vastused täidetud | 10 |

Kui lõpetad, jäta Zabbix käima: K3-s ja K4-s ehitame selle peale edasi. Kui mälu jääb väheks, peata see käsuga `docker compose stop`. **Ära kasuta `down -v`**, see kustutab kõik hostid.

## Lisaülesanded

**1. Teine piir.** Template *ICMP Ping* teeb probleemi ka siis, kui vastuse aeg on liiga pikk. Leia **Data collection → Templates → ICMP Ping → Triggers** alt, mis see piir on. Miks ei tekita sinu `proxmox2` seda probleemi?

**2. Kas server ise töötab?** Peata ainult server: `docker compose stop zabbix-server`. Värskenda veebiliidest ja vaata lehe allserva. Mida Zabbix ütleb? Kas `proxmox3` probleem tekiks sel ajal? Käivita server uuesti: `docker compose start zabbix-server`.

**3. Kolmas host.** Lisa host `proxmox1` (template **ICMP Ping**). Mida näitab selle vastuse aeg võrreldes `proxmox2`-ga ja miks?

**4. API.** Zabbixil on JSON-RPC API, mida kasutavad skriptid ja Ansible. Küsi versiooni ilma sisselogimiseta: `curl -s -X POST -H 'Content-Type: application/json-rpc' -d '{"jsonrpc":"2.0","method":"apiinfo.version","params":{},"id":1}' http://<proxmox1-IP>:8080/api_jsonrpc.php`. Loe [API juhendist](https://www.zabbix.com/documentation/7.0/en/manual/api), kuidas saada token ja küsida `host.get`.
