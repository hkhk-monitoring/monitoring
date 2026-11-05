---
tags:
  - Praktikum
  - Monitooring
  - Logid
  - Linux
---

# Praktikum: öövahetus

Tänase lõpuks kogub `proxmox1` kahe masina logisid: `proxmox2` ja `proxmox3` saadavad oma kirjed TCP kaudu keskserverisse, mis hoiab neid masina ja programmi kaupa eraldi. Kõik kolm masinat jälgivad auditiga, kes muudab logide konfiguratsiooni või turvalogi, ja journal säilib taaskäivitusel. `proxmox3` on seadistatud playbook'iga. Öö lõpus leiad 50 000 reaga veebilogist ründaja ja lahendad intsidendi, kus masina enda logi oli tühjendatud.

<figure style="max-width:690px;margin:.8em auto" class="lx" markdown="0">
<svg viewBox="0 0 690 220" role="img" aria-label="Labori ülesehitus: proxmox2 ja proxmox3 saadavad logid proxmox1 keskserverisse, sinu arvuti juhib Ansible'iga" xmlns="http://www.w3.org/2000/svg">
<style>.lx svg{width:100%;height:auto;font-family:var(--md-text-font-family,sans-serif)}.lx .box{fill:var(--md-code-bg-color);stroke:var(--md-default-fg-color--lighter);stroke-width:1.2}.lx .hi{fill:var(--md-primary-fg-color);fill-opacity:.16;stroke:var(--md-primary-fg-color);stroke-width:1.5}.lx .b{fill:var(--md-default-fg-color);font-size:14.5px;font-weight:600}.lx .s{fill:var(--md-default-fg-color--light);font-size:13px}.lx .c{fill:var(--md-default-fg-color);font-size:12.5px;font-family:var(--md-code-font-family,monospace)}.lx .a{stroke:var(--md-default-fg-color--light);stroke-width:1.5;fill:none}.lx .d{stroke-dasharray:5 4}.lx .h{fill:var(--md-default-fg-color--light)}</style>
<defs><marker id="lxl1" viewBox="0 0 10 10" refX="9" refY="5" markerWidth="6" markerHeight="6" orient="auto"><path class="h" d="M0,0 L10,5 L0,10 z"/></marker></defs>
<rect class="box" x="6" y="80" width="150" height="60" rx="6"/><text class="b" x="81" y="104" text-anchor="middle">Sinu arvuti</text><text class="s" x="81" y="122" text-anchor="middle">ssh, ansible, git</text>
<line class="a d" x1="156" y1="100" x2="236" y2="44" marker-end="url(#lxl1)"/><line class="a d" x1="156" y1="120" x2="236" y2="176" marker-end="url(#lxl1)"/><line class="a d" x1="156" y1="110" x2="500" y2="110" marker-end="url(#lxl1)"/>
<rect class="box" x="238" y="14" width="190" height="60" rx="6"/><text class="b" x="333" y="38" text-anchor="middle">proxmox2</text><text class="s" x="333" y="56" text-anchor="middle">e-pood, osa A, käsitsi</text>
<rect class="box" x="238" y="146" width="190" height="60" rx="6"/><text class="b" x="333" y="170" text-anchor="middle">proxmox3</text><text class="s" x="333" y="188" text-anchor="middle">playbook'iga, öine külaline</text>
<line class="a" x1="428" y1="44" x2="500" y2="84" marker-end="url(#lxl1)"/><line class="a" x1="428" y1="176" x2="500" y2="136" marker-end="url(#lxl1)"/><text class="c" x="470" y="58" text-anchor="middle">TCP 514</text>
<rect class="hi" x="502" y="80" width="182" height="60" rx="6"/><text class="b" x="593" y="104" text-anchor="middle">proxmox1</text><text class="s" x="593" y="122" text-anchor="middle">keskserver /var/log/remote</text>
</svg>
<figcaption>Joonis 1.1. Praktikumi masinad. <code>proxmox2</code> ja <code>proxmox3</code> saadavad logid keskserverisse <code>proxmox1</code>, sinu arvutist käivitad SSH, Ansible'i ja Giti (Talvik, 2026).</figcaption>
</figure>

**Edenemine:** laboritahvel <http://192.168.125.187:8092/> (VPN-iga).

??? abstract "Õpiväljundid"

    Praktikumi lõpuks oskad:

    1. lugeda üht logirida kolmest kohast (rsyslogi fail, journal, auditi logi) ja öelda, mis on iga väli;
    2. kontrollida, kes tohib logisid lugeda, ja anda journalile ligipääs ilma `sudo`-ta;
    3. teha journali püsivaks ja tõendada seda taaskäivitusega;
    4. kirjutada rsyslogi reegli päritolu ja programmi järgi ning kontrollida konfiguratsiooni enne taaskäivitust;
    5. seadistada logrotate'i nii, et rsyslog kirjutab pärast pööramist uude faili;
    6. seadistada auditi reeglid ja leida `auid`-st, kes muudatuse tegi;
    7. ehitada keskse logiserveri ja leida põhjus, kui logid kohale ei jõua;
    8. leida 50 000 reaga logist vastus võttega filtreeri, loenda, vaata.

