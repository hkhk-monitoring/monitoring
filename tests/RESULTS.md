# Laborite testitulemused

Iga labor käiakse läbi skriptiga `tests/weekNN.sh`. Uuem tulemus asendab sama nädala vana osa.

## week01 - Masina päevik ja logid ühte kohta

- Käivitatud: 2026-10-14 21:22
- Keskkond: AlmaLinux 9.8 (Olive Jaguar) ×3 (SSH-konf: `tests/.ssh_config`), ansible [core 2.21.5]
- Versioonid: rsyslog-8.2510.0-2.el9.aarch64 logrotate-3.18.0-12.el9.aarch64 openssh-server-9.9p1-9.el9_8.alma.1.aarch64 
- Tulemus: **82 OK, 0 FAIL**
- RAM proxmox1: rsyslogd 6.4 MB (lisakoormust ei ole); sõlm 954 MB kokku, 609 MB available
- Märkused: pärast esimest pööramist ilma postrotate'ita uus pood.log: puudub. Lõpus failid: /var/log/pood-hoiatused.log /var/log/pood.log /var/log/pood.log.1.gz /var/log/pood.log.2.gz /var/log/pood.log.3.gz . proxmox3 failid keskserveris: n01test.log python3.9.log rsyslogd.log sshd-session.log sudo.log systemd.log . L4: udp=100 tcp=100. L5 ootel ridu kohale: 3/3.
- TESTIMATA: L7 (oma skript, lahendust pole antud), L8 (TLS), L9 (systemd-journal-remote).

