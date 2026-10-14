---
tags:
  - Labor
  - Monitooring
  - Logid
  - Linux
---

# Labor: masina päevik ja keskne logiserver

**Eeldused:** [loeng](lecture.md) loetud. Automatiseerimise kursusest: `ssh proxmox1`, `ssh proxmox2`, `ssh proxmox3` töötavad ilma paroolita (nädal 1), Ansible on sinu arvutis (nädalad 3-4). `journalctl`, `tail -f`, `systemctl` ja `nano` on tuttavad.

**Keskkond:** sinu arvuti (VS Code, terminal) ja kolm Proxmoxi sõlme (AlmaLinux). `rsyslog` ja `logrotate` on AlmaLinuxis vaikimisi olemas, midagi pole vaja paigaldada.

!!! abstract "Eesmärgid"
    Pärast laborit oskad:

    1. leida üles sama sündmuse nii journaldist kui ka rsyslogi failist;
    2. filtreerida logisid tõsiduse, teenuse ja aja järgi;
    3. kirjutada rsyslogi reegli, mis suunab sinu rakenduse logid eraldi faili;
    4. seadistada logrotate'i ja kontrollida, et pööramine töötab;
    5. seadistada keskse logiserveri ja saata sinna kahe masina logid;
    6. leida keskserverist turvasündmuse jäljed.

    **Mis valmib:** `proxmox1` võtab vastu `proxmox2` ja `proxmox3` logid ja hoiab neid masina kaupa eraldi. Sinu Classroomi repos on `README.md` vastustega ning kaustades `konf/` ja `logid/` tõendid. Automaatkontroll annab kuni 100 punkti.

---

## Eeltöö

Ava õpetaja antud GitHub Classroomi link ja võta ülesanne vastu. Sulle tehakse oma repo, nagu automatiseerimise kursusel. Klooni see oma arvutisse ja ava VS Code'is:

```bash
git clone <sinu-repo-url>
cd <sinu-repo>
code .
```

