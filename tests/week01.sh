#!/bin/bash
# Kohtumine 1 labori test: käib docs/week01/lab.md läbi nagu õppija ja kontrollib oodatavaid tulemusi.
#
# Kasutus:
#   SSH_CONFIG=tests/.ssh_config bash tests/week01.sh      # lima testkeskkond (tests/lima-setup.sh up)
#   bash tests/week01.sh                                   # päris sõlmed, sinu ~/.ssh/config
#
# Eeldus: ssh proxmox1/2/3 töötab ilma paroolita ja kasutajal on sudo ilma paroolita (või NOPASSWD).
# Skript koristab enne ja pärast enda tehtud failid. Tulemus: tests/RESULTS.md (week01 osa).
set -uo pipefail
cd "$(dirname "$0")/.."

CFG="${SSH_CONFIG:-$HOME/.ssh/config}"; CFG="$(cd "$(dirname "$CFG")" && pwd)/$(basename "$CFG")"
SSHOPT=(-F "$CFG" -o BatchMode=yes -o ConnectTimeout=10)
S() { local h=$1; shift; ssh "${SSHOPT[@]}" "$h" "RUN=${RUN:-0}; $*"; }   # $RUN on ka kaugkäsus olemas
# "Võõras" sisselogimine: ilma ühenduse taaskasutuseta, et sshd näeks päris katset
SISSE() { ssh "${SSHOPT[@]}" -o ControlMaster=no -o ControlPath=none -o PubkeyAuthentication=no -o User="$1" "$2" true >/dev/null 2>&1; }
export ANSIBLE_SSH_ARGS="-F $CFG" ANSIBLE_HOST_KEY_CHECKING=False ANSIBLE_STDOUT_CALLBACK=minimal

RUN=$(date +%H%M%S)   # jooksu märgis, et vanad read ei segaks
TMP=$(mktemp -d)
LOG="$TMP/log.md"
OK=0; FAIL=0
samm() {  # samm "nimi" käsk...   -> OK, kui käsk lõpeb koodiga 0
  local nimi=$1; shift
  if out=$("$@" 2>&1); then
    echo "| $nimi | OK | |" >> "$LOG"; OK=$((OK+1)); echo "OK   $nimi"
  else
    local lyhi; lyhi=$(echo "$out" | tail -3 | tr '\n|' ' /' | cut -c1-160)
    echo "| $nimi | **FAIL** | \`$lyhi\` |" >> "$LOG"; FAIL=$((FAIL+1)); echo "FAIL $nimi"; echo "$out" | tail -5 | sed 's/^/     /'
  fi
}
on()  { grep -q -- "$1" <<< "$2"; }     # on "muster" "$tekst"
oota() { for _ in $(seq 12); do "$@" >/dev/null 2>&1 && return 0; sleep 5; done; "$@"; }   # kuni 60 s

koristus() {
  for h in proxmox1 proxmox2 proxmox3; do
    S $h 'sudo rm -f /etc/rsyslog.d/10-pood.conf /etc/rsyslog.d/50-keskserver.conf /etc/rsyslog.d/90-keskserver.conf \
             /etc/logrotate.d/pood /etc/logrotate.d/remote /var/log/pood* ; sudo rm -rf /var/log/remote ~/logiraport.sh
          sudo firewall-cmd --permanent --remove-port=514/tcp >/dev/null 2>&1; sudo firewall-cmd --permanent --remove-port=514/udp >/dev/null 2>&1
          sudo firewall-cmd --reload >/dev/null 2>&1; sudo systemctl restart rsyslog' 2>/dev/null
  done
  rm -f "$TMP/90-keskserver.conf"
}

echo "== Koristus enne"
koristus

# ---------------- Eeltöö ----------------
t_hostid() { for h in proxmox1 proxmox2 proxmox3; do [ "$(S $h hostname)" = "$h" ] || return 1; done; }
samm "Eeltöö: ssh proxmox1-3 hostname = sõlme nimi" t_hostid
P1=$(S proxmox1 "hostname -I" | awk '{print $1}')
samm "Eeltöö: proxmox1 IP leitud ($P1)" test -n "$P1"