Osades 2–8 tutvud ühe masinaga juhendi järgi: kolm logi, õigused, püsiv journal, oma rakenduse reegel, logrotate ja audit. Kolm viga teed meelega ja parandad ise. Osades 9–14 on juhiseid vähem: ehitad keskserveri, seadistad kolmanda masina playbook'iga, leiad suurest logist vastused ja uurid intsidenti.

Rida **Ennusta** tähendab, et enne käsku mõtled läbi, mis juhtub. Kirjuta vastus `README.md`-sse enne käsu käivitamist. Oodatav tulemus ja vihjed on kokkuvolditud plokkides.

## Osa 1 · Ettevalmistus

**Masin:** sinu arvuti. Siit ühendud kõigi kolme masinaga.

Kontrolli, et `ssh proxmox1`, `ssh proxmox2` ja `ssh proxmox3` töötavad ilma paroolita ja Ansible töötab sinu arvutis (Linux, macOS või WSL). Kui mõni neist ei tööta, järgi lehte [Töökeskkond](../kodulabor.md).

Ava õpetaja jagatud Classroom 50 link ja klooni oma repositoorium:

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

    `README.md`-sse kirjutad ennustused ja vastused (pealkirjad on olemas). `konf/` ja `logid/` on tõendite jaoks. `tooriistad/tee-suur-logi.sh` on osa 12 jaoks. Ära loe seda enne, seal on vastused.

??? note "Mis repositooriumis lõpuks on"

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

Logimise tööriistad peavad olema igas sõlmes. Tavapaigalduses on need olemas, kuid sõlm võib olla tehtud minimaalsest image'ist. Kontrolli ühte sõlme ja paigalda seejärel puuduvad paketid kõigisse:

```bash
ssh proxmox2 "rpm -q rsyslog logrotate audit; systemctl is-active rsyslog auditd; systemctl list-timers logrotate.timer --no-pager"
ansible all -i proxmox1,proxmox2,proxmox3, -b -m ansible.builtin.package -a "name=rsyslog,logrotate,audit state=present"
ansible all -i proxmox1,proxmox2,proxmox3, -b -m ansible.builtin.service -a "name=rsyslog state=started enabled=true"
ansible all -i proxmox1,proxmox2,proxmox3, -b -m ansible.builtin.service -a "name=auditd state=started enabled=true"
ssh proxmox1 "hostname -I"
```

??? success "Oodatav tulemus"

    Paketid on olemas, teenused `active`, `logrotate.timer` on nimekirjas (veerg `NEXT` ütleb, millal järgmine kord). Ansible vastab iga sõlme kohta `SUCCESS` (oli olemas) või `CHANGED` (paigaldas). `-i proxmox1,proxmox2,proxmox3,` lõpus olev koma ütleb Ansible'ile, et see on nimekiri, mitte faili nimi.

    `rsyslog` ja `auditd` on teenused, mis töötavad kogu aeg. `logrotate` ei ole teenus: selle käivitab kord ööpäevas taimer.

    `hostname -I` esimene aadress (`192.168.35.x`) on `proxmox1` IP. Pane see kirja: sõlmed ei tea nime `proxmox1` (see on ainult sinu `~/.ssh/config`-is) ja ühenduvad omavahel IP-aadressi kaudu.

## Osa 2 · Üks rida, kolm logi

**Masin:** `proxmox2`, kaks terminali.

Ava VS Code'is teine terminal kõrvale (menüü **Terminal → Split Terminal**) ja logi mõlemas sisse: `ssh proxmox2`. Terminal 1 näitab logi (`tail -f`), terminal 2 käivitab käske. Pärast rsyslogi konfiguratsiooni muutmist kontrolli seda käsuga `sudo rsyslogd -N1` ja alles siis taaskäivita rsyslog.

Selle osa lõpuks oskad sama sündmuse leida failist ja journalist ning tead, mille poolest auditi logi neist erineb.

**Ennusta:** kui käivitad `logger`-i, kas rida jõuab journalisse, faili `/var/log/messages` või mõlemasse?

**Terminal 1** jälgib faili `/var/log/messages`. Käsk jääb tööle, jäta see terminal lahti:

```bash
sudo tail -f /var/log/messages
```

**Terminal 2** kirjutab logisse rea ja otsib selle journalist:

