---
tags:
  - Labor
  - Monitooring
  - Logid
  - Linux
---

# Labor: öövahetus

**Eeldused:** [loeng](lecture.md) loetud. Automatiseerimise kursusest: `ssh proxmox1`, `ssh proxmox2`, `ssh proxmox3` töötavad ilma paroolita (nädal 1), Ansible on sinu arvutis (nädalad 3-4: ad-hoc, playbook, handlerid). `journalctl`, `tail -f`, `grep`, `systemctl` ja `nano` on tuttavad.

**Keskkond:** sinu arvuti (VS Code, terminal, Classroomi repo) ja kolm Proxmoxi sõlme (AlmaLinux).

!!! example "Näidisstsenaarium"
    Kati e-pood kasvas. Nüüd on kolm serverit: `proxmox1`, `proxmox2` ja `proxmox3`. Sina oled uus öövahetuse administraator. Esimese öö plaan on lihtne: et järgmine kord, kui keegi küsib "mis juhtus kell 03:12?", oleks vastus olemas. Ka siis, kui server ise on maas või keegi on jäljed kustutanud.

    Esimene pool öövahetusest läheb ühe masina tundmaõppimisele. Teine pool on päris töö. Ole valvel: öö jooksul võib juhtuda asju, mida sina ei teinud.

!!! abstract "Eesmärgid"
    Pärast laborit oskad:

    1. lugeda üht logirida kolmest kohast (rsyslogi fail, journald, auditi logi) ja öelda, mis on iga väli;
    2. selgitada, kes tohib logisid lugeda, ja anda ligipääs ilma sudota;
    3. seadistada püsiva journali, rsyslogi reegli ja logrotate'i;
    4. seadistada auditd, mis näitab, **kes** logikonfi muutis või logi tühjendas;
    5. seadistada keskse logiserveri ja saata sinna kahe masina logid, ühe neist Ansible playbookiga;
    6. leida 50 000 reaga logist vastus mõne sekundiga: filtreeri, loenda, vaata.

    **Mis valmib:** `proxmox1` kogub `proxmox2` ja `proxmox3` logisid ja iga masin jälgib auditiga oma logikonfi. Classroomi repos on vastused, konfid ja tõendid. Automaatkontroll annab kuni 100 punkti, laboritahvel näitab edenemist jooksvalt.