# ---------------- Osa A (proxmox2) ----------------
samm "A1: journalctl --list-boots töötab" S proxmox2 'journalctl --list-boots | tail -3'
samm "A1: rsyslog active" bash -c "[ \"\$(ssh ${SSHOPT[*]} proxmox2 systemctl is-active rsyslog)\" = active ]"
samm "A1: rsyslog.conf laeb imjournal" S proxmox2 'grep -q "module(load=\"imjournal\"" /etc/rsyslog.conf'
t_a1reeglid() { local o; o=$(S proxmox2 "grep -v -E '^#|^\$' /etc/rsyslog.conf | grep /var/log"); on '/var/log/messages' "$o" && on 'authpriv.none' "$o" && on '/var/log/secure' "$o" && on '/var/log/cron' "$o"; }
samm "A1: vaikereeglid messages/secure/cron, messages'is authpriv.none" t_a1reeglid

S proxmox2 'logger -t n01test "tere päevik"'; sleep 1
samm "A2: logger rida on /var/log/messages-is" S proxmox2 'sudo grep -q "n01test.*tere päevik" /var/log/messages'
samm "A2: logger rida on journalctl -t n01test väljundis" S proxmox2 'journalctl -t n01test --no-pager | grep -q "tere päevik"'
t_a2verbose() { local o; o=$(S proxmox2 'journalctl -t n01test -o verbose -n 1 --no-pager'); on 'PRIORITY=5' "$o" && on 'SYSLOG_FACILITY=1' "$o"; }
samm "A2: -o verbose näitab PRIORITY=5 ja SYSLOG_FACILITY=1" t_a2verbose

SISSE sissetungija proxmox2; sleep 1
samm "A3: journalctl -u sshd näitab Invalid user sissetungija" S proxmox2 'sudo journalctl -u sshd --since "5 min ago" --no-pager | grep -q "Invalid user sissetungija"'
samm "A3: /var/log/secure sisaldab Invalid user sissetungija" S proxmox2 'sudo grep -q "Invalid user sissetungija" /var/log/secure'
samm "A3: /var/log/messages EI sisalda Invalid user (authpriv.none)" S proxmox2 '! sudo grep -q "Invalid user sissetungija" /var/log/messages'

samm "A4: journalctl -p err -b | wc -l töötab" S proxmox2 'journalctl -p err -b --no-pager | wc -l'
S proxmox2 'logger -p user.err -t n01test "midagi läks katki"'; sleep 1
samm "A4: user.err kirje on journalctl -p err väljundis" S proxmox2 'journalctl -p err -b --no-pager | grep -q "midagi läks katki"'

# A5 samm 1-3
S proxmox2 'echo "locla0.*    /var/log/pood.log" | sudo tee /etc/rsyslog.d/10-pood.conf >/dev/null'
samm "A5.2: trükiviga -> rsyslogd -N1 ütleb unknown facility name \"locla0\"" S proxmox2 'sudo rsyslogd -N1 2>&1 | grep -q "unknown facility name \"locla0\""'
S proxmox2 'echo "local0.*    /var/log/pood.log" | sudo tee /etc/rsyslog.d/10-pood.conf >/dev/null'
samm "A5.2: rsyslogd -N1 lõpeb 'End of config validation run. Bye.'" S proxmox2 'sudo rsyslogd -N1 2>&1 | grep -q "End of config validation run. Bye."'
S proxmox2 'sudo systemctl restart rsyslog; logger -p local0.info -t pood "tellimus 1001 vastu võetud"'; sleep 1
samm "A5.3: tellimus 1001 on pood.log-is" S proxmox2 'sudo grep -q "tellimus 1001" /var/log/pood.log'
samm "A5.3: tellimus 1001 on ka messages-is" S proxmox2 'sudo grep -q "tellimus 1001" /var/log/messages'
# A5 samm 4
S proxmox2 'printf "local0.*    /var/log/pood.log\n& stop\n" | sudo tee /etc/rsyslog.d/10-pood.conf >/dev/null; sudo rsyslogd -N1 >/dev/null 2>&1 && sudo systemctl restart rsyslog; logger -p local0.info -t pood "tellimus 1002"'; sleep 1
samm "A5.4: & stop -> tellimus 1002 on pood.log-is" S proxmox2 'sudo grep -q "tellimus 1002" /var/log/pood.log'
samm "A5.4: & stop -> tellimus 1002 EI ole messages-is" S proxmox2 '! sudo grep -q "tellimus 1002" /var/log/messages'
# A5 samm 5
S proxmox2 'printf "local0.warning    /var/log/pood-hoiatused.log\nlocal0.*          /var/log/pood.log\n& stop\n" | sudo tee /etc/rsyslog.d/10-pood.conf >/dev/null
  sudo rsyslogd -N1 >/dev/null 2>&1 && sudo systemctl restart rsyslog
  logger -p local0.info    -t pood "tellimus 1003 $RUN"
  logger -p local0.warning -t pood "laos alla 5 toote $RUN"
  logger -p local0.err     -t pood "makse ebaõnnestus $RUN"'; sleep 1
