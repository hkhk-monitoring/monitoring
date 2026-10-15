---
tags:
  - Labor
  - Monitooring
  - Logid
  - Linux
---

# K1 · Praktikum: öövahetus

Tänase lõpuks kogub `proxmox1` kahe masina logisid: `proxmox2` ja `proxmox3` saadavad iga kirje TCP kaudu keskserverisse, mis hoiab neid masina ja programmi kaupa eraldi. Kõik kolm masinat jälgivad auditiga, kes muudab logikonfi või turvalogi, ja journal elab üle taaskäivituse. `proxmox3` on seadistatud playbookiga. Öö lõpus leiad 50 000 reaga veebilogist ründaja ja lahendad intsidendi, kus masina enda logi oli tühjendatud.

<figure style="max-width:690px;margin:.8em auto" class="lx" markdown="0">
<svg viewBox="0 0 690 220" role="img" aria-label="Labori ülesehitus: proxmox2 ja proxmox3 saadavad logid proxmox1 keskserverisse, sinu arvuti juhib Ansiblega" xmlns="http://www.w3.org/2000/svg">
<style>.lx svg{width:100%;height:auto;font-family:var(--md-text-font-family,sans-serif)}.lx .box{fill:var(--md-code-bg-color);stroke:var(--md-default-fg-color--lighter);stroke-width:1.2}.lx .hi{fill:var(--md-primary-fg-color);fill-opacity:.16;stroke:var(--md-primary-fg-color);stroke-width:1.5}.lx .b{fill:var(--md-default-fg-color);font-size:14.5px;font-weight:600}.lx .s{fill:var(--md-default-fg-color--light);font-size:13px}.lx .c{fill:var(--md-default-fg-color);font-size:12.5px;font-family:var(--md-code-font-family,monospace)}.lx .a{stroke:var(--md-default-fg-color--light);stroke-width:1.5;fill:none}.lx .d{stroke-dasharray:5 4}.lx .h{fill:var(--md-default-fg-color--light)}</style>
<defs><marker id="lxl1" viewBox="0 0 10 10" refX="9" refY="5" markerWidth="6" markerHeight="6" orient="auto"><path class="h" d="M0,0 L10,5 L0,10 z"/></marker></defs>
<rect class="box" x="6" y="80" width="150" height="60" rx="6"/><text class="b" x="81" y="104" text-anchor="middle">Sinu arvuti</text><text class="s" x="81" y="122" text-anchor="middle">ssh, ansible, git</text>
<line class="a d" x1="156" y1="100" x2="236" y2="44" marker-end="url(#lxl1)"/><line class="a d" x1="156" y1="120" x2="236" y2="176" marker-end="url(#lxl1)"/><line class="a d" x1="156" y1="110" x2="500" y2="110" marker-end="url(#lxl1)"/>
<rect class="box" x="238" y="14" width="190" height="60" rx="6"/><text class="b" x="333" y="38" text-anchor="middle">proxmox2</text><text class="s" x="333" y="56" text-anchor="middle">e-pood, osa A, käsitsi</text>
<rect class="box" x="238" y="146" width="190" height="60" rx="6"/><text class="b" x="333" y="170" text-anchor="middle">proxmox3</text><text class="s" x="333" y="188" text-anchor="middle">playbookiga, öine külaline</text>
<line class="a" x1="428" y1="44" x2="500" y2="84" marker-end="url(#lxl1)"/><line class="a" x1="428" y1="176" x2="500" y2="136" marker-end="url(#lxl1)"/><text class="c" x="470" y="58" text-anchor="middle">TCP 514</text>
<rect class="hi" x="502" y="80" width="182" height="60" rx="6"/><text class="b" x="593" y="104" text-anchor="middle">proxmox1</text><text class="s" x="593" y="122" text-anchor="middle">keskserver /var/log/remote</text>
</svg>
</figure>

Osas A tutvud ühe masinaga juhendi järgi: kolm logi, õigused, püsiv journal, oma rakenduse reegel, logrotate ja audit. Kolm viga teed meelega ja parandad ise. Osas B on juhiseid vähem: ehitad keskserveri, seadistad kolmanda masina playbookiga, leiad suurest logist vastused ja uurid intsidenti. Oodatav tulemus ja vihjed on kinnistes plokkides. Tee enne ise ja siis võrdle.

Klassis jõuad osa A ja B1-B3. B4-B6 ja lisaülesanded lõpeta kodus, kui aega ei jää. Kõik vajalik töötab ka kodust (VPN).

??? abstract "Õpiväljundid"

    Praktikumi lõpuks oskad:

    1. lugeda üht logirida kolmest kohast (rsyslogi fail, journal, auditi logi) ja öelda, mis on iga väli;
    2. kontrollida, kes tohib logisid lugeda, ja anda journalile ligipääs ilma `sudo`-ta;
    3. teha journali püsivaks ja tõendada seda taaskäivitusega;
    4. kirjutada rsyslogi reegli päritolu ja programmi järgi ning kontrollida konfi enne taaskäivitust;
    5. seadistada logrotate'i nii, et rsyslog kirjutab pärast pööramist uude faili;
    6. seadistada auditi reeglid ja leida `auid`-st, kes muudatuse tegi;
    7. ehitada keskse logiserveri ja leida põhjus, kui logid kohale ei jõua;
    8. leida 50 000 reaga logist vastus võttega filtreeri, loenda, vaata.

## Enne alustamist