!!! info "Kaks terminali"
    Peaaegu igas sammus on kaks terminali kõrvuti (VS Code: `` Ctrl+Shift+` `` avab teise, paremklõps → *Split Terminal*). **Terminal 1 vaatab** (`tail -f`, `journalctl -f`), **terminal 2 teeb** (tekitab sündmuse). Nii näed oma silmaga, et sündmus jõudis logisse.

---

## Eeltöö

Ava õpetaja antud GitHub Classroomi link ja võta ülesanne vastu. Klooni repo ja ava see VS Code'is:

```bash
git clone <sinu-repo-url>
cd <sinu-repo>
code .
```

Repos on `README.md` (ennustused ja vastused, pealkirjad on olemas), tühjad kaustad `konf/` ja `logid/` ning `tooriistad/tee-suur-logi.sh` (osa B).

Kontrolli, et kõik kolm sõlme vastavad:

```bash
for h in proxmox1 proxmox2 proxmox3; do
  ssh $h hostname
done
```

Kontrolli, et logimise tööriistad on olemas ja käivad. Tavapaigalduses need on, aga sõlm võib olla tehtud minimaalsest image'ist. Ära oleta, kontrolli. Kõigepealt ühes sõlmes käsitsi:

```bash
ssh proxmox2 "rpm -q rsyslog logrotate audit; systemctl is-active rsyslog auditd; systemctl list-timers logrotate.timer --no-pager"
```

`rsyslog` ja `auditd` on teenused, mis töötavad kogu aeg. `logrotate` ei ole teenus: selle käivitab kord ööpäevas taimer (`logrotate.timer`, veerg `NEXT`).

Nüüd kõik kolm korraga Ansiblega:

```bash
ansible all -i proxmox1,proxmox2,proxmox3, -b -m ansible.builtin.package -a "name=rsyslog,logrotate,audit state=present"
ansible all -i proxmox1,proxmox2,proxmox3, -b -m ansible.builtin.service -a "name=rsyslog state=started enabled=true"
```

| Osa | Tähendus |
|---|---|
| `-i proxmox1,proxmox2,proxmox3,` | inventory käsureal. **Lõpu koma on vajalik**, muidu otsib Ansible sellenimelist faili |
| `-b` | `become`, ehk sudo |
| `state=present` / `state=started enabled=true` | "peab olema paigaldatud" / "peab käima ka pärast taaskäivitust" |

*Tabel 1. Eeltöö Ansible käskude osad*

Oodatav tulemus: iga sõlm vastab `SUCCESS` (oli olemas) või `CHANGED` (Ansible paigaldas). `FAILED`-it ei tohi olla.

Pane kirja `proxmox1` IP-aadress. Sõlmed ei tea nime `proxmox1` (see on ainult sinu `~/.ssh/config`-is), omavahel räägivad nad IP kaudu:

```bash
ssh proxmox1 "hostname -I"
```

Esimene aadress (`192.168.35.x`) on õige.

---

## Osa A · Õpi masin tundma

Kogu osa A töötad sõlmes `proxmox2`. Ava kaks terminali, mõlemas `ssh proxmox2`.

### A1. Üks rida, kolm logi

**Ennusta enne** ja kirjuta `README.md`-sse: kui käivitad `logger`-i, kas rida jõuab journaldisse, faili `/var/log/messages` või mõlemasse?

Terminal 1:

```bash
sudo tail -f /var/log/messages
```

Terminal 2:

```bash
logger -t n01test "tere logi"
```

Terminal 1-sse ilmub kohe:

```text
Oct 14 20:26:20 proxmox2 n01test[4005]: tere logi
```

| Väli | Väärtus | Tähendus |
|---|---|---|
| aeg | `Oct 14 20:26:20` | millal (aastat ei ole!) |
| masin | `proxmox2` | kus; keskserveris ainus viis masinaid eristada |
| programm ja PID | `n01test[4005]` | kes kirjutas, mis protsessi number |
| sõnum | `tere logi` | vaba tekst programmi enda sõnastuses |

*Tabel 2. syslogi rea väljad*

Peata `tail` (`Ctrl+C`). Sama sündmus journaldis koos kõigi väljadega:

```bash
journalctl -t n01test -o verbose -n 1
```

Leia väljundist:

```text
    PRIORITY=5
    SYSLOG_FACILITY=1
    _HOSTNAME=proxmox2
    _PID=4005
```

`PRIORITY=5` on tõsidus `notice`, `SYSLOG_FACILITY=1` on päritolu `user` (loeng, tabel 1.3). Tekstireal neid pole, aga reeglid kasutavad neid. `_` algusega väljad lisas journald ise ja programm ei saa neid võltsida.

Kolmas on auditi logi. Seal ei ole programmide sõnumid, vaid tuuma tähelepanekud: kes mida tegi.

```bash
sudo tail -1 /var/log/audit/audit.log
```

```text
type=USER_CMD msg=audit(1792002876.234:3181): pid=11633 uid=501 auid=501 ses=5 ... cmd=7461696C202D31... exe="/usr/bin/sudo" res=success
```

See on sinu enda `sudo tail`. Inimesele loetavaks teeb selle `ausearch -i`:

```bash
sudo ausearch -m USER_CMD -i --start recent | tail -1
```

| Väli | Tähendus |
|---|---|
| `type=USER_CMD` | sündmuse liik (siin: `sudo`-ga käivitatud käsk) |
| `msg=audit(1792002876.234:3181)` | aeg sekundites alates 1970 ja järjekorranumber |
| `uid` | kelle õigustega käsk jooksis |
| `auid` | **kes algselt sisse logis**; ei muutu ka `sudo` järel |
| `exe`, `cmd` | programm ja käsk (`cmd` on kuueteistkümnendkoodis, `-i` teeb loetavaks) |
| `res` | õnnestus või mitte |

*Tabel 3. Auditi rea olulisemad väljad*

✅ **Kontrollpunkt:** oskad sama rea leida failist ja journaldist ning tead, mille poolest auditi logi neist erineb.

### A2. Kes tohib lugeda?

**Ennusta enne:** kas tavakasutaja saab lugeda `/var/log/secure`-t? Aga journaldit?

```bash
ls -l /var/log/messages /var/log/secure /var/log/cron
ls -ld /var/log/audit
cat /var/log/secure
```

```text
-rw-------. 1 root root   1200 Oct 14 21:32 /var/log/cron
-rw-------. 1 root root 369778 Oct 14 21:33 /var/log/messages
-rw-------. 1 root root 203740 Oct 14 21:33 /var/log/secure
drwx------. 2 root root 23 Aug 10 08:04 /var/log/audit
cat: /var/log/secure: Permission denied
```

AlmaLinuxis loeb tekstilogisid ainult root (`600`). Logis on IP-d, kasutajanimed ja vahel asju, mida seal olla ei tohiks (nt parool, mille keegi kirjutas kogemata kasutajanime lahtrisse).

journald jagab lugemisõigust gruppide kaudu. Tee proovikasutaja:

```bash
sudo useradd -m praktikant
sudo -u praktikant journalctl -n 3
```

```text
No journal files were opened due to insufficient permissions.
```

Lisa ta gruppi `systemd-journal` ja proovi uuesti:

```bash
sudo usermod -aG systemd-journal praktikant
sudo -u praktikant journalctl -n 3
sudo -u praktikant cat /var/log/secure
```

Nüüd näeb praktikant journalit, aga `secure` on ikka keelatud. Nii saab kolleeg veaotsingu jaoks ligipääsu ilma `sudo`-ta ja ilma turvalogita.

**Mõtle:** Miks on parem lisada kolleeg gruppi `systemd-journal` kui anda talle `sudo`? Kirjuta üks lause `README.md`-sse.

### A3. Journal, mis ei unusta

**Ennusta enne:** kas `proxmox2` journal elab üle taaskäivituse?

```bash
journalctl --list-boots
ls -ld /var/log/journal
```

Kui `/var/log/journal` kausta pole, hoiab journald journalit ainult mälus ja **taaskäivitusel kaob kõik**. Kati 03:12 lugu (loeng, osa 1) oleks siis jäänud lahendamata.

Tee journal püsivaks:

```bash
sudo mkdir -p /var/log/journal
sudo systemd-tmpfiles --create --prefix /var/log/journal
sudo journalctl --flush
ls -ld /var/log/journal
```

`systemd-tmpfiles` paneb kaustale õiged õigused (A2), `--flush` kirjutab mälus olnud journali kettale.

```text
drwxr-sr-x+ 3 root systemd-journal 46 Oct 14 21:34 /var/log/journal
```

`+` tähendab lisaõigusi (ACL): `getfacl /var/log/journal` näitab, et lugeda tohivad ka `wheel` ja `adm`.

Nüüd tõesta. Taaskäivita (terminal 2): `sudo reboot`. Oota pool minutit, logi sisse ja vaata `journalctl --list-boots`. Ridu on vähemalt kaks. Salvesta tõend, oma arvutis repo kaustas:

```bash
ssh proxmox2 "journalctl --list-boots" > logid/a3-boots.txt
```

✅ **Kontrollpunkt:** `logid/a3-boots.txt`-is on vähemalt kaks käivitust.

### A4. Keegi koputab uksele

Terminal 1:

```bash
sudo tail -f /var/log/secure
```

Terminal 2 on nüüd **sinu arvutis**. Proovi sisse logida kasutajaga, keda pole:

```bash
ssh -o User=sissetungija -o PubkeyAuthentication=no proxmox2
```

Kui küsitakse parooli, sisesta kolm korda suvaline tekst. Kui paroolisisselogimine on keelatud, saad kohe `Permission denied`. Mõlemal juhul ilmub terminal 1-sse:

```text
Oct 14 20:36:39 proxmox2 sshd-session[4133]: Invalid user sissetungija from 192.168.35.x port 49970
Oct 14 20:36:39 proxmox2 sshd-session[4133]: Connection closed by invalid user sissetungija 192.168.35.x port 49970 [preauth]
```

IP on sinu arvuti oma. Programm on uuemas OpenSSH-s `sshd-session`, vanemas `sshd`.

Peata `tail`. Seire ei loe kõiki ridu, vaid küsib. Proovi:

```bash
sudo journalctl -u sshd --since "10 min ago"         # üks teenus, ajavahemik
journalctl -p err -b                                  # vead ja hullemad sellest käivitusest
journalctl -p warning --since "1 hour ago" | wc -l     # mitu hoiatust viimase tunni jooksul
```

Kõik logid ei ole tekstifailid. Sisselogimiste ajalugu hoitakse kahendfailides `/var/log/wtmp` (õnnestunud) ja `/var/log/btmp` (ebaõnnestunud). `cat` neist midagi loetavat ei näita, nende jaoks on oma käsud:

```bash
last -n 5            # kes logis sisse, kust, kui kaua oli
sudo lastb -w -n 5   # ebaõnnestunud katsed; -w näitab pika kasutajanime täies pikkuses
```

```text
sissetungija ssh:notty    192.168.35.x     Wed Oct 14 20:36 - 20:36  (00:00)
```

**Mõtle:** `sudo grep "Invalid user" /var/log/messages` ei leia midagi. Miks? (Vastus on A5 alguses.)

Kirjuta `README.md`-sse: mitu viga (`err` ja hullemad) on sellest käivitusest ja mis programm neid kõige rohkem kirjutas.

### A5. E-poe enda logi

Vaata, mis reeglid rsyslogil juba on:

```bash
grep -v -E '^#|^$' /etc/rsyslog.conf | grep /var/log
```

```text
*.info;mail.none;authpriv.none;cron.none action(type="omfile" file="/var/log/messages")
authpriv.* action(type="omfile" file="/var/log/secure")
mail.* action(type="omfile" file="/var/log/maillog" sync="on")
cron.* action(type="omfile" file="/var/log/cron")
uucp,news.crit action(type="omfile" file="/var/log/spooler")
local7.* action(type="omfile" file="/var/log/boot.log")
```

Vasakul filter (päritolu.tõsidus), paremal tegevus. Vanemates versioonides on paremal ainult faili tee. A4 vastus: `authpriv.none`.

E-pood logib päritoluga `local0`. Tahad poe logid eraldi faili.

**1. samm.** Loo `/etc/rsyslog.d/10-pood.conf` (failid loetakse tähestiku järjekorras). Kirjuta **meelega veaga**, nagu kiirustades juhtub:

```text
locla0.*    /var/log/pood.log
```

**2. samm.** Kontrolli enne taaskäivitamist:

```bash
sudo rsyslogd -N1
```

```text
rsyslogd: unknown facility name "locla0" [v8.2510.0-2.el9]
```

`-N1` kontrollib konfi ilma rsyslogi puutumata. Paranda, kontrolli, kuni lõpus on `End of config validation run. Bye.`, siis `sudo systemctl restart rsyslog`.

**3. samm.** Terminal 1: `sudo tail -f /var/log/pood.log`. Terminal 2:

```bash
logger -p local0.info -t pood "tellimus 1001 vastu võetud"
sudo grep "tellimus 1001" /var/log/messages
```

Rida on uues failis, aga **ka** `messages`-is, sest `*.info` püüab kõik.

**4. samm.** Lisa reeglifaili teine rida:

```text
local0.*    /var/log/pood.log
& stop
```

`&` = "sama filter mis eelmisel real", `stop` = rohkem seda kirjet ei töödelda. Kontrolli, taaskäivita, testi numbriga 1002.

**5. samm.** **Ennusta enne:** lisad `local0.warning /var/log/pood-hoiatused.log` **enne** `local0.*` rida. Kuhu lähevad need kolm?

```bash
logger -p local0.info    -t pood "tellimus 1003"
logger -p local0.warning -t pood "laos alla 5 toote"
logger -p local0.err     -t pood "makse ebaõnnestus"
```

Lõplik reeglifail:

```text
local0.warning    /var/log/pood-hoiatused.log
local0.*          /var/log/pood.log
& stop
```

✅ **Kontrollpunkt:** hoiatuste failis kaks rida (warning ja err), `pood.log`-is kolm, `messages`-is mitte ühtegi.

**Mõtle:** Miks läks `err` ka hoiatuste faili, kuigi reeglis on `warning`?

**6. samm.** Päritolu ja tõsidus ei ole ainus filter. Vahel tahad kõik ühe **programmi** read, ükskõik mis päritoluga. Loo `/etc/rsyslog.d/20-ssh.conf`:

```text
if $programname startswith "sshd" then {
    action(type="omfile" file="/var/log/ssh.log")
}
```

`$programname` on kirje omadus (property), sama, mis syslogi reas enne nurksulge. `startswith`, sest programm võib olla `sshd` või `sshd-session`. Kontrolli, taaskäivita ja korda A4 sissetungija katset. Terminal 1: `sudo tail -f /var/log/ssh.log`.

### A6. Logi, mis ei täida ketast

**1. samm.** Loo `/etc/logrotate.d/pood`:

```text
/var/log/pood.log /var/log/pood-hoiatused.log {
    size 10k
    rotate 3
    missingok
}
```

`size 10k` = pööra, kui fail on üle 10 kB. Päriselus `daily` või `10M`, aga nii näed tulemust kohe.

**2. samm.** Proovikäik, `-d` ei tee midagi päriselt:

```bash
sudo logrotate -d /etc/logrotate.d/pood
```

Väljundis: `log does not need rotating`.

**3. samm.** Kirjuta logi täis ja pööra:

```bash
for i in $(seq 300); do logger -p local0.info -t pood "tellimus $i"; done
sudo logrotate -v /etc/logrotate.d/pood
ls -l /var/log/pood*
```

**4. samm.** Terminal 1: `sudo tail -f /var/log/pood.log.1`. Terminal 2:

```bash
logger -p local0.info -t pood "pärast pööramist"
sudo tail -1 /var/log/pood.log
```

`pood.log`-i pole ja rida ilmub terminal 1-sse, faili `pood.log.1`. rsyslog hoiab faili lahti ega tea, et sellel on uus nimi.

**5. samm.** Korista: kustuta pööratud failid ja **taaskäivita rsyslog**:

```bash
sudo rm -f /var/log/pood.log.*
sudo systemctl restart rsyslog
```

Kustutatud fail, mida rsyslog hoiab lahti, võtab kettal ruumi edasi, kuni rsyslog selle sulgeb. Klassikaline "ketas on täis, aga `du` ei leia midagi".

**6. samm.** Paranda konf:

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
| `compress` | vanad failid pakitakse (`.gz`) |
| `notifempty` | tühja faili ei pöörata |
| `postrotate` ... `endscript` | pärast pööramist: `HUP` käsib rsyslogil failid uuesti avada |

*Tabel 4. Logrotate'i lisaread*

**Ennusta enne:** mitu `pood.log.*` faili on alles, kui kirjutad 300 rida ja pöörad **neli korda**?

```bash
ls /var/log/pood*
```

```text
/var/log/pood-hoiatused.log  /var/log/pood.log  /var/log/pood.log.1.gz  /var/log/pood.log.2.gz  /var/log/pood.log.3.gz
```

Pakitud failist saab otsida lahti pakkimata:

```bash
sudo zgrep -c "tellimus 150" /var/log/pood.log.*.gz
```

✅ **Kontrollpunkt:** uus rida läheb `pood.log`-i, alles on kolm pakitud faili, `zgrep` leiab neist.

### A7. Kes seda tegi?

rsyslog ütleb, **mis** juhtus. Kui keegi muudab logikonfi või tühjendab turvalogi, tahad teada, **kes**. Selleks on auditd.

**1. samm.** Kolm jälgimisreeglit (`-w` jälgi, `-p wa` kirjutamine ja atribuudid, `-k` otsinguvõti):

```bash
sudo auditctl -w /etc/rsyslog.d/ -p wa -k logikonf
sudo auditctl -w /var/log/secure -p wa -k turvalogi
sudo auditctl -w /etc/cron.d/ -p wa -k ajastus
sudo auditctl -l
```

Hoiatus `Old style watch rules are slower` on normaalne.

**2. samm.** Terminal 1 vaatab:

```bash
sudo tail -f /var/log/audit/audit.log | grep --line-buffered -E 'logikonf|turvalogi'
```

Terminal 2 teeb seda, mida ründaja teeks:

```bash
sudo touch /etc/rsyslog.d/99-tagauks.conf
sudo truncate -s 0 /var/log/secure
```

Terminal 1-sse ilmuvad `type=SYSCALL` read. Peata ja loe inimese keeles:

```bash
sudo ausearch -k turvalogi -i | tail -6
```

Reast `type=SYSCALL` leia:

```text
auid=kasutaja uid=root ... comm=truncate exe=/usr/bin/truncate
```

`uid=root`, sest käsk jooksis `sudo`-ga. `auid=kasutaja` näitab, **kes** sisse logis. Seda ei saa `sudo`-ga peita.

```bash
sudo aureport -f -i | tail -5
sudo rm /etc/rsyslog.d/99-tagauks.conf
```

**3. samm.** `auditctl` reeglid kaovad taaskäivitusel. Tee püsivaks, fail `/etc/audit/rules.d/logid.rules`:

```text
-w /etc/rsyslog.d/ -p wa -k logikonf
-w /var/log/secure -p wa -k turvalogi
-w /etc/cron.d/ -p wa -k ajastus
```

Kolmas reegel jälgib ajastatud töid: ründaja, kes tahab masinasse tagasi tulla, jätab sageli maha cron-töö.

```bash
sudo augenrules --load
sudo auditctl -l
```

Tõendid, oma arvutis repo kaustas:

```bash
ssh proxmox2 "sudo cat /etc/audit/rules.d/logid.rules" > konf/logid.rules
ssh proxmox2 "sudo ausearch -k turvalogi -i" > logid/a7-audit.txt
```

✅ **Kontrollpunkt:** `konf/logid.rules`-is kolm reeglit, `logid/a7-audit.txt`-is `comm=truncate` ja sinu `auid`.

**Mõtle:** root saab ka auditi logi kustutada. Mis teeb ründaja töö raskemaks? (Osa B.)

---

!!! info "Paus"
    Välju SSH-sessioonidest. Pärast pausi töötad **iseseisvalt**: iga ülesanne ütleb, mis peab olema tehtud ja kuidas kontrollida. Konfi tükid on vihjetes. Proovi enne ise, kasuta [rsyslogi dokumentatsiooni](https://docs.rsyslog.com/doc/) ja osa A näiteid.

---

## Osa B · Öövahetus

### B1. Keskserver

**Nõuded (`proxmox1`):**

- rsyslog võtab vastu TCP kaudu pordil 514 (`imtcp`);
- võrgust tulnud kirjed **ei segune** `proxmox1` enda logidega (eraldi `ruleset`);
- iga masina iga programm saab oma faili `/var/log/remote/<masin>/<programm>.log` (mall, `%HOSTNAME%`, `%PROGRAMNAME%`);
- **kõigi masinate** `authpriv` kirjed lähevad lisaks ühte faili `/var/log/remote/turvalogi.log`;
- konf on failis `/etc/rsyslog.d/50-keskserver.conf`.

**Kontrolli:** `sudo rsyslogd -N1` on puhas ja `sudo ss -tlnp | grep 514` näitab `0.0.0.0:514` ja `rsyslogd`.

??? tip "Vihje 1: moodul ja sisend"
    ```text
    module(load="imtcp")
    input(type="imtcp" port="514" ruleset="kaugelt")
    ```
    `input` rida faili lõppu, pärast reeglistikku.

??? tip "Vihje 2: mall ja reeglistik"
    ```text
    template(name="MasinaKaupa" type="string"
             string="/var/log/remote/%HOSTNAME%/%PROGRAMNAME%.log")

    ruleset(name="kaugelt") {
        authpriv.*  action(type="omfile" file="/var/log/remote/turvalogi.log")
        action(type="omfile" dynaFile="MasinaKaupa")
    }
    ```
    `dynaFile` = failinimi arvutatakse iga kirje jaoks mallist. Reeglistiku sees töötab sama filter nagu A5-s.

### B2. proxmox2 saadab

**Nõuded (`proxmox2`):**

- kõik kirjed (`*.*`) lähevad TCP kaudu `proxmox1`-le (`omfwd`, IP, port 514);
- kui keskserver ei vasta, ootavad kirjed järjekorras ja klient ei loobu kunagi;
- konf on failis `/etc/rsyslog.d/90-keskserver.conf`.

**Kontrolli:** `logger -t n01test "siin proxmox2"` ja `proxmox1`-s `sudo cat /var/log/remote/proxmox2/n01test.log`.

??? tip "Vihje: saatmisreegel"
    ```text
    *.* action(type="omfwd" target="PROXMOX1-IP" port="514" protocol="tcp"
               queue.type="LinkedList" queue.size="10000"
               action.resumeRetryCount="-1")
    ```

??? tip "Vihje: kohale ei jõua midagi"
    Alusta kliendist. Kas port on üldse kättesaadav? `nc`-d AlmaLinuxis vaikimisi pole, aga bash oskab ise:
    ```bash
    timeout 3 bash -c '</dev/tcp/PROXMOX1-IP/514' && echo lahti || echo kinni
    ```
    `No route to host` ja `kinni`, kuigi `ss` näitas, et rsyslog kuulab: vahel on keegi. Vaata `proxmox1`-s `sudo firewall-cmd --list-ports`. Pärast pordi avamist (`--permanent --add-port=514/tcp`, `--reload`) oota kuni minut: järjekorras oodanud kirjed tulevad, klient proovib uuesti umbes iga 30 sekundi järel. Sama juhtub pärast keskserveri taaskäivitust.

**Mõtle:** `logger -p local0.info -t pood "tellimus 2001"` `proxmox2`-st ei jõua keskserverisse. Miks? (A5 4. samm ja failide järjekord.) Parandus on lisaülesanne 2.

### B3. proxmox3 playbookiga

`proxmox3` vajab sama saatmisreeglit ja samu auditi reegleid. Tee seda nagu päriselt: **playbookiga**, mis on Gitis ja töötab homme ka neljandal masinal.

```bash
scp proxmox2:/etc/rsyslog.d/90-keskserver.conf konf/
```

(`konf/logid.rules` on A7-st olemas.)

**Nõuded (`konf/keskserver.yml`):**

- paigaldab `rsyslog` ja `audit`;
- kopeerib `90-keskserver.conf` kausta `/etc/rsyslog.d/` ja `logid.rules` kausta `/etc/audit/rules.d/`;
- taaskäivitab rsyslogi ja laeb auditi reeglid **ainult siis, kui fail muutus** (handlerid, automatiseerimise nädal 4);
- teine käivitus annab `changed=0`.

```bash
ansible-playbook -i proxmox3, konf/keskserver.yml
ansible-playbook -i proxmox3, konf/keskserver.yml
```

**Kontrolli:** `ssh proxmox3 'logger -t n01test "siin proxmox3"'` jõuab `proxmox1` kausta `/var/log/remote/proxmox3/` ja `ssh proxmox3 "sudo auditctl -l"` näitab kolme reeglit.

??? tip "Vihje: playbooki ülesehitus"
    ```yaml
    - name: Logid keskserverisse ja logikonf auditi alla
      hosts: all
      become: true
      tasks:
        - name: Paketid
          ansible.builtin.package:
            name: [rsyslog, audit]
            state: present
        - name: Saatmisreegel
          ansible.builtin.copy:
            src: 90-keskserver.conf
            dest: /etc/rsyslog.d/90-keskserver.conf
            mode: "0644"
          notify: Taaskäivita rsyslog
        # ... teine copy logid.rules jaoks, notify: Lae auditi reeglid
      handlers:
        - name: Taaskäivita rsyslog
          ansible.builtin.service:
            name: rsyslog
            state: restarted
        # ... teine handler: ansible.builtin.command: augenrules --load
    ```
    `src` otsitakse playbooki kõrvalt, seega kõik kolm faili kausta `konf/`.

### B4. Mis juhtus öösel?

!!! quote "Vana tõde"
    Rakendus kirjutas öösel 3 GB logi. Tekstiredaktor keeldub seda avamast.
    *"Olgu siis. Hoia oma saladusi."*

Sina ei pea faili avama. Logi ei loeta, logilt **küsitakse**. Töövõte on alati sama: **filtreeri → loenda → vaata**.

Saada keskserverisse e-poe veebilogi ühe öö kohta (01:00-05:00). Sinu arvutist:

```bash
scp tooriistad/tee-suur-logi.sh proxmox2:
ssh proxmox2 "bash tee-suur-logi.sh > /tmp/veeb.log; wc -l /tmp/veeb.log"
ssh proxmox2 "logger -n PROXMOX1-IP -P 514 -T -t veeb -f /tmp/veeb.log"
```

`logger -n ... -T -f` saadab faili iga rea otse keskserverisse. Rida keskserveris:

```text
Oct 14 21:36:09 proxmox2 veeb kell=03:12:07 ip=10.0.1.36 meetod=GET url=/api/makse staatus=500 aeg=3207ms id=027995
```

Väljad on kujul `nimi=väärtus`. Seda on palju lihtsam otsida kui vaba teksti.

**Uurimine (`proxmox1`).** Keskserveri kaustad on `700`, ainult root saab sisse. `cd /var/log/remote/proxmox2` ja `sudo wc -l < veeb.log` annavad `Permission denied`, sest `cd`-d ja suunamist `<` teeb sinu enda shell, mitte `sudo`. Pealegi on see tõend ja **tõendiga ei tööta originaali peal**. Tee endale koopia:

```bash
sudo cp /var/log/remote/proxmox2/veeb.log ~/
sudo chown $USER ~/veeb.log
cd ~
```

Nüüd töötavad kõik käsud ilma `sudo`-ta ja originaal jääb puutumata. Kirjuta vastused repo faili `logid/b4-otsing.md` koos käsuga, millega leidsid:

1. Mitu rida on logis?
2. Mitu päringut lõppes veaga `500`?
3. Mis minutil oli vigu `500` kõige rohkem?
4. Milline URL andis vigu `500` kõige rohkem?
5. Üks IP proovis `/login`-iga paroole (`staatus=401`). Milline IP, mitu korda, mis kellast mis kellani?
6. **Kas ta pääses sisse?** Kui jah, mis kell ja mis `id`-ga päring?
7. Mis juhtus päringuga `id=031337`?

| Tööriist | Mida teeb | Näide |
|---|---|---|
| `grep -c` | loendab sobivad read | `grep -c 'staatus=500' fail` |
| `grep -o` | näitab ainult sobiva osa | `grep -o 'kell=..:..'` |
| `sort \| uniq -c \| sort -rn \| head` | mitu korda iga väärtus, suuremad ees | |
| `grep -v` | jätab sobivad read **välja** | `grep -v 'staatus=401'` |
| `head -1` / `tail -1` | esimene / viimane | |

*Tabel 5. Suure logi tööriistad*

??? tip "Vihje: küsimus 3"
    ```bash
    grep 'staatus=500' veeb.log | grep -o 'kell=..:..' | sort | uniq -c | sort -rn | head -3
    ```

??? tip "Vihje: küsimus 6"
    Võta kõik selle IP read ja jäta välja ebaõnnestunud. Mis jääb järele?

Pane käsu ette `time`. Kas 50 000 rida on arvutile palju?

**Mõtle:** Kas `grep 500` oleks sama hea kui `grep 'staatus=500'`? Proovi `grep -c 500` ja selgita vahet.

### B5. Öine külaline

Öövahetuse ajal võib õpetaja korraldada sinu masinatele "külastuse". Sa ei tea, millal, kust ega mida tehakse. Kui laboritahvel näitab, et su `proxmox3`-s juhtus midagi, või kui õpetaja ütleb "nüüd", alusta uurimist.

Kui teed laborit kodus või külastust ei tulnud, tee see ise. Sinu arvutis:

```bash
for u in admin root2 test; do
  ssh -o User=$u -o PubkeyAuthentication=no -o ConnectTimeout=5 proxmox3
done
ssh proxmox3 "sudo truncate -s 0 /var/log/secure"
ssh proxmox3 "echo '* * * * * root /usr/bin/logger -t uuendus kontroll' | sudo tee /etc/cron.d/uuendus"
```

Viimane rida on ründaja "tagauks": ajastatud töö, mis käivitub iga minut. Päris ründaja paneks sinna midagi hullemat, meie oma kirjutab ainult logirea.

`proxmox3` väidab nüüd, et midagi ei juhtunud: `ssh proxmox3 "sudo grep -c 'Invalid user' /var/log/secure"` annab `0`.

**Uurimine:**

1. Mis tegelikult juhtus? Leia keskserverist (`proxmox1`) kõik kasutajanimed, IP ja kellaajad.
2. Kes tühjendas `proxmox3` turvalogi ja mis kell? Leia `proxmox3` auditist (`auid`).
3. Kas ründaja jättis midagi maha? Vihje: keskserveris tekib iga minut uus rida ja audit (`-k ajastus`) teab, kes mida tegi. Kui leidsid, eemalda see.

Tõendid:

```bash
ssh proxmox1 "sudo grep -rh 'Invalid user' /var/log/remote/proxmox3/" > logid/b5-intsident.txt
ssh proxmox3 "sudo ausearch -k turvalogi -i; sudo ausearch -k ajastus -i" > logid/b5-audit.txt
```

`-r` otsib kõigist kausta failidest. Miks mitte `sudo grep ... /var/log/remote/proxmox3/*.log`? rsyslog loob kaustad õigustega `700`. `*` laiendab sinu shell **enne** `sudo`-t ja sina kausta ei näe, nii et grep saab failinime asemel tärni.

Kirjuta `README.md`-sse intsidendiraport: mis juhtus, millal, kust, kes kattis jäljed, kas midagi jäeti maha ja kuidas sa selle leidsid.

### B6. Keskserveri logid pöörlevad ka

**Nõuded (`proxmox1`, `/etc/logrotate.d/remote`):**

- failid `/var/log/remote/*/*.log` ja `/var/log/remote/turvalogi.log`;
- iga päev, 30 vana faili, pakitud;
- vana faili nimes kuupäev (`dateext`);
- pärast pööramist avab rsyslog failid uuesti.

**Kontrolli:** `sudo logrotate -d /etc/logrotate.d/remote` näitab mõlema masina faile ja `turvalogi.log`-i. Kirjuta `README.md`-sse, miks just nii mitu päeva.

---

## Esitamine

Oma arvutis, repo juurkaustas:

```bash
scp proxmox2:/etc/rsyslog.d/10-pood.conf       konf/
scp proxmox2:/etc/logrotate.d/pood             konf/pood.logrotate
scp proxmox1:/etc/rsyslog.d/50-keskserver.conf konf/
scp proxmox1:/etc/logrotate.d/remote           konf/remote.logrotate
ssh proxmox2 "ls /var/log/pood*"               > logid/a6-pood.txt
ssh proxmox1 "sudo ls -R /var/log/remote"      > logid/b3-remote.txt
```

Varem tegid: `logid/a3-boots.txt`, `konf/logid.rules`, `logid/a7-audit.txt`, `konf/90-keskserver.conf`, `konf/keskserver.yml`, `logid/b4-otsing.md`, `logid/b5-intsident.txt`, `logid/b5-audit.txt`.

Kontrolli, et ükski fail pole tühi (`wc -l logid/* konf/*`), siis:

```bash
git add README.md konf logid
git commit -m "Labor 1: öövahetus"
git push
```

Mõne minuti pärast näed GitHubis **Actions** all tulemust. Punase kontrolli korral loe väljundit, paranda, commit, push.

| Kontroll | Punkte |
|---|---|
| K1. Kõik failid olemas ja pole tühjad | 10 |
| K2. `10-pood.conf`: hoiatuste reegel enne `local0.*`, `& stop` | 10 |
| K3. `pood.logrotate`: `rotate 3`, `compress`, `postrotate` HUP-iga | 10 |
| K4. `logid.rules`: kolm jälgimisreeglit võtmetega | 10 |
| K5. `a3-boots.txt`: vähemalt kaks käivitust | 5 |
| K6. `50-keskserver.conf`: `imtcp`, mall, `ruleset`, `authpriv` eraldi | 10 |
| K7. `90-keskserver.conf`: `omfwd`, TCP, järjekord, lõputu kordus | 5 |
| K8. `keskserver.yml`: kaks faili, kaks handlerit | 10 |
| K9. `a6-pood.txt`: kolm pakitud vana faili | 5 |
| K10. `b4-otsing.md`: õiged vastused | 10 |
| K11. `b5-*.txt`: kasutajad keskserverist, `truncate` ja cron-fail auditist | 10 |
| K12. `README.md`: ennustused ja vastused täidetud | 5 |

*Tabel 6. Automaatkontroll*

---

## Kokkuvõte

Osas A lugesid üht rida kolmest kohast: rsyslogi fail ja journald ütlevad, mis juhtus, audit ütleb, kes. Seadistasid journali püsivaks, oma reegli ja logrotate'i ning nägid kolme viga, mida päriselt tehakse: trükiviga, puuduv `postrotate`, lahti hoitud kustutatud fail.

Osas B said `proxmox1`-st keskserveri: kaks masinat saadavad sinna logid, üks seadistati playbookiga. Leidsid 50 000 reast ründaja, kes lõpuks sisse pääses, ja lahendasid intsidendi, kus masina enda logi oli tühjendatud, aga keskserver ja audit mäletasid.

Järgmisel kohtumisel tuleb keskne jälgimissüsteem, mis kogub lisaks logidele ka numbreid.

## ✅ Lõpukontroll

- [ ] oskad öelda iga välja tähenduse syslogi reas, journaldi `-o verbose` väljundis ja auditi reas (`auid` vs `uid`)
- [ ] `praktikant` näeb journaldit, aga mitte `secure`-t
- [ ] `proxmox2` journal elab üle taaskäivituse
- [ ] pärast pööramist kirjutab rsyslog uude `pood.log`-i
- [ ] auditi reeglid on püsivad ja `ausearch -k turvalogi -i` näitab, kes logi tühjendas
- [ ] `proxmox1`-s on kaustad `proxmox2`, `proxmox3` ja fail `turvalogi.log`
- [ ] playbooki teine käivitus annab `changed=0`
- [ ] repo on push'itud ja Actions näitab 100 punkti

---

## Lisaülesanded

Kergemad on eespool.

**1. Kui palju journal võtab?** Uuri, kui palju ruumi journald nüüd kasutab, ja piira see 200 MB-ga.

??? success "Lahendus"
    ```bash
    journalctl --disk-usage
    sudo mkdir -p /etc/systemd/journald.conf.d
    printf '[Journal]\nSystemMaxUse=200M\n' | sudo tee /etc/systemd/journald.conf.d/piir.conf
    sudo systemctl restart systemd-journald
    ```
    journald kustutab vanemaid kirjeid ise, kui piir täitub.

**2. Poe logid keskserverisse.** Paranda nii, et `local0` kirjed `proxmox2`-st jõuavad keskserverisse, aga `proxmox2` enda `messages`-isse ikka ei lähe.

??? success "Lahendus"
    `& stop` lõpetab töötlemise enne, kui rsyslog jõuab `90-keskserver.conf`-ini. Failid loetakse tähestiku järjekorras:
    ```bash
    sudo mv /etc/rsyslog.d/90-keskserver.conf /etc/rsyslog.d/05-keskserver.conf
    sudo rsyslogd -N1 && sudo systemctl restart rsyslog
    logger -p local0.info -t pood "tellimus 2002"
    ```
    `proxmox1`-s: `sudo cat /var/log/remote/proxmox2/pood.log`. Muuda failinimi ka playbookis (B3).

**3. Kõige aeglasem päring.** Leia B4 logist päring, mille `aeg=` on kõige suurem.

??? success "Lahendus"
    ```bash
    awk -F'aeg=' '{ split($2, a, "ms"); if (a[1] > max) { max = a[1]; rida = $0 } } END { print rida }' ~/veeb.log
    ```
    `-F'aeg='` jagab rea kaheks, `split` lõikab `ms` ära, `awk` jätab meelde suurima.

**4. Kas UDP kaotab?** Lisa `proxmox1`-le UDP sisend (`imudp`, 514/udp, tulemüüris avada). Saada sama 50 000 rida UDP kaudu (`logger -n PROXMOX1-IP -P 514 -d -t veebudp -f /tmp/veeb.log`) ja loe, mitu kohale jõudis (`sudo wc -l` keskserveris). Meie testis jõudis kohale umbes 40 000. Kuhu kadusid ülejäänud ja miks TCP-ga seda ei juhtunud?

**5. Kui keskserver on maas.** Peata `proxmox1`-s rsyslog, saada `proxmox2`-st kolm rida, käivita rsyslog. **Ennusta enne:** kas need jõuavad? Oota kuni minut. Mis oli selles osa `queue.type` ja `resumeRetryCount`?

**6. JSON-vormingus kirjed.** Kohtumistel 8-9 lähevad logid otsingusüsteemidesse, mis eelistavad JSON-it. Tee keskserverisse mall, mis kirjutab iga kirje JSON-reana faili `/var/log/remote/koik.json`, tõsidus eraldi väljal.

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
    Mall enne reeglistikku, reeglistikku `action(type="omfile" file="/var/log/remote/koik.json" template="Json")`. Kontrolli: `sudo tail -1 /var/log/remote/koik.json | python3 -m json.tool`.

**7. Auditi aruanded.** `aureport -au`: mitu ebaõnnestunud sisselogimist on `proxmox3`-s olnud? Kes kasutas `sudo`-t kõige rohkem (`ausearch -m USER_CMD -i | grep -o 'auid=[^ ]*' | sort | uniq -c`)? Lisa reegel, mis jälgib `/etc/passwd`, ja tõesta `useradd`-iga.

**8. Oma väike valvur.** Skript `proxmox1`-s: loeb `turvalogi.log`-ist viimase 5 minuti `Invalid user` read ja kui ühelt IP-lt on neid üle 5, kirjutab `logger -p authpriv.alert` hoiatuse. Käivita iga minut `systemd` timeriga. Kohtumisel 12 teeb seda Wazuh.

**9. Krüpteeritud saatmine.** TLS `proxmox2` ja `proxmox1` vahel (port 6514, `gtls`, isesigneeritud sertifikaat). Tõesta `tcpdump`-iga, et 514-l oli sõnum loetav ja 6514-l enam mitte. Juhend: [rsyslogi dokumentatsioon](https://docs.rsyslog.com/doc/), otsingusõna "TLS".

**10. Päris raske: järjekord, mis elab üle taaskäivituse.** Mälus olev järjekord kaob, kui klient ise taaskäivitub, kui keskserver on maas. Lisa `queue.filename="keskserver"` ja `queue.saveOnShutdown="on"`. Peata keskserver, saada kolm rida, **taaskäivita klient**, käivita keskserver. Kas read jõuavad? Kui mitte, uuri `sudo journalctl -u rsyslog` ja `/var/lib/rsyslog/`. Mis seal on ja kuidas selle parandad?

**11. Kas logi on muudetud?** Ründaja võib ka keskserveris logi muuta. Lisa `/etc/logrotate.d/remote` `postrotate` plokki käsk, mis arvutab iga pööratud faili räsi (`sha256sum`) ja kirjutab selle faili `/var/log/remote/rasid.txt`. Kuidas tõestad hiljem, et pööratud fail on muutmata?

**12. Päris raske: journald ilma rsyslogita.** `systemd-journal-remote` ja `systemd-journal-upload` `proxmox3` ja `proxmox1` vahel. Võrdle rsyslogiga: mis on parem, mis halvem?

---

## Veaotsing

| Probleem | Põhjus | Lahendus |
|---|---|---|
| `rsyslogd -N1` annab vea | trükiviga | veateates on fail ja rida |
| Pärast restarti ei logi masin midagi | vigane konf | `systemctl status rsyslog`, `journalctl -u rsyslog -n 20` |
| `pood.log` puudub pärast pööramist | `postrotate` puudub | A6 5. ja 6. samm |
| `--list-boots` näitab ühte rida ka pärast rebooti | `/var/log/journal` puudub või `--flush` tegemata | A3 |
| `ausearch` ütleb `<no matches>` | võti erineb või sündmust polnud | `sudo auditctl -l` |
| `ausearch` `ssh` kaudu skriptis ei leia midagi | ilma terminalita loeb ta stdin-i | lisa `--input-logs` |
| `ss -tlnp` ei näita 514 | `imtcp` puudub | `module(load="imtcp")` |
| `proxmox1`-sse ei jõua midagi | tulemüür | B2 vihje |
| `/var/log/remote/` tühi, `journalctl -u rsyslog`: `Permission denied` | vale tee (SELinux) | tee peab algama `/var/log/` |
| Kaustanimi on IP, mitte `proxmox2` | hostinimi pole seatud | automatiseerimise nädal 1: `hostnamectl set-hostname` |
| `ssh -o User=...` logib sisse sinu kasutajana | `~/.ssh/config`-is on `ControlMaster` | lisa `-o ControlPath=none` |
| Playbook: `Could not find or access '90-keskserver.conf'` | fail pole playbooki kõrval | kõik kausta `konf/` |
| `veeb.log` on poolik | saatmine katkes | saada uuesti; loenda unikaalseid `id=` (`sort -u`) |