samm "A5.5: hoiatuste failis on warning ja err, mitte info" S proxmox2 'sudo grep -q "laos alla 5 toote $RUN" /var/log/pood-hoiatused.log && sudo grep -q "makse ebaõnnestus $RUN" /var/log/pood-hoiatused.log && ! sudo grep -q "tellimus 1003 $RUN" /var/log/pood-hoiatused.log'
samm "A5.5: pood.log-is on kõik kolm" S proxmox2 'for s in "tellimus 1003 $RUN" "laos alla 5 toote $RUN" "makse ebaõnnestus $RUN"; do sudo grep -q "$s" /var/log/pood.log || exit 1; done'
samm "A5.5: messages-is pole ühtegi kolmest" S proxmox2 '! sudo grep -q -E "(tellimus 1003|laos alla 5 toote|makse ebaõnnestus) $RUN" /var/log/messages'

# A6 samm 1-4 (ilma postrotate'ita)
S proxmox2 'printf "/var/log/pood.log /var/log/pood-hoiatused.log {\n    size 10k\n    rotate 3\n    missingok\n}\n" | sudo tee /etc/logrotate.d/pood >/dev/null'
samm "A6.2: logrotate -d ütleb 'log does not need rotating'" S proxmox2 'sudo logrotate -d /etc/logrotate.d/pood 2>&1 | grep -q "log does not need rotating"'
S proxmox2 'for i in $(seq 300); do logger -p local0.info -t pood "tellimus $i"; done'; sleep 2
samm "A6.3: pood.log on üle 10k" S proxmox2 '[ $(sudo stat -c %s /var/log/pood.log) -gt 10240 ]'
S proxmox2 'sudo logrotate -v /etc/logrotate.d/pood >/dev/null 2>&1; logger -p local0.info -t pood "pärast pööramist"'; sleep 1
samm "A6.4: pood.log.1 tekkis" S proxmox2 'sudo test -f /var/log/pood.log.1'
samm "A6.4: ilma postrotate'ita läheb uus rida vanasse faili pood.log.1" S proxmox2 'sudo grep -q "pärast pööramist" /var/log/pood.log.1'
A6_UUS=$(S proxmox2 'sudo test -f /var/log/pood.log && echo olemas || echo puudub')
echo "     (info: pärast esimest pööramist on uus pood.log: $A6_UUS)"
# A6 samm 5: vanad failid ära, siis postrotate'iga
S proxmox2 'sudo rm -f /var/log/pood.log.*; sudo systemctl restart rsyslog; printf "/var/log/pood.log /var/log/pood-hoiatused.log {\n    size 10k\n    rotate 3\n    compress\n    missingok\n    notifempty\n    postrotate\n        /usr/bin/systemctl kill -s HUP rsyslog.service >/dev/null 2>&1 || true\n    endscript\n}\n" | sudo tee /etc/logrotate.d/pood >/dev/null'
samm "A6.5: logrotate -d uue konfiga (süntaks ok)" S proxmox2 'sudo logrotate -d /etc/logrotate.d/pood 2>&1 | grep -q -v "error"'
for k in 1 2 3 4; do
  S proxmox2 'for i in $(seq 300); do logger -p local0.info -t pood "tellimus $i"; done; sleep 2; sudo logrotate -v /etc/logrotate.d/pood >/dev/null 2>&1; sleep 1'
done
S proxmox2 'logger -p local0.info -t pood "pärast HUP-i"'; sleep 1
samm "A6.5: pärast HUP-i läheb uus rida uude pood.log-i" S proxmox2 'sudo grep -q "pärast HUP-i" /var/log/pood.log'
samm "A6.5: ls /var/log/pood* = hoiatused, pood.log, .1.gz .2.gz .3.gz" bash -c "[ \"\$(ssh ${SSHOPT[*]} proxmox2 'ls /var/log/pood*' | tr '\n' ' ')\" = '/var/log/pood-hoiatused.log /var/log/pood.log /var/log/pood.log.1.gz /var/log/pood.log.2.gz /var/log/pood.log.3.gz ' ]"
A6_LS=$(S proxmox2 'ls /var/log/pood*' | tr '\n' ' ')
echo "     (info: $A6_LS)"