```bash
logger -t n01test "tere logi"
journalctl -t n01test -o verbose -n 1
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
    | `uid` | kelle õigustega käsk käivitus |
    | `auid` | kes algselt sisse logis; ei muutu `sudo` järel |
    | `exe`, `cmd` | programm ja käsk |
    | `res` | õnnestus või mitte |

## Osa 3 · Kes tohib lugeda

**Masin:** `proxmox2`.

Selle osa lõpuks on proovikasutajal ligipääs journalile, aga mitte turvalogile.

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

    Praktikant näeb nüüd journalit, aga `cat /var/log/secure` annab ikka `Permission denied`. Kasutaja saab journalit lugeda ilma `sudo`-ta, aga rootile mõeldud tekstilogifaili mitte. Journalis võivad olla samad autentimissündmused, nii et rühm `systemd-journal` annab laia lugemisõiguse: anna see ainult neile, kes seda tööks vajavad.

Kirjuta `README.md`-sse, miks on parem lisada kasutaja gruppi kui anda talle `sudo`. Pärast seda korista: `sudo userdel -r praktikant`.

## Osa 4 · Journal, mis ei unusta

**Masin:** `proxmox2`. Tõendi salvestad oma arvutis repositooriumi kaustas.

Selle osa lõpuks säilib `proxmox2` journal taaskäivitusel ja sul on selle kohta tõend.

**Ennusta:** kas journal säilib praegu taaskäivitusel?

```bash
journalctl --list-boots
ls -ld /var/log/journal
```

??? success "Oodatav tulemus"

    Üks käivitus ja `ls: cannot access '/var/log/journal': No such file or directory`. journald hoiab journalit mälus (`/run/log/journal`) ja taaskäivitusel kaob kõik (loeng, peatükk 5, `Storage=auto`).

Tee journal püsivaks ja kontrolli tulemust taaskäivitusega:

```bash
sudo mkdir -p /var/log/journal
sudo systemd-tmpfiles --create --prefix /var/log/journal   # (1)!
sudo journalctl --flush                                    # (2)!
ls -ld /var/log/journal
sudo reboot
```

1. Paneb kaustale õige grupi ja ACL-id.
2. Kirjutab mälus olnud journali kettale.

Oota pool minutit. Seejärel käivita oma arvutis repositooriumi kaustas:

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

??? warning "Kui `--list-boots` näitab pärast taaskäivitust ühte rida"
    Kaust `/var/log/journal` puudub või `journalctl --flush` jäi tegemata. Korda selle osa käske ja taaskäivita uuesti.

## Osa 5 · Keegi koputab uksele

**Masin:** terminal 1 `proxmox2`-s, terminal 2 sinu arvutis.

Selle osa lõpuks leiad ebaõnnestunud sisselogimise mitmest kohast ja tead, miks see ühes kohas puudub.

Terminal 1 (`proxmox2`): `sudo tail -f /var/log/secure`. Terminal 2 **sinu arvutis**:

```bash
ssh -o User=sissetungija -o PubkeyAuthentication=no proxmox2
```

??? warning "Kui `ssh -o User=…` logib sisse sinu kasutajana"
    Konfiguratsioonifailis `~/.ssh/config` on `ControlMaster` ja SSH kasutab olemasolevat ühendust. Lisa käsule `-o ControlPath=none`.

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

    Logis näed ka ridu `Invalid user kontroll from 192.168.125.187`. See aadress on õpetaja kontrollserver (laboritahvel), mis loeb sinu masinate seisu iga minut. Need read ei ole rünnak.

    `journalctl -u sshd` näitab sama. `lastb -w` näitab katset kahendlogist `btmp` (ilma `-w`-ta oleks nimi `sissetun`). `last` näitab õnnestunud sisselogimisi ja taaskäivitusi.

    `messages`-ist rida ei leia: rsyslogi reeglis on `authpriv.none` (näed seda osa 6 alguses).

Kirjuta `README.md`-sse vigade arv sellest käivitusest ja programm, mis neid kõige rohkem kirjutas (`journalctl -p err -b`).

## Osa 6 · E-poe enda logi

**Masin:** `proxmox2`, kaks terminali.

Selle osa lõpuks on e-poe logid eraldi failides, hoiatused omaette ja SSH-read programmi järgi oma failis.

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

E-pood logib päritoluga `local0`. Loo `/etc/rsyslog.d/10-pood.conf` **meelega veaga**:

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
    `-N1` kontrollib konfiguratsiooni ilma rsyslogi taaskäivitamata. Paranda `local0`, kontrolli uuesti (`End of config validation run. Bye.`), taaskäivita.

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

Kontrolli, taaskäivita, korda osa 5 sissetungija katset ja vaata `sudo tail /var/log/ssh.log`.

??? success "Oodatav tulemus"

    `Invalid user` read on `/var/log/ssh.log`-is. `startswith`, sest programm on `sshd` või `sshd-session`.

??? warning "Kui rsyslog pärast taaskäivitust midagi ei logi"
    Konfiguratsioonis on viga. `sudo rsyslogd -N1` näitab faili ja rea numbrit, `systemctl status rsyslog` ja `journalctl -u rsyslog -n 20` näitavad, miks teenus ei käivitunud.

## Osa 7 · Logi, mis ei täida ketast

**Masin:** `proxmox2`, kaks terminali.

Selle osa lõpuks pöörab logrotate poe logi, vanad failid on pakitud ja rsyslog kirjutab uude faili.

Loo `/etc/logrotate.d/pood`:

```text
/var/log/pood.log /var/log/pood-hoiatused.log {
    size 10k
    rotate 3
    missingok
}
```

**Terminal 2** teeb proovikäigu, kirjutab logisse 300 rida ja pöörab logi:

```bash
sudo logrotate -d /etc/logrotate.d/pood
for i in $(seq 300); do logger -p local0.info -t pood "tellimus $i"; done
sudo logrotate -v /etc/logrotate.d/pood
```

**Terminal 1** jälgib pööratud faili. Käsk jääb tööle:

```bash
sudo tail -f /var/log/pood.log.1
```

**Terminal 2** kirjutab uue rea ja vaatab, kas see jõudis uude faili:

```bash
logger -p local0.info -t pood "pärast pööramist"
sudo tail -1 /var/log/pood.log
```

??? success "Oodatav tulemus"

    Proovikäik ütleb `log does not need rotating`. Pärast 300 rida ja pööramist on `pood.log.1`. Uus rida ilmub terminal 1-sse ehk faili `pood.log.1`, `pood.log`-i ei ole (`No such file or directory`). rsyslog hoiab faili lahti ega tea, et sellel on uus nimi.

Korista ja paranda:

```bash
sudo rm -f /var/log/pood.log.*
sudo systemctl restart rsyslog       # (1)!
```

1. Kustutatud fail, mida rsyslog hoiab lahti, võtab kettal ruumi edasi, kuni rsyslog selle sulgeb. Nii tekib olukord, kus ketas on täis, aga `du` ei leia suurt faili.

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

**Ennusta:** mitu `pood.log.*` faili on alles, kui kirjutad neli korda järjest 300 rida ja pöörad iga kord logi?

```bash
for k in 1 2 3 4; do
  for i in $(seq 300); do logger -p local0.info -t pood "tellimus $i"; done
  sudo logrotate -v /etc/logrotate.d/pood