| Samm | Tulemus | Väljund (FAIL korral) |
|---|---|---|
| Eeltöö: ssh proxmox1-3 hostname = sõlme nimi | OK | |
| Eeltöö: proxmox1 IP leitud (192.168.104.3) | OK | |
| A1: journalctl --list-boots töötab | OK | |
| A1: rsyslog active | OK | |
| A1: rsyslog.conf laeb imjournal | OK | |
| A1: vaikereeglid messages/secure/cron, messages'is authpriv.none | OK | |
| A2: logger rida on /var/log/messages-is | OK | |
| A2: logger rida on journalctl -t n01test väljundis | OK | |
| A2: -o verbose näitab PRIORITY=5 ja SYSLOG_FACILITY=1 | OK | |
| A3: journalctl -u sshd näitab Invalid user sissetungija | OK | |
| A3: /var/log/secure sisaldab Invalid user sissetungija | OK | |
| A3: /var/log/messages EI sisalda Invalid user (authpriv.none) | OK | |
| A4: journalctl -p err -b | wc -l töötab | OK | |
| A4: user.err kirje on journalctl -p err väljundis | OK | |
| A5.2: trükiviga -> rsyslogd -N1 ütleb unknown facility name "locla0" | OK | |
| A5.2: rsyslogd -N1 lõpeb 'End of config validation run. Bye.' | OK | |
| A5.3: tellimus 1001 on pood.log-is | OK | |
| A5.3: tellimus 1001 on ka messages-is | OK | |
| A5.4: & stop -> tellimus 1002 on pood.log-is | OK | |
| A5.4: & stop -> tellimus 1002 EI ole messages-is | OK | |
| A5.5: hoiatuste failis on warning ja err, mitte info | OK | |
| A5.5: pood.log-is on kõik kolm | OK | |
| A5.5: messages-is pole ühtegi kolmest | OK | |
| A6.2: logrotate -d ütleb 'log does not need rotating' | OK | |
| A6.3: pood.log on üle 10k | OK | |
| A6.4: pood.log.1 tekkis | OK | |
| A6.4: ilma postrotate'ita läheb uus rida vanasse faili pood.log.1 | OK | |
| A6.5: logrotate -d uue konfiga (süntaks ok) | OK | |
| A6.5: pärast HUP-i läheb uus rida uude pood.log-i | OK | |
| A6.5: ls /var/log/pood* = hoiatused, pood.log, .1.gz .2.gz .3.gz | OK | |
| B1: proxmox1 kuulab 0.0.0.0:514 (rsyslogd) | OK | |
| B2: proxmox2 rsyslogd -N1 ok | OK | |
| B2: tulemüür kinni -> rida EI jõua proxmox1-sse | OK | |
| B2: /dev/tcp kontroll ütleb 'kinni' ja 'No route to host' | OK | |
| B2: firewall-cmd --list-ports on tühi | OK | |
| B2: /dev/tcp kontroll ütleb 'lahti' | OK | |
| B2: järjekorras oodanud rida jõudis kohale (max 60 s) | OK | |
| B3: proxmox1 rsyslogd -N1 ok (mall + ruleset) | OK | |
| B3: /var/log/remote/proxmox2/n01test.log sisaldab testrida (max 60 s) | OK | |
| B3: uus proxmox2 rida EI läinud messages-isse | OK | |
| B3 Mõtle: & stop -> tellimus 2001 EI jõua keskserverisse | OK | |
| B4: scp proxmox2:/etc/rsyslog.d/90-keskserver.conf . | OK | |
| B4: ansible copy -> proxmox3 | OK | |
| B4: ansible service restarted -> proxmox3 | OK | |
| B4: /var/log/remote/proxmox3/ tekkis ja sisaldab testrida (max 60 s) | OK | |
| B5: proxmox3 secure on tühi (grep -c = 0) | OK | |
| B5: keskserveris on kõik kolm kasutajanime (sudo grep -rh) | OK | |
| B6: logrotate -d leiab mõlema masina failid | OK | |
| L1: journalctl --disk-usage | OK | |
| L3: ruleset authpriv.* süntaks ok | OK | |
| L3: turvalogi.log sisaldab proxmox2 Invalid user l3kontroll (max 60 s) | OK | |
| L2: tellimus 2002 on keskserveris remote/proxmox2/pood.log (max 60 s) | OK | |
| L2: tellimus 2002 EI ole proxmox2 messages-is | OK | |
| L5: järjekorraga jõuavad kõik 3 kohale (max 90 s) | OK | |
| L6: JSON mall süntaks ok | OK | |
| L6: koik.json viimane rida on kehtiv JSON | OK | |
| L6: JSON-is on tosidus=warning | OK | |
| L4: logger -d (UDP) ja -T (TCP) jõuavad keskserverisse | OK | |
| Kodutöö: logiraport.sh näitab masinaid, ridu, katseid ja vigu | OK | |
| Classroom: K1. Kõik failid olemas ja pole tühjad (10 p) | OK | |
| Classroom: K2. 10-pood.conf: hoiatuste reegel enne local0.* rida ja & stop (15 p) | OK | |
| Classroom: K3. pood.logrotate: rotate 3, compress, postrotate HUP (15 p) | OK | |
| Classroom: K4. 50-keskserver.conf: imtcp, mall %HOSTNAME%, ruleset, input seotud reeglistikuga (15 p) | OK | |
| Classroom: K5. 90-keskserver.conf: omfwd, TCP, järjekord, lõputu kordus (10 p) | OK | |
| Classroom: K6. a6-pood.txt: kolm pakitud vana faili, neljandat pole (10 p) | OK | |
| Classroom: K7. b3-remote.txt: keskserveris on kahe masina kaustad (10 p) | OK | |
| Classroom: K8. b5-intsident.txt: vähemalt kolm erinevat olematut kasutajat (10 p) | OK | |
| Classroom: K9. README: vastused täidetud (5 p) | OK | |
| Classroom: tühi starter saab 0 punkti (saab 0) | OK | |
| Classroom pärast kodutööd: K1. Kõik failid olemas ja pole tühjad (10 p) | OK | |
| Classroom pärast kodutööd: K2. 10-pood.conf: hoiatuste reegel enne local0.* rida ja & stop (15 p) | OK | |
| Classroom pärast kodutööd: K3. pood.logrotate: rotate 3, compress, postrotate HUP (15 p) | OK | |
| Classroom pärast kodutööd: K4. 50-keskserver.conf: imtcp, mall %HOSTNAME%, ruleset, input seotud reeglistikuga (15 p) | OK | |
| Classroom pärast kodutööd: K5. 90-keskserver.conf: omfwd, TCP, järjekord, lõputu kordus (10 p) | OK | |
| Classroom pärast kodutööd: K6. a6-pood.txt: kolm pakitud vana faili, neljandat pole (10 p) | OK | |
| Classroom pärast kodutööd: K7. b3-remote.txt: keskserveris on kahe masina kaustad (10 p) | OK | |
| Classroom pärast kodutööd: K8. b5-intsident.txt: vähemalt kolm erinevat olematut kasutajat (10 p) | OK | |
| Classroom pärast kodutööd: K9. README: vastused täidetud (5 p) | OK | |
| Classroom pärast kodutööd: BOONUS 1. Kodutöö: kodutoo/logiraport.sh olemas ja süntaks korras (0 p) | OK | |
| Classroom pärast kodutööd: BOONUS 2. Kodutöö: skript otsib sissetungi katseid ja loendab IP kaupa (0 p) | OK | |
| Classroom pärast kodutööd: BOONUS 3. Kodutöö: raporti väljund ja vastused README-s (0 p) | OK | |
| Link töötab: https://docs.rsyslog.com/doc/ | OK | |