# ---------------- Osa B ----------------
S proxmox1 'printf "module(load=\"imtcp\")\ninput(type=\"imtcp\" port=\"514\")\n" | sudo tee /etc/rsyslog.d/50-keskserver.conf >/dev/null; sudo rsyslogd -N1 >/dev/null 2>&1 && sudo systemctl restart rsyslog'
samm "B1: proxmox1 kuulab 0.0.0.0:514 (rsyslogd)" S proxmox1 'sudo ss -tlnp | grep -E "0.0.0.0:514 " | grep -q rsyslogd'

S proxmox2 "printf '*.* action(type=\"omfwd\" target=\"$P1\" port=\"514\" protocol=\"tcp\"\n           queue.type=\"LinkedList\" queue.size=\"10000\"\n           action.resumeRetryCount=\"-1\")\n' | sudo tee /etc/rsyslog.d/90-keskserver.conf >/dev/null"
samm "B2: proxmox2 rsyslogd -N1 ok" S proxmox2 'sudo rsyslogd -N1 2>&1 | grep -q "End of config validation run. Bye."'
S proxmox2 "sudo systemctl restart rsyslog && logger -t n01test 'tere keskserver, siin proxmox2 $RUN'"; sleep 3
FW=$(S proxmox1 'sudo firewall-cmd --state 2>/dev/null || echo off')
if [ "$FW" = running ]; then
  samm "B2: tulemüür kinni -> rida EI jõua proxmox1-sse" S proxmox1 "! sudo grep -q 'siin proxmox2 $RUN' /var/log/messages"
  samm "B2: /dev/tcp kontroll ütleb 'kinni' ja 'No route to host'" bash -c "o=\$(ssh ${SSHOPT[*]} proxmox2 \"timeout 3 bash -c '</dev/tcp/$P1/514' && echo lahti || echo kinni\" 2>&1); grep -q kinni <<< \"\$o\" && grep -q 'No route to host' <<< \"\$o\""
  samm "B2: firewall-cmd --list-ports on tühi" bash -c "[ -z \"\$(ssh ${SSHOPT[*]} proxmox1 'sudo firewall-cmd --list-ports' | tr -d ' ')\" ]"
  S proxmox1 'sudo firewall-cmd --permanent --add-port=514/tcp >/dev/null && sudo firewall-cmd --reload >/dev/null'
else
  echo "     (info: firewalld proxmox1-s väljas, tulemüüri viga ei testitud)"
fi
samm "B2: /dev/tcp kontroll ütleb 'lahti'" S proxmox2 "timeout 3 bash -c '</dev/tcp/$P1/514' && echo lahti | grep -q lahti"
samm "B2: järjekorras oodanud rida jõudis kohale (max 60 s)" oota S proxmox1 "sudo grep -q 'proxmox2 .*siin proxmox2 $RUN' /var/log/messages"

S proxmox1 'printf "module(load=\"imtcp\")\n\ntemplate(name=\"MasinaKaupa\" type=\"string\"\n         string=\"/var/log/remote/%%HOSTNAME%%/%%PROGRAMNAME%%.log\")\n\nruleset(name=\"kaugelt\") {\n    action(type=\"omfile\" dynaFile=\"MasinaKaupa\")\n}\n\ninput(type=\"imtcp\" port=\"514\" ruleset=\"kaugelt\")\n" | sudo tee /etc/rsyslog.d/50-keskserver.conf >/dev/null'
samm "B3: proxmox1 rsyslogd -N1 ok (mall + ruleset)" S proxmox1 'sudo rsyslogd -N1 2>&1 | grep -q "End of config validation run. Bye."'
S proxmox1 'sudo systemctl restart rsyslog'; sleep 1
S proxmox2 "logger -t n01test 'nüüd oma kausta $RUN'"
samm "B3: /var/log/remote/proxmox2/n01test.log sisaldab testrida (max 60 s)" oota S proxmox1 "sudo grep -q 'nüüd oma kausta $RUN' /var/log/remote/proxmox2/n01test.log"
samm "B3: uus proxmox2 rida EI läinud messages-isse" S proxmox1 "! sudo grep -q 'nüüd oma kausta $RUN' /var/log/messages"
S proxmox2 'logger -p local0.info -t pood "tellimus 2001"'; sleep 3
samm "B3 Mõtle: & stop -> tellimus 2001 EI jõua keskserverisse" S proxmox1 '! sudo grep -rq "tellimus 2001" /var/log/remote/'