done
ls /var/log/pood*
sudo zgrep -c "tellimus 150" /var/log/pood.log.*.gz
```

??? success "Oodatav tulemus"

    ```text
    /var/log/pood-hoiatused.log  /var/log/pood.log  /var/log/pood.log.1.gz  /var/log/pood.log.2.gz  /var/log/pood.log.3.gz
    ```
    Neljas pööramine lükkas vanima välja (`rotate 3`). `.1` on kohe pakitud, sest `delaycompress`-i ei ole. `pood-hoiatused.log` jäi pööramata, sest see on alla 10k. `zgrep` otsib pakitud failidest lahti pakkimata. Uus `logger`-i rida läheb nüüd `pood.log`-i.

??? warning "Kui `pood.log` puudub pärast pööramist"
    `postrotate` plokk puudub või rsyslog ei saanud `HUP`-signaali. Siis kirjutab rsyslog edasi vanasse faili, kuni see on lahti.

## Osa 8 · Kes seda tegi

**Masin:** `proxmox2`, kaks terminali. Tõendid salvestad oma arvutis repositooriumi kaustas.

Selle osa lõpuks jälgib audit rsyslogi konfiguratsiooni, turvalogi ja ajastatud töid püsivalt ning sa leiad, kes muudatuse tegi.

**Terminal 2** lisab auditi reeglid:

```bash
sudo auditctl -w /etc/rsyslog.d/ -p wa -k logikonf      # (1)!
sudo auditctl -w /var/log/secure -p wa -k turvalogi
sudo auditctl -w /etc/cron.d/ -p wa -k ajastus
sudo auditctl -l
```

1. `-w` jälgi faili või kausta, `-p wa` kirjutamine ja atribuutide muutmine, `-k` otsinguvõti. Hoiatus `Old style watch rules are slower` on normaalne.

Järgmisena teeb terminal 2 seda, mida ründaja teeks, ja terminal 1 näitab, mida audit sellest kirja paneb.

**Terminal 1** jälgib auditi logi. Käsk jääb tööle, jäta see terminal lahti:

```bash
sudo tail -f /var/log/audit/audit.log | grep --line-buffered -E 'logikonf|turvalogi'
```

!!! warning "Käsk `truncate` tühjendab turvalogi"
    Allpool olev `truncate` kustutab `/var/log/secure` kogu sisu ja seda ei saa taastada. Käivita see ainult `proxmox2`-s pärast seda, kui `auditctl -l` näitab reeglit `turvalogi`. Mujal seda käsku ei kasutata.

**Terminal 2** loob rsyslogi kausta võõra faili ja tühjendab turvalogi. Pärast iga käsku vaata terminal 1-te:

```bash
sudo touch /etc/rsyslog.d/99-tagauks.conf
sudo truncate -s 0 /var/log/secure
```

**Terminal 2** otsib auditist, kes seda tegi, ja kustutab võõra faili:

```bash
sudo ausearch -k turvalogi -i | tail -6
sudo aureport -f -i | tail -5
sudo rm /etc/rsyslog.d/99-tagauks.conf
```

Terminal 1-s peata `tail` klahvidega ++ctrl+c++.

??? success "Oodatav tulemus"

    Terminal 1-sse ilmuvad `type=SYSCALL` read. `ausearch -i` reast leiad:
    ```text
    auid=kasutaja uid=root ... comm=truncate exe=/usr/bin/truncate
    ```
    `uid=root`, sest käsk käivitus `sudo`-ga. `auid` näitab, kes sisse logis, ja seda `sudo` ei muuda.

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

Oma arvutis repositooriumi kaustas:

```bash
ssh proxmox2 "sudo cat /etc/audit/rules.d/logid.rules" > konf/logid.rules
ssh proxmox2 "sudo ausearch --input-logs -k turvalogi -i" > logid/a7-audit.txt
```

??? success "Oodatav tulemus"

    `auditctl -l` näitab kolme reeglit, `konf/logid.rules`-is on kolm rida ja `logid/a7-audit.txt`-is on `comm=truncate` ja sinu kasutaja `auid`-ina.

??? warning "Kui `ausearch` ütleb `<no matches>`"
    Võti on teistsugune või sündmust ei olnud. Kontrolli reegleid käsuga `sudo auditctl -l` ja korda katset.

Kirjuta `README.md`-sse: mis vahe on `uid` ja `auid` väljal ja mis teeb ründaja töö raskemaks, kui ta on root ja saab ka auditi logi kustutada.

## Osa 9 · Keskserver

**Masin:** `proxmox1` (keskserver).

Osadest 9–14 on juhiseid vähem. Iga osa ütleb, mis peab olema tehtud ja kuidas seda kontrollida. Kasuta loengut (peatükid 6 ja 11), [rsyslogi dokumentatsiooni](https://docs.rsyslog.com/doc/) ja osade 2–8 näiteid.

**Nõuded (`proxmox1`, fail `/etc/rsyslog.d/50-keskserver.conf`):**

- võtab vastu TCP kaudu pordil 514;
- võrgust tulnud kirjed ei segune `proxmox1` enda logidega (eraldi `ruleset`);
- iga masina iga programm oma faili: `/var/log/remote/<masin>/<programm>.log`;
- kõigi masinate `authpriv` kirjed lisaks faili `/var/log/remote/turvalogi.log`.

**Kontrolli:** `sudo rsyslogd -N1` on puhas, `sudo ss -tlnp | grep 514` näitab `0.0.0.0:514` ja `rsyslogd`.

??? tip "Vihje: konfiguratsiooni osad"

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

??? warning "Kui `ss -tlnp` ei näita porti 514"
    `module(load="imtcp")` puudub või rsyslog ei taaskäivitunud pärast muudatust.

??? warning "Kui `/var/log/remote/` jääb tühjaks ja `journalctl -u rsyslog` näitab `Permission denied`"
    Failitee on väljaspool kausta `/var/log/`. SELinux lubab rsyslogil kirjutada logifaile ainult sinna, seega peab tee algama `/var/log/`.

**Ennusta:** kui `proxmox2` hakkab saatma ja tulemüüri sa veel ei puuduta, mis juhtub? Kirjuta `README.md`-sse.

## Osa 10 · proxmox2 saadab

**Masin:** `proxmox2`.

**Nõuded (`proxmox2`, fail `/etc/rsyslog.d/90-keskserver.conf`):**

- kõik kirjed (`*.*`) TCP kaudu `proxmox1`-le;
- kui keskserver ei vasta, ootavad kirjed järjekorras ja klient ei loobu kunagi.

!!! warning "Tähelepanu: kausta nimi on masina tegelik nimi"
    `%HOSTNAME%` on masina enda nimi, mitte sinu SSH alias. `proxmox1-3` on ainult sinu `~/.ssh/config`-is, keskserver neid ei tea. Vaata tegelikud nimed järele ja kasuta neid edaspidi `<proxmox2-nimi>` ja `<proxmox3-nimi>` asemel:

    ```bash
    ssh proxmox2 hostname
    ssh proxmox3 hostname
    ```

    Kui kausta nimi on IP-aadress, ei ole masinale hostinime seatud. Sea see käsuga `sudo hostnamectl set-hostname <nimi>`.

**Kontrolli:** `logger -t n01test "siin proxmox2"` ja `proxmox1`-s `sudo cat /var/log/remote/<proxmox2-nimi>/n01test.log`.

??? tip "Vihje: saatmisreegel"

    ```text
    *.* action(type="omfwd" target="PROXMOX1-IP" port="514" protocol="tcp"
               queue.type="LinkedList" queue.size="10000"
               action.resumeRetryCount="-1")
    ```

??? tip "Vihje: kohale ei jõua midagi"

    Alusta kliendist. AlmaLinuxis ei ole `nc` vaikimisi paigaldatud, kuid TCP-ühendust saab proovida bashiga:
    ```bash
    timeout 3 bash -c '</dev/tcp/PROXMOX1-IP/514' && echo lahti || echo kinni
    ```
    `No route to host` ja `kinni` tähendab, et pakett ei jõua rsyslogini, kuigi `ss` näitas, et rsyslog kuulab. Kontrolli IP-aadressi ja tulemüüri. Selles praktikumis alusta `proxmox1` tulemüürist: `sudo firewall-cmd --list-ports`.

??? success "Oodatav tulemus"

    Esimene rida ei jõua kohale, sest `proxmox1` tulemüür ei luba porti 514. Pärast `sudo firewall-cmd --permanent --add-port=514/tcp && sudo firewall-cmd --reload` jõuab see **minuti jooksul ikkagi kohale**: klient hoidis seda järjekorras ja proovis uuesti umbes iga 30 sekundi järel. Sama viivitus tuleb iga kord pärast keskserveri taaskäivitust.

    `logger -p local0.info -t pood "tellimus 2001"` ei jõua keskserverisse. `10-pood.conf` teeb `& stop` enne, kui rsyslog jõuab faili `90-keskserver.conf`-ini (failid loetakse tähestiku järjekorras). Parandus on lisaülesanne 2.

## Osa 11 · proxmox3 playbook'iga

**Masin:** sinu arvuti. Playbook seadistab `proxmox3`.

`proxmox3` vajab sama saatmisreeglit ja samu auditi reegleid. Seadista see playbook'iga. Playbook on Gitis ja sobib ka järgmise masina seadistamiseks.

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

??? tip "Vihje: playbook'i ülesehitus"

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
    `src` otsitakse playbook'i kõrvalt, seega kõik kolm faili kausta `konf/`.

??? warning "Kui playbook annab `Could not find or access '90-keskserver.conf'`"
    Fail ei ole playbook'iga samas kaustas. Pane `keskserver.yml`, `90-keskserver.conf` ja `logid.rules` kausta `konf/`.

## Osa 12 · Mis juhtus öösel

**Masin:** logi teeb `proxmox2`, otsing käib `proxmox1`-s.

Rakendus kirjutas öösel 3 GB logi ja tekstiredaktor keeldub seda avamast. Sellisest logist otsitakse vastuseid käskudega `grep`, `sort` ja `uniq`.

Saada keskserverisse e-poe veebilogi ühe öö kohta (01:00–05:00, 50 000 rida). Oma arvutist:

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

Keskserveri kaustad on `700`, `cd /var/log/remote/<proxmox2-nimi>` annab `Permission denied`. Logi on ka tõend ja originaali ei muudeta. Tee `proxmox1`-s koopia:

```bash
sudo cp /var/log/remote/<proxmox2-nimi>/veeb.log ~/
sudo chown $USER ~/veeb.log
```

**Ülesanne.** Leia vastused `proxmox1`-s ja kirjuta need oma arvutis repositooriumi faili `logid/b4-otsing.md` koos käsuga, millega leidsid:

1. Mitu rida on logis?
2. Mitu päringut lõppes veaga `500`?
3. Mis minutil oli vigu `500` kõige rohkem?
4. Milline URL andis vigu `500` kõige rohkem?
5. Üks IP-aadress proovis `/login`-iga paroole (`staatus=401`). Milline, mitu korda, mis kellast mis kellani?
6. Kas ta pääses sisse? Kui jah, mis kell ja mis `id`-ga päring?
7. Mis juhtus päringuga `id=031337`?

??? tip "Vihje: töövõte"

    Filtreeri, loenda, vaata (loeng, peatükk 12). Näiteks küsimus 3:
    ```bash
    grep 'staatus=500' veeb.log | grep -o 'kell=..:..' | sort | uniq -c | sort -rn | head -3
    ```
    Küsimus 6: võta kõik selle IP read ja jäta välja ebaõnnestunud (`grep -v`).

Kirjuta `README.md`-sse: kas `grep 500` oleks sama hea kui `grep 'staatus=500'`? Proovi `grep -c 500` ja selgita vahet.

## Osa 13 · Öine külaline

**Masin:** külastus on `proxmox3`-s, uurimine `proxmox1`-s ja `proxmox3`-s.

Eeldus: osad 9–11 on tehtud ehk `proxmox3` saadab logid keskserverisse ja auditi reeglid on peal. Muidu ei ole sul pärast külastust midagi uurida.

Öövahetuse ajal võib õpetaja korraldada sinu `proxmox3`-le "külastuse". Sa ei tea, millal, kust ega mida tehakse. Kui õpetaja ütleb "nüüd" või tahvel näitab muutust, alusta uurimist.

Kui teed praktikumi kodus või külastust ei tulnud, tee see ise oma arvutist:

!!! warning "Käsk `truncate` tühjendab `proxmox3` turvalogi"
    Turvalogi sisu kaob jäädavalt. Enne käivitamist kontrolli, et `ssh proxmox3 "sudo auditctl -l"` näitab reeglit `turvalogi`.

```bash
for u in admin root2 test; do
  ssh -o User=$u -o PubkeyAuthentication=no -o ConnectTimeout=5 proxmox3