Automatiseerimise kursusest peab töötama: `ssh proxmox1`, `ssh proxmox2` ja `ssh proxmox3` ilma paroolita ning Ansible sinu arvutis (Linux, macOS või WSL). Kui ei tööta, vaata [Töökeskkond](../kodulabor.md).

Ava õpetaja jagatud Classroom 50 link ja klooni oma repo:

```bash
git clone <sinu-repo-url>
cd <sinu-repo>
ls -R
```

??? success "Oodatav tulemus"

    ```text
    .:
    README.md  kodutoo  konf  logid  tooriistad

    ./tooriistad:
    tee-suur-logi.sh
    ```

    `README.md`-sse kirjutad ennustused ja vastused (pealkirjad on olemas). `konf/` ja `logid/` on tõendite jaoks. `tooriistad/tee-suur-logi.sh` on osa B4 jaoks: ära loe seda enne, seal on vastused.

??? note "Mis repos lõpuks on"

    ```text
    <sinu-repo>/
    ├── README.md
    ├── konf/
    │   ├── 10-pood.conf          proxmox2: oma rakenduse reegel
    │   ├── pood.logrotate        proxmox2: logrotate
    │   ├── logid.rules           auditi reeglid
    │   ├── 50-keskserver.conf    proxmox1: keskserver
    │   ├── 90-keskserver.conf    klient: saatmine
    │   ├── keskserver.yml        playbook proxmox3 jaoks
    │   └── remote.logrotate      proxmox1: keskserveri logrotate
    ├── logid/
    │   ├── a3-boots.txt  a6-pood.txt  a7-audit.txt
    │   ├── b3-remote.txt  b4-otsing.md
    │   └── b5-intsident.txt  b5-audit.txt
    └── kodutoo/
        └── logiraport.sh
    ```

Logimise tööriistad peavad igas sõlmes olemas olema. Tavapaigalduses on, aga sõlm võib olla tehtud minimaalsest image'ist. Vaata ühes sõlmes, siis tee kõigis kindlaks:

```bash
ssh proxmox2 "rpm -q rsyslog logrotate audit; systemctl is-active rsyslog auditd; systemctl list-timers logrotate.timer --no-pager"
ansible all -i proxmox1,proxmox2,proxmox3, -b -m ansible.builtin.package -a "name=rsyslog,logrotate,audit state=present"
ansible all -i proxmox1,proxmox2,proxmox3, -b -m ansible.builtin.service -a "name=rsyslog state=started enabled=true"
ssh proxmox1 "hostname -I"
```

??? success "Oodatav tulemus"

    Paketid on olemas, teenused `active`, `logrotate.timer` on nimekirjas (veerg `NEXT` ütleb, millal järgmine kord). Ansible vastab iga sõlme kohta `SUCCESS` (oli olemas) või `CHANGED` (paigaldas). `-i proxmox1,proxmox2,proxmox3,` lõpus olev koma ütleb Ansible'ile, et see on nimekiri, mitte faili nimi.

    `rsyslog` ja `auditd` on teenused, mis töötavad kogu aeg. `logrotate` ei ole teenus: selle käivitab kord ööpäevas taimer.

    `hostname -I` esimene aadress (`192.168.35.x`) on `proxmox1` IP. Pane see kirja: sõlmed ei tea nime `proxmox1` (see on ainult sinu `~/.ssh/config`-is) ja räägivad omavahel IP kaudu.

!!! tip "Töökäik iga sammu juures"

    1. Ava kaks terminali kõrvuti (VS Code: menüü **Terminal → Split Terminal**).
    2. **Terminal 1 vaatab** (`tail -f`, `journalctl -f`), **terminal 2 teeb**.
    3. Kus on "Ennusta", kirjuta vastus `README.md`-sse **enne** käsu käivitamist.
    4. rsyslogi konfi muutmise järel alati `sudo rsyslogd -N1`, alles siis `sudo systemctl restart rsyslog`.

## A · Juhendatud osa

Kogu osa A töötad sõlmes `proxmox2`. Logi mõlemas terminalis sisse: `ssh proxmox2`.

### A1 · Üks rida, kolm logi

Selle sammu lõpuks oskad sama sündmuse leida failist ja journalist ning tead, mille poolest auditi logi neist erineb.

**Ennusta:** kui käivitad `logger`-i, kas rida jõuab journalisse, faili `/var/log/messages` või mõlemasse?

```bash
sudo tail -f /var/log/messages                 # terminal 1
logger -t n01test "tere logi"                  # terminal 2
journalctl -t n01test -o verbose -n 1          # terminal 2
```

??? success "Oodatav tulemus"

    Terminal 1-sse ilmub kohe:
    ```text
    Oct 14 20:26:20 proxmox2 n01test[4005]: tere logi
    ```
    `journalctl -o verbose` näitab sama kirjet väljadega, nende seas:
    ```text
        PRIORITY=5
        SYSLOG_FACILITY=1
        _HOSTNAME=proxmox2
        _PID=4005
    ```
    `PRIORITY=5` on tõsidus `notice`, `SYSLOG_FACILITY=1` on päritolu `user` (loeng, peatükk 7). Tekstireal neid pole. `_` algusega väljad lisas journald ise ja programm ei saa neid võltsida.

Kolmas on auditi logi. Seal on tuuma tähelepanekud, mitte programmide sõnumid:

```bash
sudo tail -1 /var/log/audit/audit.log
sudo ausearch -m USER_CMD -i --start recent | tail -1
```