# B4 Ansible
samm "B4: scp proxmox2:/etc/rsyslog.d/90-keskserver.conf ." scp -F "$CFG" -o BatchMode=yes proxmox2:/etc/rsyslog.d/90-keskserver.conf "$TMP/"
samm "B4: ansible copy -> proxmox3" bash -c "cd '$TMP' && ansible all -i proxmox3, -b -m ansible.builtin.copy -a 'src=90-keskserver.conf dest=/etc/rsyslog.d/90-keskserver.conf'"
samm "B4: ansible service restarted -> proxmox3" ansible all -i proxmox3, -b -m ansible.builtin.service -a "name=rsyslog state=restarted"
S proxmox3 "logger -t n01test 'siin proxmox3 $RUN'"
samm "B4: /var/log/remote/proxmox3/ tekkis ja sisaldab testrida (max 60 s)" oota S proxmox1 "sudo grep -q 'siin proxmox3 $RUN' /var/log/remote/proxmox3/n01test.log"

# B5 intsident
for u in admin root2 test; do SISSE $u proxmox3; done; sleep 2
S proxmox3 'sudo truncate -s 0 /var/log/secure'
samm "B5: proxmox3 secure on tühi (grep -c = 0)" bash -c "[ \"\$(ssh ${SSHOPT[*]} proxmox3 \"sudo grep -c 'Invalid user' /var/log/secure\")\" = 0 ]"
t_b5() { local o; o=$(S proxmox1 'sudo grep -rh "Invalid user" /var/log/remote/proxmox3/'); on 'Invalid user admin' "$o" && on 'Invalid user root2' "$o" && on 'Invalid user test' "$o"; }
samm "B5: keskserveris on kõik kolm kasutajanime (sudo grep -rh)" oota t_b5
B5_FAILID=$(S proxmox1 'sudo ls /var/log/remote/proxmox3/' | tr '\n' ' ')
echo "     (info: proxmox3 failid keskserveris: $B5_FAILID)"

# B6 lahendusnäide
S proxmox1 'printf "/var/log/remote/*/*.log {\n    daily\n    rotate 30\n    compress\n    missingok\n    notifempty\n    postrotate\n        /usr/bin/systemctl kill -s HUP rsyslog.service >/dev/null 2>&1 || true\n    endscript\n}\n" | sudo tee /etc/logrotate.d/remote >/dev/null'
t_b6() { local o; o=$(S proxmox1 'sudo logrotate -d /etc/logrotate.d/remote 2>&1'); on '/var/log/remote/proxmox2/' "$o" && on '/var/log/remote/proxmox3/' "$o"; }
samm "B6: logrotate -d leiab mõlema masina failid" t_b6

# ---------------- Lisaülesannete lahendused ----------------
samm "L1: journalctl --disk-usage" S proxmox2 'journalctl --disk-usage | grep -q -i "take up"'

S proxmox1 'sudo sed -i "s#    action(type=\"omfile\" dynaFile=\"MasinaKaupa\")#    authpriv.*  action(type=\"omfile\" file=\"/var/log/remote/turvalogi.log\")\n    action(type=\"omfile\" dynaFile=\"MasinaKaupa\")#" /etc/rsyslog.d/50-keskserver.conf'
samm "L3: ruleset authpriv.* süntaks ok" S proxmox1 'sudo rsyslogd -N1 2>&1 | grep -q "End of config validation run. Bye."'
S proxmox1 'sudo systemctl restart rsyslog'; sleep 1; SISSE l3kontroll proxmox2; sleep 2
samm "L3: turvalogi.log sisaldab proxmox2 Invalid user l3kontroll (max 60 s)" oota S proxmox1 'sudo grep -q "Invalid user l3kontroll" /var/log/remote/turvalogi.log'

# L2 poe logid keskserverisse
S proxmox2 'sudo mv /etc/rsyslog.d/90-keskserver.conf /etc/rsyslog.d/05-keskserver.conf; sudo rsyslogd -N1 >/dev/null 2>&1 && sudo systemctl restart rsyslog; logger -p local0.info -t pood "tellimus 2002"'; sleep 3
samm "L2: tellimus 2002 on keskserveris remote/proxmox2/pood.log (max 60 s)" oota S proxmox1 'sudo grep -q "tellimus 2002" /var/log/remote/proxmox2/pood.log'
samm "L2: tellimus 2002 EI ole proxmox2 messages-is" S proxmox2 '! sudo grep -q "tellimus 2002" /var/log/messages'
S proxmox2 'sudo mv /etc/rsyslog.d/05-keskserver.conf /etc/rsyslog.d/90-keskserver.conf; sudo systemctl restart rsyslog'