Repos on `README.md` (siia kirjutad laboris ennustused ja vastused, pealkirjad on juba olemas) ning tühjad kaustad `konf/` ja `logid/` (sinna kopeerid lõpus oma konfid ja väljundid, vt [Esitamine](#esitamine)).

Kontrolli, et kõik kolm sõlme vastavad (sama tsükkel nagu automatiseerimise nädalal 1):

```bash
for h in proxmox1 proxmox2 proxmox3; do
  ssh $h hostname
done
```

Pane kirja `proxmox1` IP-aadress, seda on osas B vaja. Sõlmed ise ei tea nime `proxmox1` (see on ainult sinu arvuti `~/.ssh/config`-is), seega räägivad nad omavahel IP kaudu:

```bash
ssh proxmox1 "hostname -I"
```

Esimene aadress (`192.168.35.x`) on õige.

---

## Osa A · Üks masin ja tema päevik

Kogu osa A töötad sõlmes `proxmox2`. Ava VS Code'is kaks terminali (`` Ctrl+Shift+` `` avab teise) ja logi mõlemas sisse:

```bash
ssh proxmox2
```

### A1. Kus päevik elab?

**Ennusta enne** ja kirjuta faili `README.md`: kas `proxmox2` päevik (journald) elab üle masina taaskäivituse või kaob see?

Kontrolli:

```bash
journalctl --list-boots | tail -3
```

Iga rida on üks käivitus. Kui ridu on mitu, hoiab journald logisid kettal ja need elavad üle taaskäivituse. Kui on ainult üks rida (`0`), hoitakse neid ainult mälus.

Vaata, kas rsyslog töötab ja kust ta oma kirjed saab:

```bash
systemctl is-active rsyslog
grep -n imjournal /etc/rsyslog.conf
```

Rida `module(load="imjournal" ...)` ongi joonise 1.3 nool journaldist rsyslogi (loeng, osa 2).

Vaata nüüd rsyslogi vaikimisi reegleid:

```bash
grep -v -E '^#|^$' /etc/rsyslog.conf | grep /var/log
```

Oodatav tulemus (AlmaLinux 9.8):

```text
*.info;mail.none;authpriv.none;cron.none action(type="omfile" file="/var/log/messages")
authpriv.* action(type="omfile" file="/var/log/secure")
mail.* action(type="omfile" file="/var/log/maillog" sync="on")
cron.* action(type="omfile" file="/var/log/cron")
uucp,news.crit action(type="omfile" file="/var/log/spooler")
local7.* action(type="omfile" file="/var/log/boot.log")
```

Iga rida on üks reegel: vasakul filter (päritolu.tõsidus), paremal tegevus. `action(type="omfile" file="...")` tähendab "kirjuta faili". Vanemates versioonides on paremal ainult faili tee (`/var/log/messages`), tähendus on sama.

**Mõtle:** Miks on reas `/var/log/messages` lisatud `authpriv.none`? Mis juhtuks, kui see puuduks?

### A2. Üks sündmus, kaks kohta

**Ennusta enne:** kui käivitad `logger`-i, kas rida jõuab journaldisse, faili `/var/log/messages` või mõlemasse?

Terminal 1, jälgi faili:

```bash
sudo tail -f /var/log/messages
```

Terminal 2, kirjuta päevikusse:

```bash
logger -t n01test "tere päevik"
```

`-t n01test` paneb kirjele programmi nimeks `n01test`, et see oleks lihtne üles leida. Terminal 1-sse ilmub rida kohe.

Nüüd leia sama rida journaldist (terminal 2):

```bash
journalctl -t n01test
```

Mõlemas kohas on sama sündmus. Vaata nüüd, mida journald selle kirje kohta veel teab:

```bash
journalctl -t n01test -o verbose -n 1
```

Väljundis on terve hulk välju. Leia need kaks:

```text
    PRIORITY=5
    SYSLOG_FACILITY=1
```

`PRIORITY=5` on tõsidus `notice` (loeng, tabel 1.2) ja `SYSLOG_FACILITY=1` on `user`. Need on joonise 1.2 "nähtamatud" osad. Tekstifailis neid ei näe, aga rsyslog kasutab neid reeglites.

Peata terminal 1-s `tail -f` (`Ctrl+C`).

✅ **Kontrollpunkt:** oskad sama `logger`-i rea üles leida nii `journalctl`-ist kui ka failist `/var/log/messages`. Kirjuta `README.md`-sse, kas ennustus läks täppi.

### A3. Turvasündmus

Tekita sündmus, mida turvalogi peaks nägema. **Oma arvutis** (mitte sõlmes!) proovi sisse logida kasutajaga, keda pole olemas:

```bash
ssh -o User=sissetungija -o PubkeyAuthentication=no proxmox2
```

Kui küsitakse parooli, sisesta suvaline tekst kolm korda. Kui sõlmes on paroolisisselogimine keelatud, saad kohe `Permission denied (publickey,...)`. Mõlemal juhul ühendus ebaõnnestub ja sõlm paneb katse kirja.

Tagasi `proxmox2` terminalis. Kus see katse nüüd on? Proovi kaht teed:

```bash
sudo journalctl -u sshd --since "5 min ago"
sudo grep "Invalid user" /var/log/secure
```

Esimene küsib journaldilt teenuse `sshd` kõiki kirjeid viimase 5 minuti kohta. Teine otsib rsyslogi failist.

Oodatav tulemus mõlemas:

```text
Oct 14 20:36:39 proxmox2 sshd-session[4133]: Invalid user sissetungija from 192.168.35.x port 49970
Oct 14 20:36:39 proxmox2 sshd-session[4133]: Connection closed by invalid user sissetungija 192.168.35.x port 49970 [preauth]
```

IP on sinu arvuti oma. Programmi nimi on uuemas OpenSSH-s `sshd-session`, vanemas `sshd`.

Proovi nüüd otsida kasutajanime järgi: `sudo grep sissetungija /var/log/secure`. Tulemusi on rohkem kui enne. Mis read on juurde tulnud ja miks? (Vihje: vaata, mis programm need kirjutas.)

**Mõtle:** Proovi `sudo grep "Invalid user" /var/log/messages`. Miks seal seda rida pole? (Vihje: A1 reeglid.)

### A4. Seire pilguga: vead ja hoiatused

Sinu töö pole lugeda kõiki ridu. Seire küsib: **"Kas midagi on valesti?"** Vasta sellele küsimusele käskudega, mida juba tunned, aga uute filtritega.

Kõik vead ja hullemad sellest käivitusest:

```bash
journalctl -p err -b
```

Mitu neid on?

```bash
journalctl -p err -b | wc -l
```

Hoiatused ja hullemad viimase tunni jooksul, ainult kokkuvõtlikult:

```bash
journalctl -p warning --since "1 hour ago" -o short
```

Kirjuta `README.md`-sse:

```markdown
## A4
- Vigu (err ja hullemad) sellest käivitusest: ...
- Kõige sagedasem viga (programm): ...
```

**Kui `journalctl -p err -b` on tühi:** see on hea uudis, masin on terve. Tekita endale viga: `logger -p user.err -t n01test "midagi läks katki"` ja kontrolli uuesti.

### A5. Sinu rakenduse reegel

Kujuta ette, et `proxmox2`-s jookseb e-pood, mis logib päritoluga `local0`. Tahad poe logid eraldi faili, et neid ei peaks `messages`-ist otsima.

**1. samm.** Loo reeglifail. Failid kaustas `/etc/rsyslog.d/` loetakse tähestiku järjekorras ja number ees määrab järjekorra:

```bash
sudo nano /etc/rsyslog.d/10-pood.conf
```

Sisu on üks rida. Kirjuta see **meelega veaga**, nagu kiirustades juhtub (`locla0`, mitte `local0`):

```text
locla0.*    /var/log/pood.log
```

**2. samm.** Kontrolli süntaksit **enne** taaskäivitamist. Vigane konf võib jätta reegli tööle panemata või halvemal juhul rsyslogi seisma panna, ja siis ei logi masin üldse midagi:

```bash
sudo rsyslogd -N1
```

Oodatav tulemus:

```text
rsyslogd: version 8.2510.0-2.el9, config validation run (level 1), master config /etc/rsyslog.conf
rsyslogd: unknown facility name "locla0" [v8.2510.0-2.el9]
```

`-N1` kontrollib konfi ilma rsyslogi puutumata ja ütleb täpselt, mis on valesti. Paranda failis `locla0` → `local0` ja kontrolli uuesti. Nüüd lõpeb väljund reaga `End of config validation run. Bye.` Siis:

```bash
sudo systemctl restart rsyslog
```

**3. samm.** Testi:

```bash
logger -p local0.info -t pood "tellimus 1001 vastu võetud"
sudo tail -3 /var/log/pood.log
```

Rida on uues failis. Aga vaata ka:

```bash
sudo grep "tellimus 1001" /var/log/messages
```

Rida on **ka** `messages`-is, sest vaikimisi reegel `*.info` püüab kõik kinni.

**4. samm.** Lisa reeglifaili teine rida, mis ütleb "kui kirje läks poe faili, siis rohkem seda edasi ei töödelda":

```text
local0.*    /var/log/pood.log
& stop
```

`&` tähendab "sama filter, mis eelmisel real" ja `stop` lõpetab selle kirje töötlemise. Kuna meie fail on `10-...`, loetakse see enne põhikonfi reegleid.

Kontrolli (`rsyslogd -N1`), taaskäivita ja testi uue numbriga (`tellimus 1002`). Nüüd peaks see olema ainult `pood.log`-is.

**5. samm.** Hoiatused eraldi. **Ennusta enne:** lisad reegli `local0.warning /var/log/pood-hoiatused.log` **enne** `local0.*` rida. Millisesse faili (või failidesse) lähevad need kolm kirjet?

```bash
logger -p local0.info    -t pood "tellimus 1003"
logger -p local0.warning -t pood "laos alla 5 toote"
logger -p local0.err     -t pood "makse ebaõnnestus"
```

Kirjuta ennustus `README.md`-sse, siis lisa reegel, kontrolli, taaskäivita ja testi. Reeglifail on nüüd:

```text
local0.warning    /var/log/pood-hoiatused.log
local0.*          /var/log/pood.log
& stop
```

✅ **Kontrollpunkt:** `pood-hoiatused.log`-is on kaks rida (warning ja err), `pood.log`-is kolm ja `messages`-is mitte ühtegi neist.

**Mõtle:** Miks läks `err` kirje ka hoiatuste faili, kuigi reeglis on kirjas `warning`?

### A6. Pööra logi

Poe logi kasvab. Seadista sellele logrotate.

**1. samm.** Loo fail:

```bash
sudo nano /etc/logrotate.d/pood
```

Alusta lühikese versiooniga:

```text
/var/log/pood.log /var/log/pood-hoiatused.log {
    size 10k
    rotate 3
    missingok
}
```

`size 10k` tähendab "pööra, kui fail on suurem kui 10 kilobaiti". Päriselus oleks see `daily` või `10M`, aga nii näed tulemust kohe.

**2. samm.** Proovikäik. `-d` (debug) näitab, mida logrotate **teeks**, aga ei tee midagi:

```bash
sudo logrotate -d /etc/logrotate.d/pood
```

Väljundis on rida `log does not need rotating`, sest fail on veel väike.

**3. samm.** Kirjuta logi täis. See tsükkel kirjutab 300 rida:

```bash
for i in $(seq 300); do logger -p local0.info -t pood "tellimus $i"; done
ls -lh /var/log/pood.log
```

**4. samm.** Pööra päriselt:

```bash
sudo logrotate -v /etc/logrotate.d/pood
ls -l /var/log/pood*
```

Nüüd on olemas `pood.log.1`. **Aga** kirjuta veel üks rida ja vaata, kuhu see läheb:

```bash
logger -p local0.info -t pood "pärast pööramist"
sudo tail -1 /var/log/pood.log
sudo tail -1 /var/log/pood.log.1
```

Oodatav tulemus: `tail ... pood.log` annab `No such file or directory` ja rida on hoopis failis `pood.log.1`. rsyslog kirjutab ikka vanasse faili. Ta hoiab faili lahti ega tea, et sellel on nüüd uus nimi (loeng, osa 4, küsimus 2).

**5. samm.** Korista enne parandamist. Kustuta pööratud failid ja **taaskäivita rsyslog**:

```bash
sudo rm -f /var/log/pood.log.*
sudo systemctl restart rsyslog
```

Miks taaskäivitus? Kui kustutad faili, mida rsyslog hoiab lahti, kirjutab ta edasi kustutatud faili. Kettal seda enam pole, aga ruumi võtab see ikka, kuni rsyslog faili sulgeb. Pärast taaskäivitust avab ta uue `pood.log`-i.

**6. samm.** Paranda konf: lisa pakkimine ja käsk, mis ütleb rsyslogile "ava failid uuesti":

```text
/var/log/pood.log /var/log/pood-hoiatused.log {
    size 10k
    rotate 3
    compress
    missingok
    notifempty
    postrotate
        /usr/bin/systemctl kill -s HUP rsyslog.service >/dev/null 2>&1 || true
    endscript
}
```

| Rida | Miks |
|---|---|
| `compress` | vanad failid pakitakse, `.gz` |
| `notifempty` | tühja faili ei pöörata |
| `postrotate` ... `endscript` | käsk pärast pööramist; `HUP` signaal käsib rsyslogil failid uuesti avada |

*Tabel 1. Logrotate'i lisaread*

Kirjuta jälle 300 rida, pööra ja kontrolli. Tee seda **neli korda**. **Ennusta enne:** mitu `pood.log.*` faili on lõpuks alles?

```bash
ls -l /var/log/pood*
```

Oodatav tulemus pärast neljandat korda:

```text
/var/log/pood-hoiatused.log  /var/log/pood.log  /var/log/pood.log.1.gz  /var/log/pood.log.2.gz  /var/log/pood.log.3.gz
```

Neljas kord lükkas kõige vanema faili välja (`rotate 3`). `pood-hoiatused.log` jäi pööramata, sest see on väiksem kui 10k.

Lõpuks kontrolli, kuhu uus rida läheb:

```bash
logger -p local0.info -t pood "pärast HUP-i"
sudo tail -1 /var/log/pood.log
```

✅ **Kontrollpunkt:** uus rida on `pood.log`-is, alles on kolm pakitud vana faili.

---

!!! info "Paus"
    Välju mõlemast SSH-sessioonist (`exit`). Pärast pausi töötad iseseisvalt ja kolme masinaga.

---

## Osa B · Logid ühte kohta

Osas A hoidis iga kirje oma masinas. Osas B teed `proxmox1`-st keskserveri ja saadad sinna `proxmox2` ja `proxmox3` logid. `proxmox2` seadistad käsitsi, `proxmox3` Ansiblega.

### B1. Keskserver kuulab

Logi sisse `proxmox1`-sse. Ehita konf kahe sammuga.

**1. samm: ainult kuulamine.**

```bash
sudo nano /etc/rsyslog.d/50-keskserver.conf
```

```text
module(load="imtcp")
input(type="imtcp" port="514")
```

`imtcp` on sisendmoodul ("input module"), mis võtab kirjeid vastu TCP kaudu.

Kontrolli (`sudo rsyslogd -N1`), taaskäivita ja vaata, kas port on lahti:

```bash
sudo ss -tlnp | grep 514
```

Oodatav tulemus: rida, kus `0.0.0.0:514` ja `rsyslogd`. Keskserver kuulab.

**Mõtle enne B2-te:** kui `proxmox2` saadab nüüd oma logid, kuhu need `proxmox1`-s jõuavad? (Vihje: A1 reeglid kehtivad kõigile kirjetele, ka võrgust tulnutele.) Kirjuta oma arvamus `README.md`-sse, kontrollime B2-s.

### B2. proxmox2 saadab

Logi sisse `proxmox2`-sse:

```bash
sudo nano /etc/rsyslog.d/90-keskserver.conf
```

Number `90` paneb selle reegli viimaseks, pärast sinu `10-pood.conf`-i. Asenda `PROXMOX1-IP` eeltöös kirja pandud aadressiga:

```text
*.* action(type="omfwd" target="PROXMOX1-IP" port="514" protocol="tcp"
           queue.type="LinkedList" queue.size="10000"
           action.resumeRetryCount="-1")
```

| Osa | Tähendus |
|---|---|
| `*.*` | kõik kirjed, iga päritolu ja tõsidus |
| `omfwd` | väljundmoodul, mis saadab edasi (forward) |
| `protocol="tcp"` | tähitud kiri (loeng, tabel 1.4) |
| `queue.type="LinkedList"` | järjekord mälus: kui keskserver ei vasta, kirjed ootavad |
| `action.resumeRetryCount="-1"` | proovi uuesti lõpmatuseni, ära loobu |

*Tabel 2. Saatmisreegli osad*

Kontrolli, taaskäivita ja saada test:

```bash
sudo rsyslogd -N1 && sudo systemctl restart rsyslog
logger -t n01test "tere keskserver, siin proxmox2"
```

Nüüd `proxmox1`-s:

```bash
sudo grep "siin proxmox2" /var/log/messages
```

Tõenäoliselt **ei leia midagi**. Keskserver kuulab, klient saadab, aga kohale ei jõua. Leia ise, kus see katkeb. Alusta kliendist (`proxmox2`): kas port 514 on `proxmox1`-s üldse kättesaadav?

```bash
timeout 3 bash -c '</dev/tcp/PROXMOX1-IP/514' && echo lahti || echo kinni
```

Bash proovib avada TCP-ühenduse. `nc`-d ei ole AlmaLinuxis vaikimisi olemas, aga see trikk töötab alati.

Oodatav tulemus:

```text
bash: connect: No route to host
kinni
```

Port on kinni, kuigi `ss` näitas, et rsyslog kuulab. Kes on kliendi ja serveri vahel? Vaata `proxmox1`-s:

```bash
sudo firewall-cmd --list-ports
```

Tühi rida: tulemüür ei luba ühtegi lisaporti. Ava 514/tcp:

```bash
sudo firewall-cmd --permanent --add-port=514/tcp
sudo firewall-cmd --reload
```

Kontrolli `proxmox2`-st uuesti (`lahti`). Nüüd oota kuni minut ja otsi `proxmox1`-s uuesti:

```bash
sudo grep "siin proxmox2" /var/log/messages
```

Rida jõudis kohale, **kuigi saatsid selle siis, kui port oli kinni**. Klient hoidis seda järjekorras (`queue.type`) ja proovis uuesti (`resumeRetryCount`), umbes iga 30 sekundi järel.

**Kui `firewall-cmd` ütleb `FirewallD is not running`:** tulemüür on sõlmes väljas, rida jõudis kohe kohale ja seda viga sa ei näe. Loe ülejäänu siiski läbi, kooli võrgus on tulemüür tavaliselt sees.

Rida on olemas, aga **segamini** `proxmox1` enda logidega. Kolme masina puhul on see segadus. Vastus B1 küsimusele: võrgust tulnud kirjed käivad läbi samade vaikimisi reeglite.

<figure markdown="span">
  ![proxmox1 failis messages on proxmox1 enda read ja proxmox2-st tulnud read segamini](../images/n01_keskserver_segamini.png)
  <figcaption>Joonis 1.1. Oodatav tulemus: `proxmox1` faili `/var/log/messages` lõpus on read kahe erineva masinanimega.</figcaption>
</figure>
<!-- TODO Maria: ekraanipilt proxmox1-st, `sudo tail -8 /var/log/messages` pärast B2 testi; näha kaks erinevat hostinime. -->

### B3. Iga masin oma kausta

Paranda `proxmox1` konf nii, et võrgust tulnud kirjed lähevad **eraldi reeglistikku** ja sealt masina ja programmi järgi oma faili.

Ehita seda tükkhaaval. Kõigepealt mall, mis ütleb, mis nimega fail tehakse. `%HOSTNAME%` ja `%PROGRAMNAME%` asenduvad iga kirje puhul selle kirje väärtustega:

```text
template(name="MasinaKaupa" type="string"
         string="/var/log/remote/%HOSTNAME%/%PROGRAMNAME%.log")
```

Siis reeglistik (ruleset), mis kirjutab malli järgi faili:

```text
ruleset(name="kaugelt") {
    action(type="omfile" dynaFile="MasinaKaupa")
}
```

`dynaFile` tähendab, et faili nimi arvutatakse iga kirje jaoks mallist.

Lõpuks seo sisend reeglistikuga. Muuda olemasolevat `input` rida:

```text
input(type="imtcp" port="514" ruleset="kaugelt")
```

Pane kolm tükki faili `/etc/rsyslog.d/50-keskserver.conf` õiges järjekorras: `module`, `template`, `ruleset`, `input`. Kontrolli, taaskäivita.

Testi `proxmox2`-st uuesti (`logger -t n01test "nüüd oma kausta"`) ja vaata `proxmox1`-s:

```bash
sudo ls -R /var/log/remote/
sudo cat /var/log/remote/proxmox2/n01test.log
```

**Kui faili kohe ei tule:** sa taaskäivitasid keskserveri ja klient ühendub uuesti alles järgmisel katsel, kuni 30 sekundi pärast. Oota minut ja kontrolli uuesti. Kirje ei kao, see on kliendi järjekorras.

✅ **Kontrollpunkt:** kaustas `/var/log/remote/proxmox2/` on fail `n01test.log` sinu testreaga ja `messages`-isse uusi `proxmox2` ridu enam ei tule.

**Mõtle:** Saada `proxmox2`-st poe kirje: `logger -p local0.info -t pood "tellimus 2001"`. Kas see jõuab keskserverisse? Miks? (Vihje: A5 4. samm ja failide järjekord kaustas `/etc/rsyslog.d/`.) Parandus on lisaülesanne 2.

**Kui kaust on tühi:** vaata `sudo journalctl -u rsyslog -n 20` (`proxmox1`). Kui näed `Permission denied`, kontrolli, kas kirjutasid tee täpselt `/var/log/remote/...` (SELinux lubab rsyslogil kirjutada ainult `/var/log` alla).

### B4. proxmox3 Ansiblega

`proxmox3` vajab täpselt sama faili, mis `proxmox2`-l. Käsitsi kopeerimise asemel kasuta Ansiblet, nagu automatiseerimise kursusel.

Too fail oma arvutisse, otse repo kausta `konf/` (see on ka esitamise tõend):

```bash
scp proxmox2:/etc/rsyslog.d/90-keskserver.conf konf/
```

Saada see `proxmox3`-sse ja taaskäivita rsyslog. Kirjuta kaks Ansible ad-hoc käsku ise. Vajad mooduleid `ansible.builtin.copy` ja `ansible.builtin.service`, `-b` (sudo) ja inventory't `-i proxmox3,`. Meenuta automatiseerimise nädalat 3.

??? tip "Vihje, kui jääd kinni"
    ```bash
    ansible all -i proxmox3, -b -m ansible.builtin.copy \
      -a "src=konf/90-keskserver.conf dest=/etc/rsyslog.d/90-keskserver.conf"
    ansible all -i proxmox3, -b -m ansible.builtin.service \
      -a "name=rsyslog state=restarted"
    ```

Testi: `ssh proxmox3 'logger -t n01test "siin proxmox3"'` ja kontrolli `proxmox1`-s, kas tekkis kaust `/var/log/remote/proxmox3/`.

**Mõtle:** Mis on ad-hoc käsu puudus võrreldes playbookiga, kui homme tuleb neljas masin? Kuidas teeksid selle playbookiga, mis taaskäivitab rsyslogi ainult siis, kui fail muutus? (Automatiseerimise nädal 4, handlerid.)

### B5. Intsident

Nüüd kasutad keskserverit nii, nagu seda päriselt kasutatakse.

**Sinu arvutis** proovi `proxmox3`-sse sisse logida kolme erineva olematu kasutajaga (iga kord sisesta suvaline parool):

```bash
for u in admin root2 test; do
  ssh -o User=$u -o PubkeyAuthentication=no -o ConnectTimeout=5 proxmox3
done
```

Kujuta ette, et ründaja tühjendas järgmisena `proxmox3`-s turvalogi. Tee seda:

```bash
ssh proxmox3 "sudo truncate -s 0 /var/log/secure"
ssh proxmox3 "sudo grep -c 'Invalid user' /var/log/secure"
```

`proxmox3` väidab, et midagi ei juhtunud (0). Leia `proxmox1`-st, mis tegelikult juhtus:

```bash
sudo grep -rh "Invalid user" /var/log/remote/proxmox3/
```

`-r` otsib kõigist kausta failidest. Miks mitte `sudo grep ... /var/log/remote/proxmox3/*.log`? rsyslog loob kaustad õigustega `700` (ainult root). `*` laiendab sinu enda shell **enne** `sudo`-t ja sina kausta sisse ei näe, nii et grep saab failinime asemel tärni.

Kirjuta `README.md`-sse:

```markdown
## B5 intsident
- Mitu katset: ...
- Mis kasutajanimed: ...
- Mis IP-lt: ...
- Mis kell esimene ja viimane: ...
- Käsk, millega leidsin: ...
```

✅ **Kontrollpunkt:** leidsid kõik kolm kasutajanime keskserverist, kuigi `proxmox3` enda logi oli tühi.

### B6. Keskserveri logid pöörlevad ka

Keskserver kogub kahe masina logisid, nii et tema kettal kasvavad logid kõige kiiremini. Seadista `proxmox1`-s logrotate failidele `/var/log/remote/*/*.log`. Kasuta A6 faili mallina, aga mõtle ise läbi:

- kas pöörata ajaga või suuruse järgi?
- mitu vana faili hoida, kui turvasündmus avastatakse sageli alles nädalate pärast?

Kontrolli `sudo logrotate -d /etc/logrotate.d/remote`-ga, et logrotate leiab mõlema masina failid. Kirjuta `README.md`-sse oma valikud ja ühe lausega põhjendus.

✅ **Kontrollpunkt:** `logrotate -d` väljundis on näha failid nii `proxmox2` kui ka `proxmox3` kaustast.

---

## Esitamine

Kõik tõendid on sõlmedes. Kopeeri need oma repo kausta. Käivita **oma arvutis, repo juurkaustas**:

```bash
scp proxmox2:/etc/rsyslog.d/10-pood.conf      konf/
scp proxmox2:/etc/logrotate.d/pood            konf/pood.logrotate
scp proxmox1:/etc/rsyslog.d/50-keskserver.conf konf/
scp proxmox1:/etc/logrotate.d/remote          konf/remote.logrotate
```

`konf/90-keskserver.conf` on sul B4-st juba olemas.

Väljundid:

```bash
ssh proxmox2 "sudo grep 'Invalid user' /var/log/secure"   > logid/a3-secure.txt
ssh proxmox2 "ls /var/log/pood*"                          > logid/a6-pood.txt
ssh proxmox1 "sudo ls -R /var/log/remote"                 > logid/b3-remote.txt
ssh proxmox1 "sudo grep -rh 'Invalid user' /var/log/remote/proxmox3/" > logid/b5-intsident.txt
```

Kontrolli, et ükski fail pole tühi (`wc -l logid/* konf/*`), siis:

```bash
git add README.md konf logid
git commit -m "Labor 1: keskne logiserver"
git push
```

Repos on automaatkontroll. Mõne minuti pärast näed GitHubis **Actions** all tulemust ja punkte. Kui mõni kontroll on punane, loe selle väljundit, paranda, tee uus commit ja push. Esitada võid nii mitu korda, kui vaja.

| Kontroll | Punkte |
|---|---|
| Kõik failid olemas ja pole tühjad | 10 |
| `10-pood.conf`: hoiatuste reegel enne `local0.*` rida, `& stop` | 15 |
| `pood.logrotate`: `rotate 3`, `compress`, `postrotate` HUP-iga | 15 |
| `50-keskserver.conf`: `imtcp`, mall `%HOSTNAME%`-iga, `ruleset`, `input` seotud reeglistikuga | 15 |
| `90-keskserver.conf`: `omfwd`, TCP, järjekord, lõputu kordus | 10 |
| `a6-pood.txt`: kolm pakitud vana faili, neljandat pole | 10 |
| `b3-remote.txt`: kaustad `proxmox2` ja `proxmox3` | 10 |
| `b5-intsident.txt`: vähemalt kolm erinevat olematut kasutajat | 10 |
| `README.md`: ennustused ja vastused täidetud | 5 |

*Tabel 3. Automaatkontroll*

---

## Kokkuvõte

Osas A leidsid sama sündmuse nii journaldist kui ka rsyslogi failist, filtreerisid tõsiduse järgi, kirjutasid oma rakendusele reegli ja nägid, miks logrotate vajab `postrotate` käsku. Osas B said `proxmox1`-st keskserveri: kaks masinat saadavad sinna oma logid TCP kaudu ja keskserver hoiab neid masina ja programmi kaupa eraldi. Intsidendis nägid, miks: masina enda logi oli tühjendatud, aga koopia keskserveris jäi alles.

Järgmisel kohtumisel tuleb keskne jälgimissüsteem, mis kogub lisaks logidele ka numbreid.

## ✅ Lõpukontroll

- [ ] `journalctl -t n01test` ja `/var/log/messages` näitavad sama testrida (`proxmox2`)
- [ ] `/etc/rsyslog.d/10-pood.conf` suunab `local0` kirjed `pood.log`-i ja hoiatused `pood-hoiatused.log`-i ning `messages`-isse neid ei jõua
- [ ] `/etc/logrotate.d/pood` pöörab, pakib ja rsyslog kirjutab pärast pööramist uude faili
- [ ] `proxmox1`-s on kaustad `/var/log/remote/proxmox2/` ja `/var/log/remote/proxmox3/`
- [ ] B5: leidsid keskserverist kolm sissetungi katset, kuigi `proxmox3` enda turvalogi oli tühi
- [ ] `README.md`-s on ennustused (A1, A2, A5, A6) ja vastused (A4, B5, B6)
- [ ] repo on push'itud ja Actions näitab 100 punkti

---

## Lisaülesanded

Kergemad on eespool. Tee nii palju, kui jõuad.

**1. Kui palju päevik võtab?** Uuri `proxmox2`-s, kui palju kettaruumi journald kasutab, ja leia, kuidas seda piirata.

??? success "Lahendus"
    ```bash
    journalctl --disk-usage
    ```
    Piirang käib failis `/etc/systemd/journald.conf` (või `/etc/systemd/journald.conf.d/*.conf`) reaga `SystemMaxUse=200M`, siis `sudo systemctl restart systemd-journald`. journald kustutab ise vanemaid kirjeid, kui piir täitub. See on journaldi oma logrotate.

**2. Poe logid keskserverisse.** B3 "Mõtle" küsimuses nägid, et `local0` kirjed `proxmox2`-st keskserverisse ei jõua. Paranda nii, et jõuavad, aga `proxmox2` enda `messages`-isse ikka ei lähe.

??? success "Lahendus"
    `10-pood.conf` reegel `& stop` lõpetab kirje töötlemise enne, kui rsyslog jõuab faili `90-keskserver.conf` juurde. Failid loetakse tähestiku järjekorras, seega piisab, kui saatmisreegel loetakse enne poe reeglit:
    ```bash
    sudo mv /etc/rsyslog.d/90-keskserver.conf /etc/rsyslog.d/05-keskserver.conf
    sudo rsyslogd -N1 && sudo systemctl restart rsyslog
    logger -p local0.info -t pood "tellimus 2002"
    ```
    `proxmox1`-s: `sudo cat /var/log/remote/proxmox2/pood.log`.

**3. Turvalogid eraldi.** Muuda keskserveri reeglistikku nii, et kõigi masinate `authpriv` kirjed lähevad lisaks ühte faili `/var/log/remote/turvalogi.log`. Nii näeb kõigi masinate sisselogimisi ühest kohast.

??? success "Lahendus"
    Reeglistiku sees saab kasutada sama `päritolu.tõsidus` filtrit:
    ```text
    ruleset(name="kaugelt") {
        authpriv.*  action(type="omfile" file="/var/log/remote/turvalogi.log")
        action(type="omfile" dynaFile="MasinaKaupa")
    }
    ```

**4. Kas UDP kaotab?** Lisa `proxmox1`-le UDP sisend (`imudp`, port 514/udp, tulemüüris ka avada). Saada `proxmox2`-st 10 000 rida UDP kaudu otse `logger`-iga (`logger -n PROXMOX1-IP -P 514 -d`) ja loe, mitu kohale jõudis. Korda TCP-ga (`-T`). Kas vahe on? Mis siis, kui saadad kümme korda kiiremini?

**5. Kui keskserver on maas.** Peata `proxmox1`-s rsyslog (`sudo systemctl stop rsyslog`). Saada `proxmox2`-st kolm rida `logger`-iga. Käivita rsyslog uuesti. **Ennusta enne:** kas need kolm rida jõuavad kohale? Kontrolli, aga oota kuni minut: klient proovib uuesti umbes iga 30 sekundi järel. Mis oli selles osa `queue.type` ja `resumeRetryCount`?

**6. JSON-vormingus kirjed.** Järgmistel kohtumistel lähevad logid otsingusüsteemidesse, mis eelistavad JSON-it. Tee keskserverisse teine mall, mis kirjutab iga kirje ühe JSON-reana faili `/var/log/remote/koik.json`.

??? success "Lahendus"
    ```text
    template(name="Json" type="list") {
        constant(value="{")
        property(name="timereported" dateFormat="rfc3339" format="jsonf" outname="aeg")
        constant(value=",")
        property(name="hostname" format="jsonf" outname="masin")
        constant(value=",")
        property(name="programname" format="jsonf" outname="programm")
        constant(value=",")
        property(name="syslogseverity-text" format="jsonf" outname="tosidus")
        constant(value=",")
        property(name="msg" format="jsonf" outname="sonum")
        constant(value="}\n")
    }
    ```
    ja reeglistikku: `action(type="omfile" file="/var/log/remote/koik.json" template="Json")`. Kontrolli: `sudo tail -1 /var/log/remote/koik.json | python3 -m json.tool`.

**7. Hoiatus mitme ebaõnnestunud sisselogimise korral.** Kirjuta `proxmox1`-s skript, mis loeb `turvalogi.log`-ist (ülesanne 3) viimase 5 minuti `Invalid user` read ja kui neid on üle 5 ühelt IP-lt, kirjutab `logger -p authpriv.alert` hoiatuse. Käivita see iga minut `systemd` timeriga. See on väike sissetungituvastus, mille N12 teeb Wazuh päriselt.

**8. Krüpteeritud saatmine.** Seadista `proxmox2` ja `proxmox1` vahel TLS (port 6514, rsyslogi `gtls` draiver, isesigneeritud sertifikaat). Tõesta `tcpdump`-iga, et port 514-l sõnum oli loetav ja 6514-l enam mitte. Juhend: [rsyslogi dokumentatsioon](https://docs.rsyslog.com/doc/), otsingusõna "TLS".

**9. Päris raske: journald ilma rsyslogita.** systemd-l on oma keskne logimine (`systemd-journal-remote` ja `systemd-journal-upload`). Seadista see `proxmox3` ja `proxmox1` vahel kõrvuti rsyslogiga. Võrdle: mis on parem, mis halvem? Millal valiksid kumma?

---

## Veaotsing

| Probleem | Põhjus | Lahendus |
|---|---|---|
| `rsyslogd -N1` annab vea | trükiviga konfis | veateates on fail ja rea number |
| Pärast restarti ei logi masin midagi | vigane konf, rsyslog ei käivitunud | `systemctl status rsyslog`, `journalctl -u rsyslog -n 20` |
| `pood.log` jääb tühjaks pärast pööramist | `postrotate` puudub, rsyslog kirjutab vanasse faili | A6 5. samm |
| `ss -tlnp` ei näita porti 514 | `imtcp` moodul pole laetud | `module(load="imtcp")` peab olema enne `input` rida |
| `proxmox1`-sse ei jõua midagi | tulemüür | `sudo firewall-cmd --list-ports` (`proxmox1`) |
| Ühendus ikka ei tööta | vale IP või port kinni | `proxmox2`-st: `timeout 3 bash -c '</dev/tcp/PROXMOX1-IP/514' && echo lahti` |
| `/var/log/remote/` on tühi, `journalctl` näitab `Permission denied` | vale tee, SELinux | tee peab algama `/var/log/` |
| Kaustanimi on IP, mitte `proxmox2` | sõlme hostinimi pole seatud | automatiseerimise nädal 1: `hostnamectl set-hostname` |
| `ssh -o User=...` ei küsi parooli | paroolisisselogimine on keelatud | normaalne, `Invalid user` kirje tekib siiski |
| `ssh -o User=...` logib sisse sinu tavakasutajana, `Invalid user` kirjet ei teki | `~/.ssh/config`-is on `ControlMaster`, ssh kasutab olemasolevat ühendust | lisa käsule `-o ControlPath=none` |