??? success "Oodatav tulemus"

    ```text
    type=USER_CMD msg=audit(1792002876.234:3181): pid=11633 uid=501 auid=501 ses=5 ... cmd=7461696C202D31... exe="/usr/bin/sudo" res=success
    ```
    See on sinu enda `sudo tail`. `ausearch -i` teeb sama inimloetavaks: `uid` ja `auid` muutuvad nimedeks, `cmd` loetavaks käsuks.

    | Väli | Tähendus |
    |---|---|
    | `type` | sündmuse liik |
    | `msg=audit(aeg:nr)` | aeg sekundites alates 1970 ja järjekorranumber |
    | `uid` | kelle õigustega käsk jooksis |
    | `auid` | kes algselt sisse logis; ei muutu `sudo` järel |
    | `exe`, `cmd` | programm ja käsk |
    | `res` | õnnestus või mitte |

### A2 · Kes tohib lugeda

Selle sammu lõpuks on proovikasutajal ligipääs journalile, aga mitte turvalogile.

**Ennusta:** kas tavakasutaja saab lugeda `/var/log/secure`-t? Aga journalit?

```bash
ls -l /var/log/messages /var/log/secure /var/log/cron
ls -ld /var/log/audit
cat /var/log/secure
sudo useradd -m praktikant
sudo -u praktikant journalctl -n 3
```

??? success "Oodatav tulemus"

    ```text
    -rw-------. 1 root root   1200 Oct 14 21:32 /var/log/cron
    -rw-------. 1 root root 369778 Oct 14 21:33 /var/log/messages
    -rw-------. 1 root root 203740 Oct 14 21:33 /var/log/secure
    drwx------. 2 root root     23 Aug 10 08:04 /var/log/audit
    cat: /var/log/secure: Permission denied
    No journal files were opened due to insufficient permissions.
    ```
    AlmaLinuxis loeb tekstilogisid ainult root (`600`). Sinu kasutaja näeb journalit, sest ta on grupis `wheel` (vaata `id`).

Anna praktikandile journal, aga mitte rohkem:

```bash
sudo usermod -aG systemd-journal praktikant
sudo -u praktikant journalctl -n 3
sudo -u praktikant cat /var/log/secure
```

??? success "Oodatav tulemus"

    Praktikant näeb nüüd journalit, aga `cat /var/log/secure` annab ikka `Permission denied`. See on vähima õiguse põhimõte: kolleeg saab veaotsinguks journali ilma `sudo`-ta ja ilma turvalogita.

Kirjuta `README.md`-sse, miks on parem lisada kolleeg gruppi kui anda talle `sudo`. Pärast seda korista: `sudo userdel -r praktikant`.

### A3 · Journal, mis ei unusta

Selle sammu lõpuks elab `proxmox2` journal üle taaskäivituse ja sul on selle kohta tõend.

**Ennusta:** kas journal elab praegu üle taaskäivituse?

```bash
journalctl --list-boots
ls -ld /var/log/journal
```

??? success "Oodatav tulemus"

    Üks käivitus ja `ls: cannot access '/var/log/journal': No such file or directory`. journald hoiab journalit mälus (`/run/log/journal`) ja taaskäivitusel kaob kõik (loeng, peatükk 5, `Storage=auto`).

Tee journal püsivaks ja tõesta:

```bash
sudo mkdir -p /var/log/journal
sudo systemd-tmpfiles --create --prefix /var/log/journal   # (1)!
sudo journalctl --flush                                    # (2)!
ls -ld /var/log/journal
sudo reboot
```

1. Paneb kaustale õige grupi ja ACL-id.
2. Kirjutab mälus olnud journali kettale.

Oota pool minutit, siis oma arvutis repo kaustas:

```bash
ssh proxmox2 "journalctl --list-boots" > logid/a3-boots.txt
cat logid/a3-boots.txt
```

??? success "Oodatav tulemus"

    Enne rebooti:
    ```text
    drwxr-sr-x+ 3 root systemd-journal 46 Oct 14 21:34 /var/log/journal
    ```
    `+` tähendab ACL-i: `getfacl /var/log/journal` näitab, et lugeda tohivad ka `wheel` ja `adm`.

    Pärast rebooti on `--list-boots` väljundis vähemalt kaks rida (`-1` ja `0`).

### A4 · Keegi koputab uksele

Selle sammu lõpuks leiad ebaõnnestunud sisselogimise mitmest kohast ja tead, miks see ühes kohas puudub.

Terminal 1 (`proxmox2`): `sudo tail -f /var/log/secure`. Terminal 2 **sinu arvutis**:

```bash
ssh -o User=sissetungija -o PubkeyAuthentication=no proxmox2
```

Kui küsitakse parooli, sisesta kolm korda suvaline tekst. Kui paroolisisselogimine on keelatud, saad kohe `Permission denied`. Siis `proxmox2`-s:

```bash
sudo journalctl -u sshd --since "10 min ago"
sudo lastb -w -n 5
last -n 5
journalctl -p err -b | wc -l
sudo grep "Invalid user" /var/log/messages
```

??? success "Oodatav tulemus"

    Terminal 1-sse ilmub:
    ```text
    Oct 14 20:36:39 proxmox2 sshd-session[4133]: Invalid user sissetungija from 192.168.35.x port 49970
    Oct 14 20:36:39 proxmox2 sshd-session[4133]: Connection closed by invalid user sissetungija 192.168.35.x port 49970 [preauth]
    ```
    IP on sinu arvuti oma. Programm on uuemas OpenSSH-s `sshd-session`, vanemas `sshd`.

    `journalctl -u sshd` näitab sama. `lastb -w` näitab katset kahendlogist `btmp` (ilma `-w`-ta oleks nimi `sissetun`). `last` näitab õnnestunud sisselogimisi ja taaskäivitusi.

    `messages`-ist rida ei leia: rsyslogi reeglis on `authpriv.none` (A5 alguses näed).