# L5 keskserver maas
S proxmox1 'sudo systemctl stop rsyslog'
S proxmox2 'for i in 1 2 3; do logger -t n01test "ootel $i"; done'; sleep 2
S proxmox1 'sudo systemctl start rsyslog'
L5=0; for i in $(seq 18); do L5=$(S proxmox1 'sudo cat /var/log/remote/proxmox2/n01test.log 2>/dev/null | grep -c ootel'); [ "${L5:-0}" -ge 3 ] && break; sleep 5; done
echo "     (info: L5 - keskserver maas, 3 rida saadetud, kohale jõudis $L5, ~$((i*5)) s pärast)"
samm "L5: järjekorraga jõuavad kõik 3 kohale (max 90 s)" test "${L5:-0}" -ge 3

# L6 JSON mall
S proxmox1 'cat <<'"'"'EOF'"'"' | sudo tee /etc/rsyslog.d/51-json.conf >/dev/null
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
EOF
sudo sed -i "s#^ruleset(name=\"kaugelt\") {#ruleset(name=\"kaugelt\") {\n    action(type=\"omfile\" file=\"/var/log/remote/koik.json\" template=\"Json\")#" /etc/rsyslog.d/50-keskserver.conf
sudo mv /etc/rsyslog.d/51-json.conf /etc/rsyslog.d/49-json.conf'
samm "L6: JSON mall süntaks ok" S proxmox1 'sudo rsyslogd -N1 2>&1 | grep -q "End of config validation run. Bye."'
S proxmox1 'sudo systemctl restart rsyslog'; sleep 1; S proxmox2 'logger -p local3.warning -t n01test "json \"jutumärkidega\" test"'; sleep 2
samm "L6: koik.json viimane rida on kehtiv JSON" S proxmox1 'sudo tail -1 /var/log/remote/koik.json | python3 -m json.tool >/dev/null'
samm "L6: JSON-is on tosidus=warning" S proxmox1 'sudo grep "jutumärkidega" /var/log/remote/koik.json | tail -1 | python3 -c "import sys,json; d=json.loads(sys.stdin.read()); assert d[\"tosidus\"]==\"warning\", d"'
S proxmox1 'sudo rm -f /etc/rsyslog.d/49-json.conf'

# L4 UDP vs TCP (väike)
S proxmox1 'printf "module(load=\"imudp\")\ninput(type=\"imudp\" port=\"514\" ruleset=\"kaugelt\")\n" | sudo tee /etc/rsyslog.d/52-udp.conf >/dev/null; sudo firewall-cmd --state >/dev/null 2>&1 && sudo firewall-cmd --permanent --add-port=514/udp >/dev/null && sudo firewall-cmd --reload >/dev/null; sudo systemctl restart rsyslog'
sleep 1
S proxmox2 "for i in \$(seq 100); do logger -n $P1 -P 514 -d -t udptest \"udp \$i\"; done; for i in \$(seq 100); do logger -n $P1 -P 514 -T -t tcptest \"tcp \$i\"; done"; sleep 3
L3=$(S proxmox1 'echo "udp=$(sudo cat /var/log/remote/proxmox2/udptest.log 2>/dev/null | wc -l) tcp=$(sudo cat /var/log/remote/proxmox2/tcptest.log 2>/dev/null | wc -l)"')
echo "     (info: L4 $L3)"
samm "L4: logger -d (UDP) ja -T (TCP) jõuavad keskserverisse" bash -c "on(){ grep -q -- \"\$1\" <<< \"\$2\"; }; ! on 'udp=0' '$L3' && ! on 'tcp=0' '$L3'"
S proxmox1 'sudo rm -f /etc/rsyslog.d/52-udp.conf'

