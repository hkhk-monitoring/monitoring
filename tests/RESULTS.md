# Laborite testitulemused

Iga labor käiakse läbi skriptiga `tests/weekNN.sh`. Uuem tulemus asendab sama nädala vana osa.

## week01 - Masina päevik ja logid ühte kohta (labor: öövahetus)

- Käivitatud: 2026-10-14 22:09
- Keskkond: AlmaLinux 9.8 (Olive Jaguar) ×3 (SSH-konf: `tests/.ssh_config`), ansible [core 2.21.5]
- Versioonid: rsyslog-8.2510.0-2.el9.aarch64 logrotate-3.18.0-12.el9.aarch64 audit-3.1.5-8.el9.aarch64 openssh-server-9.9p1-9.el9_8.alma.1.aarch64 
- Tulemus: **111 OK, 1 FAIL**
- Märkused:
    - B4 Mõtle: grep -c 500 = 846, staatus=500 = 748
    - L3 kõige aeglasem: kell=03:14:22 ip=10.0.1.36 meetod=GET url=/api/makse staatus=500 aeg=4995ms id=027995
    - öine külaline: proxmox3: 22:07:37 kasutajad=guest52 backup90 oracle33 cron=/etc/cron.d/varukoopia
    - auid B5-s: auid=lima 
    - L5: keskserver maas, kohale 3/3 ~35 s
    - L4: UDP 50000 reast kohale 44090
    - RAM proxmox1: rsyslogd 7.8 MB (50 000 rida veebilogi sees); 954 MB kokku, 615 MB available
- TESTIMATA: L8 (oma valvur, lahendust pole antud), L9 (TLS), L10 (kettal püsiv järjekord: eeltestis jäid kirjed kettale ega jõudnud kohale; ülesanne on uurimuslik), L11 (räsid), L12 (systemd-journal-remote).