Kirjuta `README.md`-sse vigade arv sellest käivitusest ja programm, mis neid kõige rohkem kirjutas (`journalctl -p err -b`).

### A5 · E-poe enda logi

Selle sammu lõpuks on e-poe logid eraldi failides, hoiatused omaette ja SSH-read programmi järgi oma failis.

Vaata, mis reeglid rsyslogil on:

```bash
grep -v -E '^#|^$' /etc/rsyslog.conf | grep /var/log
```

??? success "Oodatav tulemus"

    ```text
    *.info;mail.none;authpriv.none;cron.none action(type="omfile" file="/var/log/messages")
    authpriv.* action(type="omfile" file="/var/log/secure")
    mail.* action(type="omfile" file="/var/log/maillog" sync="on")
    cron.* action(type="omfile" file="/var/log/cron")
    uucp,news.crit action(type="omfile" file="/var/log/spooler")
    local7.* action(type="omfile" file="/var/log/boot.log")
    ```
    AlmaLinux 9.8 kasutab uut süntaksit (`action(...)`), vanemates on paremal ainult faili tee.

E-pood logib päritoluga `local0`. Loo `/etc/rsyslog.d/10-pood.conf` **meelega veaga**, nagu kiirustades juhtub:

```text
locla0.*    /var/log/pood.log
```

```bash
sudo rsyslogd -N1
```

??? success "Oodatav tulemus"

    ```text
    rsyslogd: unknown facility name "locla0" [v8.2510.0-2.el9]
    ```
    `-N1` kontrollib konfi ilma rsyslogi puutumata. Paranda `local0`, kontrolli uuesti (`End of config validation run. Bye.`), taaskäivita.

```bash
logger -p local0.info -t pood "tellimus 1001"
sudo grep "tellimus 1001" /var/log/pood.log /var/log/messages
```

Rida on mõlemas, sest `*.info` püüab kõik. Lisa reeglifaili teine rida ja proovi numbriga 1002:

```text
local0.*    /var/log/pood.log
& stop
```

**Ennusta:** lisad rea `local0.warning /var/log/pood-hoiatused.log` **enne** `local0.*` rida. Kuhu lähevad need kolm?

```bash
logger -p local0.info    -t pood "tellimus 1003"
logger -p local0.warning -t pood "laos alla 5 toote"
logger -p local0.err     -t pood "makse ebaõnnestus"
```

??? success "Oodatav tulemus"

    ```text
    local0.warning    /var/log/pood-hoiatused.log
    local0.*          /var/log/pood.log
    & stop
    ```
    `pood-hoiatused.log`-is on warning ja err (`warning` tähendab "hoiatus ja tõsisemad"), `pood.log`-is kõik kolm, `messages`-is mitte ühtegi.

Viimaseks reegel programmi järgi, mitte päritolu järgi. Loo `/etc/rsyslog.d/20-ssh.conf`:

```text
if $programname startswith "sshd" then {
    action(type="omfile" file="/var/log/ssh.log")
}
```

Kontrolli, taaskäivita, korda A4 sissetungija katset ja vaata `sudo tail /var/log/ssh.log`.

??? success "Oodatav tulemus"

    `Invalid user` read on `/var/log/ssh.log`-is. `startswith`, sest programm on `sshd` või `sshd-session`.

### A6 · Logi, mis ei täida ketast

Selle sammu lõpuks pöörab logrotate poe logi, vanad failid on pakitud ja rsyslog kirjutab uude faili.

Loo `/etc/logrotate.d/pood`:

```text
/var/log/pood.log /var/log/pood-hoiatused.log {
    size 10k
    rotate 3
    missingok
}
```

```bash
sudo logrotate -d /etc/logrotate.d/pood                                       # proovikäik
for i in $(seq 300); do logger -p local0.info -t pood "tellimus $i"; done
sudo logrotate -v /etc/logrotate.d/pood
sudo tail -f /var/log/pood.log.1                                              # terminal 1
logger -p local0.info -t pood "pärast pööramist"                              # terminal 2
sudo tail -1 /var/log/pood.log
```

??? success "Oodatav tulemus"

    Proovikäik ütleb `log does not need rotating`. Pärast 300 rida ja pööramist on `pood.log.1`. Uus rida ilmub terminal 1-sse ehk faili `pood.log.1`, `pood.log`-i ei ole (`No such file or directory`). rsyslog hoiab faili lahti ega tea, et sellel on uus nimi.

Korista ja paranda:

```bash
sudo rm -f /var/log/pood.log.*
sudo systemctl restart rsyslog       # (1)!
```

1. Kustutatud fail, mida rsyslog hoiab lahti, võtab kettal ruumi edasi, kuni rsyslog selle sulgeb. Klassikaline "ketas on täis, aga `du` ei leia midagi".

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

**Ennusta:** mitu `pood.log.*` faili on alles, kui kirjutad 300 rida ja pöörad neli korda?

```bash
ls /var/log/pood*
sudo zgrep -c "tellimus 150" /var/log/pood.log.*.gz
```