# ---------------- Kodutöö ----------------
S proxmox2 'for i in $(seq 20); do logger -p user.info -t pood "tellimus $i"; done; logger -p user.err -t pood "makse ebaõnnestus"'
S proxmox3 'logger -p user.warning -t varundus "ketas 85% täis"'
for u in admin oracle guest; do SISSE $u proxmox2; done; sleep 2
S proxmox1 'cat > ~/logiraport.sh <<'"'"'EOF'"'"'
#!/bin/bash
KAUST=/var/log/remote
echo "=== Logiraport $(date "+%F %H:%M") ==="
echo "Masinad:"
ls -d "$KAUST"/*/
for m in "$KAUST"/*/; do
  nimi=$(basename "$m")
  read=$(cat "$m"*.log | wc -l)
  echo "  $nimi: $read rida"
  echo "    enim: $(wc -l "$m"*.log | sort -n | tail -2 | head -1)"
done
echo "Sissetungi katsed (IP, mitu korda):"
grep -h "Invalid user" "$KAUST"/*/*.log \
  | grep -oE "from [0-9.]+" \
  | sort | uniq -c | sort -rn
echo "Viimased vead:"
grep -h -i -E "error|fail|ebaõnnestus" "$KAUST"/*/*.log | tail -5
EOF'
KT=$(S proxmox1 'sudo bash ~/logiraport.sh')
echo "$KT" | sed 's/^/     | /' | head -20
t_kt() { on 'proxmox2:' "$KT" && on 'proxmox3:' "$KT" && on 'from ' "$KT" && on 'makse ebaõnnestus' "$KT"; }
samm "Kodutöö: logiraport.sh näitab masinaid, ridu, katseid ja vigu" t_kt