| Samm | Tulemus | Väljund (FAIL korral) |
|---|---|---|
| Eeltöö: ssh proxmox1-3 hostname | OK | |
| Eeltöö: rpm -q, teenused, logrotate.timer | OK | |
| Eeltöö: ansible package rsyslog,logrotate,audit | OK | |
| Eeltöö: ansible service rsyslog started | OK | |
| Eeltöö: proxmox1 IP (192.168.104.3) | OK | |
| A1: logger rida /var/log/messages-is | OK | |
| A1: journalctl -t n01test leiab | OK | |
| A1: -o verbose: PRIORITY=5 SYSLOG_FACILITY=1 _HOSTNAME _PID | OK | |
| A1: audit.log viimane rida algab type= | OK | |
| A1: ausearch -m USER_CMD -i näitab sudo käsku | OK | |
| A2: messages/secure/cron on 600 root | OK | |
| A2: tavakasutaja cat secure -> Permission denied | OK | |
| A2: praktikant ilma grupita: insufficient permissions | OK | |
| A2: praktikant systemd-journal grupis näeb journalit | OK | |
| A2: praktikant ikka ei loe secure-t | OK | |
| A3: algseisus /var/log/journal puudub | OK | |
| A3: /var/log/journal drwxr-sr-x+ root systemd-journal | OK | |
| A3: getfacl: wheel ja adm loevad | OK | |
| A3: pärast rebooti --list-boots >= 2 | OK | |
| A4: secure: Invalid user sissetungija | OK | |
| A4: journalctl -u sshd --since leiab | OK | |
| A4: -p err -b ja -p warning töötavad | OK | |
| A4: last -n 5 töötab | OK | |
| A4: lastb -w: sissetungija täisnimega | OK | |
| A4: messages-is pole Invalid user | OK | |
| A5: vaikereeglid nagu juhendis | OK | |
| A5.2: trükiviga -> unknown facility name locla0 | OK | |
| A5.2: parandatud -> Bye. | OK | |
| A5.3: 1001 pood.log-is ja messages-is | OK | |
| A5.4: & stop -> 1002 ainult pood.log-is | OK | |
| A5.5: hoiatused: warning+err, mitte info | OK | |
| A5.5: pood.log kõik kolm, messages mitte ühtegi | OK | |
| A5.6: programmi filter -N1 ok | OK | |
| A5.6: /var/log/ssh.log sisaldab Invalid user | OK | |
| A6.2: logrotate -d: does not need rotating | OK | |
| A6.4: pood.log puudub, rida pood.log.1-s | OK | |
| A6.6: pärast HUP-i uus rida pood.log-is | OK | |
| A6.6: ls = hoiatused, pood.log, .1-.3.gz | OK | |
| A6.6: zgrep -c leiab pakitud failidest | OK | |
| A7.1: auditctl -l: 3 reeglit | OK | |
| A7.2: audit.log SYSCALL read võtmetega | OK | |
| A7.2: ausearch: comm=truncate auid=lima uid=root | OK | |
| A7.2: aureport -f -i | OK | |
| A7.3: augenrules --load -> 3 reeglit | OK | |
| B1: -N1 ok | OK | |
| B1: kuulab 0.0.0.0:514 rsyslogd | OK | |
| B2: tulemüür kinni -> ei jõua | OK | |
| B2: /dev/tcp: No route to host + kinni | OK | |
| B2: firewall-cmd --list-ports tühi | OK | |
| B2: järjekorras oodanud rida kohal (max 60 s) | OK | |
| B2: kaugrida ei läinud proxmox1 messages-isse | OK | |
| B2 Mõtle: & stop -> 2001 ei jõua keskserverisse | OK | |
| B3: playbook 1. käivitus failed=0 | OK | |
| B3: playbook 2. käivitus changed=0 | OK | |
| B3: proxmox3 rida keskserveris (max 60 s) | OK | |
| B3: proxmox3 auditctl -l = 3 | OK | |
| B4: generaator 50000 rida | OK | |
| B4: keskserveris 50000 rida (max 60 s) | **FAIL** | `bash: line 1: /var/log/remote/proxmox2/veeb.log: Permission denied bash: line 1: [: : integer expected ` |
| B4: cd keskserveri kausta ilma sudota ei õnnestu (700) | OK | |
| B4: koopia kodukausta + chown | OK | |
| B4.1-2: 50000 rida, 748 viga | OK | |
| B4.3-4: 03:12 ja /api/makse | OK | |
| B4.5: 10.0.9.66 459x 02:45:00-02:55:59 | OK | |
| B4.6: sisse pääses 02:56:00 id=024167 | OK | |
| B4.7: id=031337 = /pood 200 | OK | |
| B4 Mõtle: grep 500 annab rohkem | OK | |
| L3: awk leiab aeg >= 4900ms | OK | |
| B5: külalise skript õnnestus | OK | |
| B5: proxmox3 secure grep -c = 0 | OK | |
| B5.1: keskserveris >= 3 kasutajat | OK | |
| B5.1: turvalogi.log sisaldab proxmox3 katseid | OK | |
| B5.2-3: audit: truncate ja /etc/cron.d/varukoopia | OK | |
| B5.3: cron-töö jälg varukoopia.log keskserveris (max 90 s) | OK | |
| B6: logrotate -d leiab proxmox2, proxmox3, turvalogi | OK | |
| Classroom: K1. Kõik failid olemas ja pole tühjad (10 p) | OK | |
| Classroom: K2. 10-pood.conf: hoiatuste reegel enne local0.* rida ja & stop (10 p) | OK | |
| Classroom: K3. pood.logrotate: rotate 3, compress, postrotate HUP (10 p) | OK | |
| Classroom: K4. logid.rules: kolm jälgimisreeglit võtmetega (10 p) | OK | |
| Classroom: K5. a3-boots.txt: journal elab üle taaskäivituse (5 p) | OK | |
| Classroom: K6. 50-keskserver.conf: imtcp, mall, ruleset, authpriv eraldi (10 p) | OK | |
| Classroom: K7. 90-keskserver.conf: omfwd, TCP, järjekord, lõputu kordus (5 p) | OK | |
| Classroom: K8. keskserver.yml: kaks faili, kaks handlerit (10 p) | OK | |
| Classroom: K9. a6-pood.txt: kolm pakitud vana faili, neljandat pole (5 p) | OK | |
| Classroom: K10. b4-otsing.md: õiged vastused (10 p) | OK | |
| Classroom: K11. b5: kasutajad keskserverist, truncate ja cron-fail auditist (10 p) | OK | |
| Classroom: K12. README: vastused täidetud (5 p) | OK | |
| Classroom: tühi starter saab 0 punkti (saab 0) | OK | |
| L1: journald piir 200M | OK | |
| L2: 05- -> 2002 keskserveris (max 60 s) | OK | |
| L2: 2002 ei ole proxmox2 messages-is | OK | |
| L5: mälujärjekord toob 3/3 (max 90 s) | OK | |
| L6: JSON mall -N1 ok | OK | |
| L6: koik.json kehtiv JSON, tosidus=warning (max 60 s) | OK | |
| L7: aureport -au | OK | |
| L4: UDP jõuab vähemalt osaliselt | OK | |
| Kodutöö: logiraport.sh | OK | |
| Classroom pärast kodutööd: K1. Kõik failid olemas ja pole tühjad (10 p) | OK | |
| Classroom pärast kodutööd: K2. 10-pood.conf: hoiatuste reegel enne local0.* rida ja & stop (10 p) | OK | |
| Classroom pärast kodutööd: K3. pood.logrotate: rotate 3, compress, postrotate HUP (10 p) | OK | |
| Classroom pärast kodutööd: K4. logid.rules: kolm jälgimisreeglit võtmetega (10 p) | OK | |
| Classroom pärast kodutööd: K5. a3-boots.txt: journal elab üle taaskäivituse (5 p) | OK | |
| Classroom pärast kodutööd: K6. 50-keskserver.conf: imtcp, mall, ruleset, authpriv eraldi (10 p) | OK | |
| Classroom pärast kodutööd: K7. 90-keskserver.conf: omfwd, TCP, järjekord, lõputu kordus (5 p) | OK | |
| Classroom pärast kodutööd: K8. keskserver.yml: kaks faili, kaks handlerit (10 p) | OK | |
| Classroom pärast kodutööd: K9. a6-pood.txt: kolm pakitud vana faili, neljandat pole (5 p) | OK | |
| Classroom pärast kodutööd: K10. b4-otsing.md: õiged vastused (10 p) | OK | |
| Classroom pärast kodutööd: K11. b5: kasutajad keskserverist, truncate ja cron-fail auditist (10 p) | OK | |
| Classroom pärast kodutööd: K12. README: vastused täidetud (5 p) | OK | |
| Classroom pärast kodutööd: BOONUS 1. Kodutöö: kodutoo/logiraport.sh olemas ja süntaks korras (0 p) | OK | |
| Classroom pärast kodutööd: BOONUS 2. Kodutöö: skript otsib sissetungi katseid ja loendab IP kaupa (0 p) | OK | |
| Classroom pärast kodutööd: BOONUS 3. Kodutöö: raporti väljund ja vastused README-s (0 p) | OK | |
| Link: https://docs.rsyslog.com/doc/ | OK | |