??? success "Oodatav tulemus"

    ```text
    /var/log/pood-hoiatused.log  /var/log/pood.log  /var/log/pood.log.1.gz  /var/log/pood.log.2.gz  /var/log/pood.log.3.gz
    ```
    Neljas pööramine lükkas vanima välja (`rotate 3`). `.1` on kohe pakitud, sest `delaycompress`-i ei ole. `pood-hoiatused.log` jäi pööramata, sest see on alla 10k. `zgrep` otsib pakitud failidest lahti pakkimata. Uus `logger`-i rida läheb nüüd `pood.log`-i.

### A7 · Kes seda tegi

Selle sammu lõpuks jälgib audit logikonfi, turvalogi ja ajastatud töid püsivalt ning sa leiad, kes muudatuse tegi.

```bash
sudo auditctl -w /etc/rsyslog.d/ -p wa -k logikonf      # (1)!
sudo auditctl -w /var/log/secure -p wa -k turvalogi
sudo auditctl -w /etc/cron.d/ -p wa -k ajastus
sudo auditctl -l
```

1. `-w` jälgi faili või kausta, `-p wa` kirjutamine ja atribuutide muutmine, `-k` otsinguvõti. Hoiatus `Old style watch rules are slower` on normaalne.

Terminal 1 vaatab, terminal 2 teeb seda, mida ründaja teeks:

```bash
sudo tail -f /var/log/audit/audit.log | grep --line-buffered -E 'logikonf|turvalogi'   # terminal 1
sudo touch /etc/rsyslog.d/99-tagauks.conf                                               # terminal 2
sudo truncate -s 0 /var/log/secure
sudo ausearch -k turvalogi -i | tail -6
sudo aureport -f -i | tail -5
sudo rm /etc/rsyslog.d/99-tagauks.conf
```

??? success "Oodatav tulemus"

    Terminal 1-sse ilmuvad `type=SYSCALL` read. `ausearch -i` reast leiad:
    ```text
    auid=kasutaja uid=root ... comm=truncate exe=/usr/bin/truncate
    ```
    `uid=root`, sest käsk jooksis `sudo`-ga. `auid` näitab, kes sisse logis, ja seda `sudo` ei muuda.

`auditctl` reeglid kaovad taaskäivitusel. Tee need püsivaks failis `/etc/audit/rules.d/logid.rules`:

```text
-w /etc/rsyslog.d/ -p wa -k logikonf
-w /var/log/secure -p wa -k turvalogi
-w /etc/cron.d/ -p wa -k ajastus
```

```bash
sudo augenrules --load
sudo auditctl -l
```

Oma arvutis repo kaustas:

```bash
ssh proxmox2 "sudo cat /etc/audit/rules.d/logid.rules" > konf/logid.rules
ssh proxmox2 "sudo ausearch -k turvalogi -i" > logid/a7-audit.txt
```

??? success "Oodatav tulemus"

    `auditctl -l` näitab kolme reeglit, `konf/logid.rules`-is on kolm rida ja `logid/a7-audit.txt`-is on `comm=truncate` ja sinu kasutaja `auid`-ina. Kui `ausearch` skriptis midagi ei leia, lisa `--input-logs` (ilma terminalita loeb ta stdin-i).

Kirjuta `README.md`-sse: mis vahe on `uid` ja `auid` väljal ja mis teeb ründaja töö raskemaks, kui ta on root ja saab ka auditi logi kustutada.

## B · Iseseisev osa