# ---------------- Esitamine + Classroomi kontrollid ----------------
STARTER=$(cd ../lab01-starter 2>/dev/null && pwd); CTESTS=$(cd ../classroom50/it24-monitooring 2>/dev/null && pwd)
if [ -d "$STARTER" ] && [ -f "$CTESTS/lab01-tests.json" ]; then
  R="$TMP/opilane"; cp -R "$STARTER" "$R"; rm -rf "$R/.git"
  cp "$TMP/90-keskserver.conf" "$R/konf/"     # B4 scp
  ( cd "$R"
    scp -F "$CFG" -q proxmox2:/etc/rsyslog.d/10-pood.conf       konf/
    scp -F "$CFG" -q proxmox2:/etc/logrotate.d/pood             konf/pood.logrotate
    scp -F "$CFG" -q proxmox1:/etc/rsyslog.d/50-keskserver.conf konf/
    scp -F "$CFG" -q proxmox1:/etc/logrotate.d/remote           konf/remote.logrotate
    ssh "${SSHOPT[@]}" proxmox2 "sudo grep 'Invalid user' /var/log/secure"   > logid/a3-secure.txt
    ssh "${SSHOPT[@]}" proxmox2 "ls /var/log/pood*"                          > logid/a6-pood.txt
    ssh "${SSHOPT[@]}" proxmox1 "sudo ls -R /var/log/remote"                 > logid/b3-remote.txt
    ssh "${SSHOPT[@]}" proxmox1 "sudo grep -rh 'Invalid user' /var/log/remote/proxmox3/" > logid/b5-intsident.txt
    python3 - <<'PY'
import re
s=open('README.md',encoding='utf-8').read()
i=[0]
def f(m):
    i[0]+=1; return 'Testvastus %d: rsyslog kirjutas pärast pööramist vanasse faili, sest hoiab seda lahti.'%i[0]
open('README.md','w',encoding='utf-8').write(re.sub('_vastus_',f,s))
PY
  )
  run_kontroll() {  # run_kontroll <tests.json> <õppija kaust> <silt>
    local cnt n; cnt=$(python3 -c "import json,sys;print(len(json.load(open(sys.argv[1]))['tests']))" "$1")
    for ((n=0; n<cnt; n++)); do
      python3 -c "import json,sys;t=json.load(open(sys.argv[1]))['tests'][int(sys.argv[2])];open(sys.argv[3],'w').write(t['run']);print(t['name']+' ('+str(t['points'])+' p)')" "$1" $n "$TMP/k$n.sh" > "$TMP/nimi"
      [ -n "${4:-}" ] && ! grep -q "^$4" "$TMP/nimi" && continue
      samm "$3 $(cat "$TMP/nimi")" bash -c "cd '$2' && bash '$TMP/k$n.sh'"
    done
  }
  run_kontroll "$CTESTS/lab01-tests.json" "$R" "Classroom:" K
  # negatiivne kontroll: tühi starter peab kukkuma
  E="$TMP/tyhi"; cp -R "$STARTER" "$E"; rm -rf "$E/.git"
  TYHI=$(cd "$E" && python3 -c "
import json,subprocess
t=json.load(open('$CTESTS/lab01-tests.json'))['tests']
print(sum(x['points'] for x in t if subprocess.run(['bash','-c',x['run']],capture_output=True).returncode==0))")
  samm "Classroom: tühi starter saab 0 punkti (saab $TYHI)" test "$TYHI" -eq 0
  # kodutöö samasse repo: skript kodutoo/ alla, raport ja vastused README osasse Kodutöö
  scp -F "$CFG" -q proxmox1:logiraport.sh "$R/kodutoo/"
  KT_FILE="$TMP/kt.txt"; echo "$KT" > "$KT_FILE"
  python3 - "$R/README.md" "$KT_FILE" <<'PY'
import sys
p,kt=sys.argv[1],open(sys.argv[2],encoding='utf-8').read().strip()
s=open(p,encoding='utf-8').read()
s=s.replace('_kodutöö_',kt,1)
s=s.replace('_kodutöö_','Skript loeb iga kord kõik read uuesti, 50 masina ja 1 GB päevas korral läheb see aeglaseks ja ketas saab täis; raport ei hoiata ise.')
open(p,'w',encoding='utf-8').write(s)
PY
  run_kontroll "$CTESTS/lab01-tests.json" "$R" "Classroom pärast kodutööd:"
else
  echo "     (info: ../lab01-starter või classroom50 testid puuduvad, Classroomi kontrollid vahele jäetud)"
fi

# ---------------- Lingid ----------------
for u in $(grep -ho 'https\?://[^) ]*' docs/week01/*.md | sort -u); do
  samm "Link töötab: $u" bash -c "curl -s -o /dev/null -L --max-time 15 -w '%{http_code}' '$u' | grep -q '^2'"
done

# ---------------- RAM ----------------
RAM=$(S proxmox1 'ps -o rss= -C rsyslogd | awk "{s+=\$1} END {printf \"%.1f MB\", s/1024}"')
MEM=$(S proxmox1 'free -m | awk "/Mem:/ {print \$2\" MB kokku, \"\$7\" MB available\"}"')
echo "     (info: rsyslogd proxmox1-l $RAM; $MEM)"

if [ "${KEEP:-0}" = 1 ]; then echo "== KEEP=1: sõlmed jäävad labori lõppseisu"; else echo "== Koristus pärast"; koristus; fi

# ---------------- RESULTS.md ----------------
OS=$(S proxmox1 '. /etc/os-release; echo $PRETTY_NAME')
VER=$(S proxmox1 'rpm -q rsyslog logrotate openssh-server | tr "\n" " "')
ANS=$(ansible --version | head -1)
{
  echo "## week01 - Masina päevik ja logid ühte kohta"
  echo
  echo "- Käivitatud: $(date '+%F %H:%M')"
  echo "- Keskkond: $OS ×3 (SSH-konf: \`${SSH_CONFIG:-~/.ssh/config}\`), $ANS"
  echo "- Versioonid: $VER"
  echo "- Tulemus: **$OK OK, $FAIL FAIL**"
  echo "- RAM proxmox1: rsyslogd $RAM (lisakoormust ei ole); sõlm $MEM"
  echo "- Märkused: pärast esimest pööramist ilma postrotate'ita uus pood.log: $A6_UUS. Lõpus failid: $A6_LS. proxmox3 failid keskserveris: $B5_FAILID. L4: $L3. L5 ootel ridu kohale: $L5/3."
  echo "- TESTIMATA: L7 (oma skript, lahendust pole antud), L8 (TLS), L9 (systemd-journal-remote)."
  echo
  echo "| Samm | Tulemus | Väljund (FAIL korral) |"
  echo "|---|---|---|"
  cat "$LOG"
  echo
} > "$TMP/week01.md"
R=tests/RESULTS.md
[ -f $R ] || printf '# Laborite testitulemused\n\nIga labor käiakse läbi skriptiga `tests/weekNN.sh`. Uuem tulemus asendab sama nädala vana osa.\n\n' > $R
python3 - "$R" "$TMP/week01.md" <<'EOF'
import sys,re
r,new=sys.argv[1],open(sys.argv[2]).read()
s=open(r).read()
s=re.sub(r'(?s)## week01 .*?(?=\n## week|\Z)', '', s).rstrip()+'\n\n'+new
open(r,'w').write(s)
EOF
rm -rf "$TMP"
echo "== $OK OK, $FAIL FAIL  -> $R"
[ "$FAIL" -eq 0 ]