done
ssh proxmox3 "sudo truncate -s 0 /var/log/secure"
ssh proxmox3 "echo '* * * * * root /usr/bin/logger -t uuendus kontroll' | sudo tee /etc/cron.d/uuendus"
```

`ssh proxmox3 "sudo grep -c 'Invalid user' /var/log/secure"` annab nüüd `0`.

Kasutaja `kontroll` aadressilt `192.168.125.187` on õpetaja kontrollserver (laboritahvel, vt osa 5). Need read ei ole rünnak, jäta need intsidendiraportist välja.

**Uurimine:**

1. Mis juhtus? Leia keskserverist kõik kasutajanimed, IP-aadressid ja kellaajad.
2. Kes tühjendas `proxmox3` turvalogi ja mis kell?
3. Mis jäeti maha? Eemalda see.

```bash
P3=$(ssh proxmox3 hostname)
ssh proxmox1 "sudo grep -rh 'Invalid user' /var/log/remote/$P3/" > logid/b5-intsident.txt
ssh proxmox3 "sudo ausearch --input-logs -k turvalogi -i; sudo ausearch --input-logs -k ajastus -i" > logid/b5-audit.txt
```

??? tip "Vihje"

    `grep -r` otsib kõigist kausta failidest. `sudo grep ... /var/log/remote/$P3/*.log` ei tööta: `*` laiendab sinu shell enne `sudo`-t ja sina kausta ei näe. Maha jäetud asi kirjutab keskserverisse iga minut uue rea ja audit (`-k ajastus`) teab, kes selle tegi.

Kirjuta `README.md`-sse intsidendiraport: mis juhtus, millal, kust, kes kattis jäljed, mis jäeti maha ja kuidas sa selle leidsid.

## Osa 14 · Keskserveri logide pööramine

**Masin:** `proxmox1` (keskserver).

**Nõuded (`proxmox1`, `/etc/logrotate.d/remote`):** failid `/var/log/remote/*/*.log` ja `/var/log/remote/turvalogi.log`, iga päev, 30 vana faili, pakitud, nimes kuupäev (`dateext`), pärast pööramist avab rsyslog failid uuesti.

**Kontrolli:** `sudo logrotate -d /etc/logrotate.d/remote` näitab mõlema masina faile ja `turvalogi.log`-i. Kirjuta `README.md`-sse, miks just nii mitu päeva.

## Töö esitamine

Repositooriumis on rsyslogi, logrotate'i ja auditi konfiguratsioonifailid, playbook ning tõendid kaustas `logid/`. Kopeeri puuduvad failid masinatest ja saada töö oma arvutist:

```bash
scp proxmox2:/etc/rsyslog.d/10-pood.conf       konf/
scp proxmox2:/etc/logrotate.d/pood             konf/pood.logrotate
scp proxmox1:/etc/rsyslog.d/50-keskserver.conf konf/
scp proxmox1:/etc/logrotate.d/remote           konf/remote.logrotate
ssh proxmox2 "ls /var/log/pood*"               > logid/a6-pood.txt
ssh proxmox1 "sudo ls -R /var/log/remote"      > logid/b3-remote.txt
git status
git add README.md konf logid
git commit -m "Praktikum 1: öövahetus"
git push
```

Tulemuse näed Classroom 50-s.

## Lisaülesanded

??? example "1 · Journali piir"
    Piira journal 200 MB-ga.

    ??? success "Lahendus"

        ```bash
        journalctl --disk-usage
        sudo mkdir -p /etc/systemd/journald.conf.d
        printf '[Journal]\nSystemMaxUse=200M\n' | sudo tee /etc/systemd/journald.conf.d/piir.conf
        sudo systemctl restart systemd-journald
        ```

??? example "2 · Poe logid keskserverisse"
    `local0` kirjed `proxmox2`-st peavad jõudma keskserverisse, aga mitte `proxmox2` enda `messages`-isse.

    ??? success "Lahendus"

        `& stop` lõpetab töötlemise enne, kui rsyslog jõuab `90-keskserver.conf`-ini. Saatmisreegel peab olema enne:
        ```bash
        sudo mv /etc/rsyslog.d/90-keskserver.conf /etc/rsyslog.d/05-keskserver.conf
        sudo rsyslogd -N1 && sudo systemctl restart rsyslog
        logger -p local0.info -t pood "tellimus 2002"
        ```
        Muuda failinimi ka playbook'is ja kopeeri fail repositooriumisse nimega `konf/05-keskserver.conf`. Playbook peab `proxmox3`-st vana faili eemaldama, muidu saadab `proxmox3` iga rea kaks korda:
        ```yaml
        - name: Vana saatmisreegel ära
          ansible.builtin.file:
            path: /etc/rsyslog.d/90-keskserver.conf
            state: absent
          notify: Taaskäivita rsyslog
        ```

??? example "3 · Kõige aeglasem päring"
    Leia osa 12 logist päring, mille `aeg=` on suurim.

    ??? success "Lahendus"

        ```bash
        awk -F'aeg=' '{ split($2, a, "ms"); if (a[1] > max) { max = a[1]; rida = $0 } } END { print rida }' ~/veeb.log
        ```

??? example "4 · Kas UDP kaotab?"
    Lisa `proxmox1`-le UDP sisend (`imudp`, 514/udp, tulemüür). Saada sama 50 000 rida UDP-ga (`logger -n PROXMOX1-IP -P 514 -d -t veebudp -f /tmp/veeb.log`) ja loe, mitu jõudis. Meie testides jõudis kohale 40 000–44 000, tulemus varieerub. Kuhu kadusid ülejäänud ja miks TCP-ga seda ei juhtunud?

??? example "5 · Keskserver maas"
    Peata `proxmox1`-s rsyslog, saada `proxmox2`-st kolm rida, käivita rsyslog. Ennusta, siis oota kuni minut. Mis oli selles `queue.type` ja `resumeRetryCount` roll?

??? example "6 · JSON-kirjed"
    Kohtumistel 8–9 lähevad logid otsingusüsteemidesse, mis eelistavad JSON-i. Tee keskserverisse mall, mis kirjutab iga kirje JSON-reana faili `/var/log/remote/koik.json`, tõsidus eraldi väljal.

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

??? example "7 · Auditi aruanded"
    `aureport -au`: mitu ebaõnnestunud sisselogimist on `proxmox3`-s olnud? Kes kasutas `sudo`-t kõige rohkem (`ausearch -m USER_CMD -i | grep -o 'auid=[^ ]*' | sort | uniq -c`)? Lisa reegel `/etc/passwd` jaoks ja tõesta `useradd`-iga.

??? example "8 · Oma valvur"
    Skript `proxmox1`-s loeb `turvalogi.log`-ist viimase 5 minuti `Invalid user` read ja kui ühelt IP-lt on üle 5, kirjutab `logger -p authpriv.alert` hoiatuse. Käivita iga minut systemd taimeriga. Kohtumisel 12 teeb seda Wazuh.

??? example "9 · Krüpteeritud saatmine"
    TLS `proxmox2` ja `proxmox1` vahel (port 6514, `gtls`, isesigneeritud sertifikaat). Tõesta `tcpdump`-iga, et 514-l oli sõnum loetav ja 6514-l mitte.

??? example "10 · Järjekord, mis säilib taaskäivitusel (uurimuslik)"
    Mälus olev järjekord kaob, kui klient ise taaskäivitub, kui keskserver on maas. Lisa `queue.filename="keskserver"` ja `queue.saveOnShutdown="on"`. Peata keskserver, saada kolm rida, taaskäivita klient, käivita keskserver. Meie testis jäid read kettale (`/var/lib/rsyslog/`) ega jõudnud kohale. Miks? Kuidas parandad?

??? example "11 · Kas logi on muudetud?"
    Lisa `/etc/logrotate.d/remote` `postrotate` plokki käsk, mis arvutab iga pööratud faili `sha256sum`-i faili `/var/log/remote/rasid.txt`. Kuidas tõestad hiljem, et fail on muutmata?

??? example "12 · journald ilma rsyslogita"
    `systemd-journal-remote` ja `systemd-journal-upload` `proxmox3` ja `proxmox1` vahel. Võrdle rsyslogiga.