Iga ülesanne ütleb, mis peab olema tehtud ja kuidas kontrollida. Kasuta loengut (peatükid 6 ja 11), [rsyslogi dokumentatsiooni](https://docs.rsyslog.com/doc/) ja osa A näiteid. Vihjed on kinni.

### B1 · Keskserver

**Nõuded (`proxmox1`, fail `/etc/rsyslog.d/50-keskserver.conf`):**

- võtab vastu TCP kaudu pordil 514;
- võrgust tulnud kirjed ei segune `proxmox1` enda logidega (eraldi `ruleset`);
- iga masina iga programm oma faili: `/var/log/remote/<masin>/<programm>.log`;
- kõigi masinate `authpriv` kirjed lisaks faili `/var/log/remote/turvalogi.log`.

**Kontrolli:** `sudo rsyslogd -N1` on puhas, `sudo ss -tlnp | grep 514` näitab `0.0.0.0:514` ja `rsyslogd`.

??? tip "Vihje: konfi osad"

    ```text
    module(load="imtcp")

    template(name="MasinaKaupa" type="string"
             string="/var/log/remote/%HOSTNAME%/%PROGRAMNAME%.log")

    ruleset(name="kaugelt") {
        authpriv.*  action(type="omfile" file="/var/log/remote/turvalogi.log")
        action(type="omfile" dynaFile="MasinaKaupa")
    }

    input(type="imtcp" port="514" ruleset="kaugelt")
    ```
    `dynaFile` arvutab failinime iga kirje jaoks mallist. `input` faili lõppu.

**Ennusta:** kui `proxmox2` hakkab saatma ja tulemüüri sa veel ei puuduta, mis juhtub? Kirjuta `README.md`-sse.

### B2 · proxmox2 saadab

**Nõuded (`proxmox2`, fail `/etc/rsyslog.d/90-keskserver.conf`):**

- kõik kirjed (`*.*`) TCP kaudu `proxmox1`-le;
- kui keskserver ei vasta, ootavad kirjed järjekorras ja klient ei loobu kunagi.

!!! warning "Tähelepanu: kausta nimi on masina päris nimi"
    `%HOSTNAME%` on masina enda nimi, mitte sinu SSH alias. `proxmox1-3` on ainult sinu `~/.ssh/config`-is, keskserver neid ei tea. Vaata päris nimed järele ja kasuta neid edaspidi `<proxmox2-nimi>` ja `<proxmox3-nimi>` asemel:

    ```bash
    ssh proxmox2 hostname
    ssh proxmox3 hostname
    ```

**Kontrolli:** `logger -t n01test "siin proxmox2"` ja `proxmox1`-s `sudo cat /var/log/remote/<proxmox2-nimi>/n01test.log`.

??? tip "Vihje: saatmisreegel"

    ```text
    *.* action(type="omfwd" target="PROXMOX1-IP" port="514" protocol="tcp"
               queue.type="LinkedList" queue.size="10000"
               action.resumeRetryCount="-1")
    ```

??? tip "Vihje: kohale ei jõua midagi"

    Alusta kliendist. `nc`-d AlmaLinuxis vaikimisi pole, aga bash oskab ise:
    ```bash
    timeout 3 bash -c '</dev/tcp/PROXMOX1-IP/514' && echo lahti || echo kinni
    ```
    `No route to host` ja `kinni` tähendab, et pakett ei jõua rsyslogini, kuigi `ss` näitas, et rsyslog kuulab. Kliendi ja serveri vahel on tulemüür. Vaata `proxmox1`-s `sudo firewall-cmd --list-ports`.

??? success "Oodatav tulemus"

    Esimene rida ei jõua kohale, sest `proxmox1` tulemüür ei luba porti 514. Pärast `sudo firewall-cmd --permanent --add-port=514/tcp && sudo firewall-cmd --reload` jõuab see **minuti jooksul ikkagi kohale**: klient hoidis seda järjekorras ja proovis uuesti umbes iga 30 sekundi järel. Sama viivitus tuleb iga kord pärast keskserveri taaskäivitust.

    `logger -p local0.info -t pood "tellimus 2001"` ei jõua keskserverisse. `10-pood.conf` teeb `& stop` enne, kui rsyslog jõuab faili `90-keskserver.conf`-ini (failid loetakse tähestiku järjekorras). Parandus on lisaülesanne 2.

### B3 · proxmox3 playbookiga

`proxmox3` vajab sama saatmisreeglit ja samu auditi reegleid. Tee seda playbookiga, mis on Gitis ja töötab homme ka neljandal masinal.

```bash
scp proxmox2:/etc/rsyslog.d/90-keskserver.conf konf/
```

**Nõuded (`konf/keskserver.yml`):**

- paigaldab `rsyslog` ja `audit`;
- kopeerib `90-keskserver.conf` kausta `/etc/rsyslog.d/` ja `logid.rules` kausta `/etc/audit/rules.d/`;
- taaskäivitab rsyslogi ja laeb auditi reeglid **ainult siis, kui fail muutus** (handlerid, automatiseerimise nädal 4);
- teine käivitus annab `changed=0`.

```bash
ansible-playbook -i proxmox3, konf/keskserver.yml
ansible-playbook -i proxmox3, konf/keskserver.yml
```

**Kontrolli:** `ssh proxmox3 'logger -t n01test "siin proxmox3"'` jõuab `proxmox1` kausta `/var/log/remote/<proxmox3-nimi>/`, `ssh proxmox3 "sudo auditctl -l"` näitab kolme reeglit.

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
        # ... teine copy logid.rules jaoks (mode "0600"), notify: Lae auditi reeglid
      handlers:
        - name: Taaskäivita rsyslog
          ansible.builtin.service:
            name: rsyslog
            state: restarted
        # ... teine handler: ansible.builtin.command: augenrules --load
    ```
    `src` otsitakse playbooki kõrvalt, seega kõik kolm faili kausta `konf/`.

### B4 · Mis juhtus öösel

Rakendus kirjutas öösel 3 GB logi ja tekstiredaktor keeldub seda avamast. Logi ei loeta, logilt küsitakse.

Saada keskserverisse e-poe veebilogi ühe öö kohta (01:00-05:00, 50 000 rida). Oma arvutist:

```bash
scp tooriistad/tee-suur-logi.sh proxmox2:
ssh proxmox2 "bash tee-suur-logi.sh > /tmp/veeb.log; wc -l /tmp/veeb.log"
ssh proxmox2 "logger -n PROXMOX1-IP -P 514 -T -t veeb -f /tmp/veeb.log"
```

Rida keskserveris:

```text
Oct 14 21:36:09 proxmox2 veeb kell=03:12:07 ip=10.0.1.36 meetod=GET url=/api/makse staatus=500 aeg=3207ms id=027995
```

Real on kaks kellaaega. Esimene (`Oct 14 21:36:09`) on aeg, mil kirje keskserverisse saadeti. Teine (`kell=03:12:07`) on rakenduse enda aeg, mil päring tehti. Uurimisel kasuta rakenduse aega.

Keskserveri kaustad on `700`, `cd /var/log/remote/<proxmox2-nimi>` annab `Permission denied`. Pealegi on see tõend ja **tõendiga ei tööta originaali peal**. Tee `proxmox1`-s koopia:

```bash
sudo cp /var/log/remote/<proxmox2-nimi>/veeb.log ~/
sudo chown $USER ~/veeb.log
```

**Ülesanne.** Leia vastused ja kirjuta need faili `logid/b4-otsing.md` koos käsuga, millega leidsid:

1. Mitu rida on logis?
2. Mitu päringut lõppes veaga `500`?
3. Mis minutil oli vigu `500` kõige rohkem?
4. Milline URL andis vigu `500` kõige rohkem?
5. Üks IP proovis `/login`-iga paroole (`staatus=401`). Milline, mitu korda, mis kellast mis kellani?
6. Kas ta pääses sisse? Kui jah, mis kell ja mis `id`-ga päring?
7. Mis juhtus päringuga `id=031337`?

??? tip "Vihje: töövõte"

    Filtreeri, loenda, vaata (loeng, peatükk 12). Näiteks küsimus 3:
    ```bash
    grep 'staatus=500' veeb.log | grep -o 'kell=..:..' | sort | uniq -c | sort -rn | head -3
    ```
    Küsimus 6: võta kõik selle IP read ja jäta välja ebaõnnestunud (`grep -v`).

Kirjuta `README.md`-sse: kas `grep 500` oleks sama hea kui `grep 'staatus=500'`? Proovi `grep -c 500` ja selgita vahet.

### B5 · Öine külaline

Eeldus: B1-B3 on tehtud, ehk `proxmox3` saadab logid keskserverisse ja auditi reeglid on peal. Muidu ei ole sul pärast külastust midagi uurida.

Öövahetuse ajal võib õpetaja korraldada sinu `proxmox3`-le "külastuse". Sa ei tea, millal, kust ega mida tehakse. Kui õpetaja ütleb "nüüd" või tahvel näitab muutust, alusta uurimist.

Kui teed laborit kodus või külastust ei tulnud, tee see ise oma arvutist:

```bash
for u in admin root2 test; do
  ssh -o User=$u -o PubkeyAuthentication=no -o ConnectTimeout=5 proxmox3
done
ssh proxmox3 "sudo truncate -s 0 /var/log/secure"
ssh proxmox3 "echo '* * * * * root /usr/bin/logger -t uuendus kontroll' | sudo tee /etc/cron.d/uuendus"
```

`ssh proxmox3 "sudo grep -c 'Invalid user' /var/log/secure"` annab nüüd `0`.

**Uurimine:**

1. Mis juhtus? Leia keskserverist kõik kasutajanimed, IP ja kellaajad.
2. Kes tühjendas `proxmox3` turvalogi ja mis kell?
3. Mis jäeti maha? Eemalda see.

```bash
P3=$(ssh proxmox3 hostname)
ssh proxmox1 "sudo grep -rh 'Invalid user' /var/log/remote/$P3/" > logid/b5-intsident.txt
ssh proxmox3 "sudo ausearch -k turvalogi -i; sudo ausearch -k ajastus -i" > logid/b5-audit.txt
```

??? tip "Vihje"

    `grep -r` otsib kõigist kausta failidest. `sudo grep ... /var/log/remote/$P3/*.log` ei tööta: `*` laiendab sinu shell enne `sudo`-t ja sina kausta ei näe. Maha jäetud asi kirjutab keskserverisse iga minut uue rea ja audit (`-k ajastus`) teab, kes selle tegi.

Kirjuta `README.md`-sse intsidendiraport: mis juhtus, millal, kust, kes kattis jäljed, mis jäeti maha ja kuidas sa selle leidsid.

### B6 · Keskserveri logid pöörlevad ka

**Nõuded (`proxmox1`, `/etc/logrotate.d/remote`):** failid `/var/log/remote/*/*.log` ja `/var/log/remote/turvalogi.log`, iga päev, 30 vana faili, pakitud, nimes kuupäev (`dateext`), pärast pööramist avab rsyslog failid uuesti.

**Kontrolli:** `sudo logrotate -d /etc/logrotate.d/remote` näitab mõlema masina faile ja `turvalogi.log`-i. Kirjuta `README.md`-sse, miks just nii mitu päeva.

## Esitamine

Oma arvutis repo kaustas:

```bash
scp proxmox2:/etc/rsyslog.d/10-pood.conf       konf/
scp proxmox2:/etc/logrotate.d/pood             konf/pood.logrotate
scp proxmox1:/etc/rsyslog.d/50-keskserver.conf konf/
scp proxmox1:/etc/logrotate.d/remote           konf/remote.logrotate
ssh proxmox2 "ls /var/log/pood*"               > logid/a6-pood.txt
ssh proxmox1 "sudo ls -R /var/log/remote"      > logid/b3-remote.txt
wc -l logid/* konf/*
git add README.md konf logid
git commit -m "Labor 1: öövahetus"
git push
```

Mõne minuti pärast näed GitHubis **Actions** all tulemust. Punase kontrolli korral loe väljundit, paranda, commit, push.

??? note "Automaatkontroll (100 punkti)"

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

    Kodutöö kontrollid on nimega `BOONUS` ja annavad lisapunkte.

## Lisaülesanded

**1. Journali piir.** Piira journal 200 MB-ga.

??? success "Lahendus"

    ```bash
    journalctl --disk-usage
    sudo mkdir -p /etc/systemd/journald.conf.d
    printf '[Journal]\nSystemMaxUse=200M\n' | sudo tee /etc/systemd/journald.conf.d/piir.conf
    sudo systemctl restart systemd-journald
    ```

**2. Poe logid keskserverisse.** `local0` kirjed `proxmox2`-st peavad jõudma keskserverisse, aga mitte `proxmox2` enda `messages`-isse.

??? success "Lahendus"

    `& stop` lõpetab töötlemise enne, kui rsyslog jõuab `90-keskserver.conf`-ini. Saatmisreegel peab olema enne:
    ```bash
    sudo mv /etc/rsyslog.d/90-keskserver.conf /etc/rsyslog.d/05-keskserver.conf
    sudo rsyslogd -N1 && sudo systemctl restart rsyslog
    logger -p local0.info -t pood "tellimus 2002"
    ```
    Muuda failinimi ka playbookis.

**3. Kõige aeglasem päring.** Leia B4 logist päring, mille `aeg=` on suurim.

??? success "Lahendus"

    ```bash
    awk -F'aeg=' '{ split($2, a, "ms"); if (a[1] > max) { max = a[1]; rida = $0 } } END { print rida }' ~/veeb.log
    ```

**4. Kas UDP kaotab?** Lisa `proxmox1`-le UDP sisend (`imudp`, 514/udp, tulemüür). Saada sama 50 000 rida UDP-ga (`logger -n PROXMOX1-IP -P 514 -d -t veebudp -f /tmp/veeb.log`) ja loe, mitu jõudis. Meie testides jõudis kohale 40 000-44 000, tulemus varieerub. Kuhu kadusid ülejäänud ja miks TCP-ga seda ei juhtunud?

**5. Keskserver maas.** Peata `proxmox1`-s rsyslog, saada `proxmox2`-st kolm rida, käivita rsyslog. Ennusta, siis oota kuni minut. Mis oli selles `queue.type` ja `resumeRetryCount` roll?

**6. JSON-kirjed.** Kohtumistel 8-9 lähevad logid otsingusüsteemidesse, mis eelistavad JSON-i. Tee keskserverisse mall, mis kirjutab iga kirje JSON-reana faili `/var/log/remote/koik.json`, tõsidus eraldi väljal.

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
    Mall enne reeglistikku, reeglistikku `action(type="omfile" file="/var/log/remote/koik.json" template="Json")`. Kontroll: `sudo tail -1 /var/log/remote/koik.json | python3 -m json.tool`.

**7. Auditi aruanded.** `aureport -au`: mitu ebaõnnestunud sisselogimist on `proxmox3`-s olnud? Kes kasutas `sudo`-t kõige rohkem (`ausearch -m USER_CMD -i | grep -o 'auid=[^ ]*' | sort | uniq -c`)? Lisa reegel `/etc/passwd` jaoks ja tõesta `useradd`-iga.

**8. Oma valvur.** Skript `proxmox1`-s loeb `turvalogi.log`-ist viimase 5 minuti `Invalid user` read ja kui ühelt IP-lt on üle 5, kirjutab `logger -p authpriv.alert` hoiatuse. Käivita iga minut `systemd` timeriga. Kohtumisel 12 teeb seda Wazuh.

**9. Krüpteeritud saatmine.** TLS `proxmox2` ja `proxmox1` vahel (port 6514, `gtls`, isesigneeritud sertifikaat). Tõesta `tcpdump`-iga, et 514-l oli sõnum loetav ja 6514-l mitte.

**10. Järjekord, mis elab üle taaskäivituse (uurimuslik).** Mälus olev järjekord kaob, kui klient ise taaskäivitub, kui keskserver on maas. Lisa `queue.filename="keskserver"` ja `queue.saveOnShutdown="on"`. Peata keskserver, saada kolm rida, taaskäivita klient, käivita keskserver. Meie testis jäid read kettale (`/var/lib/rsyslog/`) ega jõudnud kohale. Miks? Kuidas parandad?

**11. Kas logi on muudetud?** Lisa `/etc/logrotate.d/remote` `postrotate` plokki käsk, mis arvutab iga pööratud faili `sha256sum`-i faili `/var/log/remote/rasid.txt`. Kuidas tõestad hiljem, et fail on muutmata?

**12. journald ilma rsyslogita.** `systemd-journal-remote` ja `systemd-journal-upload` `proxmox3` ja `proxmox1` vahel. Võrdle rsyslogiga.

## Veaotsing

| Probleem | Põhjus | Lahendus |
|---|---|---|
| `rsyslogd -N1` annab vea | trükiviga | veateates on fail ja rida |
| pärast restarti ei logi masin midagi | vigane konf | `systemctl status rsyslog`, `journalctl -u rsyslog -n 20` |
| `pood.log` puudub pärast pööramist | `postrotate` puudub | A6 |
| `--list-boots` näitab ühte rida pärast rebooti | `/var/log/journal` puudub või `--flush` tegemata | A3 |
| `ausearch` ütleb `<no matches>` | võti erineb või sündmust polnud | `sudo auditctl -l` |
| `ausearch` skriptis ei leia midagi | ilma terminalita loeb ta stdin-i | `--input-logs` |
| `ss -tlnp` ei näita 514 | `imtcp` puudub | `module(load="imtcp")` |
| `proxmox1`-sse ei jõua midagi | tulemüür, IP | B2 vihje |
| `/var/log/remote/` tühi, `journalctl -u rsyslog`: `Permission denied` | tee väljaspool `/var/log/` (SELinux) | tee peab algama `/var/log/` |
| kaustanimi on IP, mitte `proxmox2` | hostinimi seadmata | `hostnamectl set-hostname` |
| `ssh -o User=...` logib sisse sinu kasutajana | `~/.ssh/config`-is on `ControlMaster` | `-o ControlPath=none` |
| playbook: `Could not find or access '90-keskserver.conf'` | fail pole playbooki kõrval | kõik kausta `konf/` |
| `cd /var/log/remote/<proxmox2-nimi>`: `Permission denied` | kaust on `700` | tee koopia (B4) |
