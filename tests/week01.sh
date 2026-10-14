#!/bin/bash
# Kohtumine 1 labori test ("Öövahetus"): käib docs/week01/lab.md läbi nagu õppija ja kontrollib oodatavaid tulemusi.
#
# Kasutus:
#   SSH_CONFIG=tests/.ssh_config bash tests/week01.sh      # lima testkeskkond (tests/lima-setup.sh up)
#   bash tests/week01.sh                                   # päris sõlmed, sinu ~/.ssh/config
#   KEEP=1 ...                                             # jäta sõlmed labori lõppseisu (tahvli kontrollide testiks)
#
# Eeldus: ssh proxmox1/2/3 töötab ilma paroolita, sudo NOPASSWD. B5 kasutab õpetaja skripti
# ../monitoring-juhendaja/koolitaja/oine-kylaline.sh, kui see on olemas, muidu labori "tee ise" varianti.
# Tulemus: tests/RESULTS.md (week01 osa).
set -uo pipefail
cd "$(dirname "$0")/.."

CFG="${SSH_CONFIG:-$HOME/.ssh/config}"; CFG="$(cd "$(dirname "$CFG")" && pwd)/$(basename "$CFG")"
SSHOPT=(-F "$CFG" -o BatchMode=yes -o ConnectTimeout=10)
RUN=$(date +%H%M%S)
S() { local h=$1; shift; ssh "${SSHOPT[@]}" "$h" "RUN=$RUN; $*"; }
SISSE() { ssh "${SSHOPT[@]}" -o ControlMaster=no -o ControlPath=none -o PubkeyAuthentication=no -o User="$1" "$2" true >/dev/null 2>&1; }
export ANSIBLE_SSH_ARGS="-F $CFG" ANSIBLE_HOST_KEY_CHECKING=False ANSIBLE_STDOUT_CALLBACK=minimal ANSIBLE_PYTHON_INTERPRETER=auto_silent
STARTER=$(cd ../lab01-starter 2>/dev/null && pwd); CTESTS=$(cd ../classroom50/it24-monitooring 2>/dev/null && pwd)
KYLALINE=$(cd ../monitoring-juhendaja/koolitaja 2>/dev/null && pwd)/oine-kylaline.sh

TMP=$(mktemp -d); LOG="$TMP/log.md"; OK=0; FAIL=0
R="$TMP/opilane"; cp -R "$STARTER" "$R" 2>/dev/null; rm -rf "$R/.git"; mkdir -p "$R/konf" "$R/logid" "$R/kodutoo"
samm() {
  local nimi=$1; shift
  if out=$("$@" 2>&1); then echo "| $nimi | OK | |" >> "$LOG"; OK=$((OK+1)); echo "OK   $nimi"
  else local l; l=$(echo "$out" | tail -3 | tr '\n|' ' /' | cut -c1-160)
    echo "| $nimi | **FAIL** | \`$l\` |" >> "$LOG"; FAIL=$((FAIL+1)); echo "FAIL $nimi"; echo "$out" | tail -5 | sed 's/^/     /'; fi
}
on()   { grep -q -- "$1" <<< "$2"; }
oota() { for _ in $(seq 12); do "$@" >/dev/null 2>&1 && return 0; sleep 5; done; "$@"; }
INFO=(); info() { echo "     (info: $*)"; INFO+=("$*"); }

koristus() {
  for h in proxmox1 proxmox2 proxmox3; do
    S $h 'sudo rm -f /etc/rsyslog.d/05-keskserver.conf /etc/rsyslog.d/10-pood.conf /etc/rsyslog.d/20-ssh.conf /etc/rsyslog.d/49-json.conf \
            /etc/rsyslog.d/50-keskserver.conf /etc/rsyslog.d/52-udp.conf /etc/rsyslog.d/90-keskserver.conf /etc/rsyslog.d/99-*.conf \
            /etc/logrotate.d/pood /etc/logrotate.d/remote /var/log/pood* /var/log/ssh.log /etc/audit/rules.d/logid.rules \
            /etc/cron.d/uuendus /etc/cron.d/kontroll /etc/cron.d/synk /etc/cron.d/varukoopia /etc/systemd/journald.conf.d/piir.conf \
            /tmp/veeb.log ~/veeb.log ~/tee-suur-logi.sh ~/logiraport.sh
          sudo rm -rf /var/log/remote; sudo userdel -r praktikant 2>/dev/null
          sudo augenrules --load >/dev/null 2>&1; sudo auditctl -D >/dev/null 2>&1
          sudo firewall-cmd -q --permanent --remove-port=514/tcp 2>/dev/null; sudo firewall-cmd -q --permanent --remove-port=514/udp 2>/dev/null
          sudo firewall-cmd -q --reload 2>/dev/null; sudo systemctl restart systemd-journald rsyslog' >/dev/null 2>&1
  done
  S proxmox2 'sudo rm -rf /var/log/journal; sudo systemctl restart systemd-journald' >/dev/null 2>&1   # A3 algseis: journal mälus
}
echo "== Koristus enne"; koristus

# ================= Eeltöö =================
t_hostid() { for h in proxmox1 proxmox2 proxmox3; do [ "$(S $h hostname)" = "$h" ] || return 1; done; }
samm "Eeltöö: ssh proxmox1-3 hostname" t_hostid
samm "Eeltöö: rpm -q, teenused, logrotate.timer" bash -c "ssh ${SSHOPT[*]} proxmox2 'rpm -q rsyslog logrotate audit && systemctl is-active rsyslog auditd && systemctl list-timers logrotate.timer --no-pager' | grep -q logrotate.timer"
samm "Eeltöö: ansible package rsyslog,logrotate,audit" bash -c "! ansible all -i proxmox1,proxmox2,proxmox3, -b -m ansible.builtin.package -a 'name=rsyslog,logrotate,audit state=present' | grep -q -E 'FAILED|UNREACHABLE'"
samm "Eeltöö: ansible service rsyslog started" bash -c "! ansible all -i proxmox1,proxmox2,proxmox3, -b -m ansible.builtin.service -a 'name=rsyslog state=started enabled=true' | grep -q -E 'FAILED|UNREACHABLE'"
P1=$(S proxmox1 "hostname -I" | awk '{print $1}'); samm "Eeltöö: proxmox1 IP ($P1)" test -n "$P1"

# ================= A1 =================
S proxmox2 'logger -t n01test "tere logi $RUN"'; sleep 1
samm "A1: logger rida /var/log/messages-is" S proxmox2 'sudo grep -q "n01test.*tere logi $RUN" /var/log/messages'
samm "A1: journalctl -t n01test leiab" S proxmox2 'journalctl -t n01test --no-pager | grep -q "tere logi $RUN"'
t_a1v() { local o; o=$(S proxmox2 'journalctl -t n01test -o verbose -n 1 --no-pager'); on 'PRIORITY=5' "$o" && on 'SYSLOG_FACILITY=1' "$o" && on '_HOSTNAME=proxmox2' "$o" && on '_PID=' "$o"; }
samm "A1: -o verbose: PRIORITY=5 SYSLOG_FACILITY=1 _HOSTNAME _PID" t_a1v
samm "A1: audit.log viimane rida algab type=" S proxmox2 'sudo tail -1 /var/log/audit/audit.log | grep -q "^type="'
samm "A1: ausearch -m USER_CMD -i näitab sudo käsku" S proxmox2 'sudo ausearch --input-logs -m USER_CMD -i --start recent | grep -q "type=USER_CMD"'

# ================= A2 =================
samm "A2: messages/secure/cron on 600 root" S proxmox2 'for f in /var/log/messages /var/log/secure /var/log/cron; do [ "$(stat -c %a:%U $f)" = 600:root ] || exit 1; done'
samm "A2: tavakasutaja cat secure -> Permission denied" bash -c "ssh ${SSHOPT[*]} proxmox2 'cat /var/log/secure' 2>&1 | grep -q 'Permission denied'"
samm "A2: praktikant ilma grupita: insufficient permissions" bash -c "ssh ${SSHOPT[*]} proxmox2 'sudo useradd -m praktikant; sudo -u praktikant journalctl -n 3 --no-pager' 2>&1 | grep -q 'insufficient permissions'"
samm "A2: praktikant systemd-journal grupis näeb journalit" bash -c "! ssh ${SSHOPT[*]} proxmox2 'sudo usermod -aG systemd-journal praktikant; sudo -u praktikant journalctl -n 3 --no-pager' 2>&1 | grep -q 'insufficient permissions'"
samm "A2: praktikant ikka ei loe secure-t" bash -c "ssh ${SSHOPT[*]} proxmox2 'sudo -u praktikant cat /var/log/secure' 2>&1 | grep -q 'Permission denied'"

# ================= A3 =================
samm "A3: algseisus /var/log/journal puudub" S proxmox2 '! test -d /var/log/journal'
S proxmox2 'sudo mkdir -p /var/log/journal; sudo systemd-tmpfiles --create --prefix /var/log/journal; sudo journalctl --flush'
samm "A3: /var/log/journal drwxr-sr-x+ root systemd-journal" S proxmox2 'ls -ld /var/log/journal | grep -qE "^drwxr-sr-x\+ .* root systemd-journal"'
samm "A3: getfacl: wheel ja adm loevad" S proxmox2 'getfacl -p /var/log/journal 2>/dev/null | grep -q "^group:wheel:r-x" && getfacl -p /var/log/journal | grep -q "^group:adm:r-x"'
S proxmox2 'sudo systemctl reboot' >/dev/null 2>&1; sleep 15
for _ in $(seq 30); do S proxmox2 true >/dev/null 2>&1 && break; sleep 5; done
samm "A3: pärast rebooti --list-boots >= 2" bash -c "[ \$(ssh ${SSHOPT[*]} proxmox2 'journalctl --list-boots --no-pager' | grep -cE '^ *-?[0-9]+ +[0-9a-f]{32}') -ge 2 ]"
S proxmox2 'journalctl --list-boots --no-pager' > "$R/logid/a3-boots.txt"

# ================= A4 =================
SISSE sissetungija proxmox2; sleep 1
samm "A4: secure: Invalid user sissetungija" S proxmox2 'sudo grep -q "Invalid user sissetungija" /var/log/secure'
samm "A4: journalctl -u sshd --since leiab" S proxmox2 'sudo journalctl -u sshd --since "10 min ago" --no-pager | grep -q "Invalid user sissetungija"'
samm "A4: -p err -b ja -p warning töötavad" S proxmox2 'journalctl -p err -b --no-pager >/dev/null; journalctl -p warning --since "1 hour ago" --no-pager | wc -l'
samm "A4: last -n 5 töötab" S proxmox2 'last -n 5 | grep -q -E "pts|reboot|wtmp"'
samm "A4: lastb -w: sissetungija täisnimega" S proxmox2 'sudo lastb -w -n 20 | grep -q "^sissetungija "'
samm "A4: messages-is pole Invalid user" S proxmox2 '! sudo grep -q "Invalid user sissetungija" /var/log/messages'

# ================= A5 =================
t_a5r() { local o; o=$(S proxmox2 "grep -v -E '^#|^\$' /etc/rsyslog.conf | grep /var/log"); on 'authpriv.none' "$o" && on '/var/log/secure' "$o" && on '/var/log/messages' "$o"; }
samm "A5: vaikereeglid nagu juhendis" t_a5r
S proxmox2 'echo "locla0.*    /var/log/pood.log" | sudo tee /etc/rsyslog.d/10-pood.conf >/dev/null'
samm "A5.2: trükiviga -> unknown facility name locla0" S proxmox2 'sudo rsyslogd -N1 2>&1 | grep -q "unknown facility name \"locla0\""'
S proxmox2 'echo "local0.*    /var/log/pood.log" | sudo tee /etc/rsyslog.d/10-pood.conf >/dev/null'
samm "A5.2: parandatud -> Bye." S proxmox2 'sudo rsyslogd -N1 2>&1 | grep -q "End of config validation run. Bye."'
S proxmox2 'sudo systemctl restart rsyslog; logger -p local0.info -t pood "tellimus 1001 $RUN"'; sleep 1
samm "A5.3: 1001 pood.log-is ja messages-is" S proxmox2 'sudo grep -q "tellimus 1001 $RUN" /var/log/pood.log && sudo grep -q "tellimus 1001 $RUN" /var/log/messages'
S proxmox2 'printf "local0.*    /var/log/pood.log\n& stop\n" | sudo tee /etc/rsyslog.d/10-pood.conf >/dev/null; sudo systemctl restart rsyslog; logger -p local0.info -t pood "tellimus 1002 $RUN"'; sleep 1
samm "A5.4: & stop -> 1002 ainult pood.log-is" S proxmox2 'sudo grep -q "tellimus 1002 $RUN" /var/log/pood.log && ! sudo grep -q "tellimus 1002 $RUN" /var/log/messages'
S proxmox2 'printf "local0.warning    /var/log/pood-hoiatused.log\nlocal0.*          /var/log/pood.log\n& stop\n" | sudo tee /etc/rsyslog.d/10-pood.conf >/dev/null; sudo systemctl restart rsyslog
  logger -p local0.info -t pood "tellimus 1003 $RUN"; logger -p local0.warning -t pood "laos alla 5 toote $RUN"; logger -p local0.err -t pood "makse ebaõnnestus $RUN"'; sleep 1
samm "A5.5: hoiatused: warning+err, mitte info" S proxmox2 'f=/var/log/pood-hoiatused.log; sudo grep -q "laos alla 5 toote $RUN" $f && sudo grep -q "makse ebaõnnestus $RUN" $f && ! sudo grep -q "tellimus 1003 $RUN" $f'
samm "A5.5: pood.log kõik kolm, messages mitte ühtegi" S proxmox2 'for t in "tellimus 1003" "laos alla 5 toote" "makse ebaõnnestus"; do sudo grep -q "$t $RUN" /var/log/pood.log || exit 1; sudo grep -q "$t $RUN" /var/log/messages && exit 1; done; true'
S proxmox2 "printf 'if \$programname startswith \"sshd\" then {\n    action(type=\"omfile\" file=\"/var/log/ssh.log\")\n}\n' | sudo tee /etc/rsyslog.d/20-ssh.conf >/dev/null"
samm "A5.6: programmi filter -N1 ok" S proxmox2 'sudo rsyslogd -N1 2>&1 | grep -q "End of config validation run. Bye."'
S proxmox2 'sudo systemctl restart rsyslog'; SISSE filter$RUN proxmox2; sleep 1
samm "A5.6: /var/log/ssh.log sisaldab Invalid user" S proxmox2 'sudo grep -q "Invalid user filter$RUN" /var/log/ssh.log'

# ================= A6 =================
S proxmox2 'printf "/var/log/pood.log /var/log/pood-hoiatused.log {\n    size 10k\n    rotate 3\n    missingok\n}\n" | sudo tee /etc/logrotate.d/pood >/dev/null'
samm "A6.2: logrotate -d: does not need rotating" S proxmox2 'sudo logrotate -d /etc/logrotate.d/pood 2>&1 | grep -q "log does not need rotating"'
S proxmox2 'for i in $(seq 300); do logger -p local0.info -t pood "tellimus $i"; done; sleep 2; sudo logrotate -v /etc/logrotate.d/pood >/dev/null 2>&1; logger -p local0.info -t pood "pärast pööramist $RUN"'; sleep 1
samm "A6.4: pood.log puudub, rida pood.log.1-s" S proxmox2 '! sudo test -e /var/log/pood.log && sudo grep -q "pärast pööramist $RUN" /var/log/pood.log.1'
S proxmox2 'sudo rm -f /var/log/pood.log.*; sudo systemctl restart rsyslog; printf "/var/log/pood.log /var/log/pood-hoiatused.log {\n    size 10k\n    rotate 3\n    compress\n    missingok\n    notifempty\n    postrotate\n        /usr/bin/systemctl kill -s HUP rsyslog.service >/dev/null 2>&1 || true\n    endscript\n}\n" | sudo tee /etc/logrotate.d/pood >/dev/null'
for k in 1 2 3 4; do S proxmox2 'for i in $(seq 300); do logger -p local0.info -t pood "tellimus $i"; done; sleep 2; sudo logrotate -v /etc/logrotate.d/pood >/dev/null 2>&1; sleep 1'; done
S proxmox2 'logger -p local0.info -t pood "pärast HUP-i $RUN"'; sleep 1
samm "A6.6: pärast HUP-i uus rida pood.log-is" S proxmox2 'sudo grep -q "pärast HUP-i $RUN" /var/log/pood.log'
samm "A6.6: ls = hoiatused, pood.log, .1-.3.gz" bash -c "[ \"\$(ssh ${SSHOPT[*]} proxmox2 'ls /var/log/pood*' | tr '\n' ' ')\" = '/var/log/pood-hoiatused.log /var/log/pood.log /var/log/pood.log.1.gz /var/log/pood.log.2.gz /var/log/pood.log.3.gz ' ]"
samm "A6.6: zgrep -c leiab pakitud failidest" bash -c "ssh ${SSHOPT[*]} proxmox2 'sudo zgrep -c \"tellimus 150\" /var/log/pood.log.*.gz' | grep -q ':[1-9]'"

# ================= A7 =================
S proxmox2 'sudo auditctl -w /etc/rsyslog.d/ -p wa -k logikonf; sudo auditctl -w /var/log/secure -p wa -k turvalogi; sudo auditctl -w /etc/cron.d/ -p wa -k ajastus' >/dev/null 2>&1
samm "A7.1: auditctl -l: 3 reeglit" bash -c "[ \$(ssh ${SSHOPT[*]} proxmox2 'sudo auditctl -l' | grep -c -E 'logikonf|turvalogi|ajastus') -eq 3 ]"
S proxmox2 'sudo touch /etc/rsyslog.d/99-tagauks.conf; sudo truncate -s 0 /var/log/secure'; sleep 1
samm "A7.2: audit.log SYSCALL read võtmetega" S proxmox2 'sudo grep -E "logikonf|turvalogi" /var/log/audit/audit.log | grep -q "type=SYSCALL"'
AU=$(S proxmox2 'id -un')
t_a7() { local o; o=$(S proxmox2 'sudo ausearch --input-logs -k turvalogi -i'); on 'comm=truncate' "$o" && on "auid=$AU" "$o" && on 'uid=root' "$o"; }
samm "A7.2: ausearch: comm=truncate auid=$AU uid=root" t_a7
samm "A7.2: aureport -f -i" S proxmox2 'sudo aureport --input-logs -f -i | grep -q -E "/etc/rsyslog.d|/var/log/"'
S proxmox2 'sudo rm /etc/rsyslog.d/99-tagauks.conf; printf -- "-w /etc/rsyslog.d/ -p wa -k logikonf\n-w /var/log/secure -p wa -k turvalogi\n-w /etc/cron.d/ -p wa -k ajastus\n" | sudo tee /etc/audit/rules.d/logid.rules >/dev/null; sudo augenrules --load >/dev/null 2>&1'
samm "A7.3: augenrules --load -> 3 reeglit" bash -c "[ \$(ssh ${SSHOPT[*]} proxmox2 'sudo auditctl -l' | grep -c -E 'logikonf|turvalogi|ajastus') -eq 3 ]"
S proxmox2 'sudo cat /etc/audit/rules.d/logid.rules' > "$R/konf/logid.rules"
S proxmox2 'sudo ausearch --input-logs -k turvalogi -i' > "$R/logid/a7-audit.txt"

# ================= B1 =================
S proxmox1 'printf "module(load=\"imtcp\")\n\ntemplate(name=\"MasinaKaupa\" type=\"string\"\n         string=\"/var/log/remote/%%HOSTNAME%%/%%PROGRAMNAME%%.log\")\n\nruleset(name=\"kaugelt\") {\n    authpriv.*  action(type=\"omfile\" file=\"/var/log/remote/turvalogi.log\")\n    action(type=\"omfile\" dynaFile=\"MasinaKaupa\")\n}\n\ninput(type=\"imtcp\" port=\"514\" ruleset=\"kaugelt\")\n" | sudo tee /etc/rsyslog.d/50-keskserver.conf >/dev/null'
samm "B1: -N1 ok" S proxmox1 'sudo rsyslogd -N1 2>&1 | grep -q "End of config validation run. Bye."'
S proxmox1 'sudo systemctl restart rsyslog'
samm "B1: kuulab 0.0.0.0:514 rsyslogd" S proxmox1 'sudo ss -tlnp | grep -E "0.0.0.0:514 " | grep -q rsyslogd'

# ================= B2 =================
S proxmox2 "printf '*.* action(type=\"omfwd\" target=\"$P1\" port=\"514\" protocol=\"tcp\"\n           queue.type=\"LinkedList\" queue.size=\"10000\"\n           action.resumeRetryCount=\"-1\")\n' | sudo tee /etc/rsyslog.d/90-keskserver.conf >/dev/null; sudo systemctl restart rsyslog; logger -t n01test 'siin proxmox2 $RUN'"; sleep 3
FW=$(S proxmox1 'sudo firewall-cmd --state 2>/dev/null || echo off')
if [ "$FW" = running ]; then
  samm "B2: tulemüür kinni -> ei jõua" S proxmox1 '! sudo grep -rq "siin proxmox2 $RUN" /var/log/remote/ 2>/dev/null'
  samm "B2: /dev/tcp: No route to host + kinni" bash -c "o=\$(ssh ${SSHOPT[*]} proxmox2 \"timeout 3 bash -c '</dev/tcp/$P1/514' && echo lahti || echo kinni\" 2>&1); grep -q kinni <<< \"\$o\" && grep -q 'No route to host' <<< \"\$o\""
  samm "B2: firewall-cmd --list-ports tühi" bash -c "[ -z \"\$(ssh ${SSHOPT[*]} proxmox1 'sudo firewall-cmd --list-ports' | tr -d ' ')\" ]"
  S proxmox1 'sudo firewall-cmd -q --permanent --add-port=514/tcp && sudo firewall-cmd -q --reload'
else info "firewalld väljas, tulemüüri viga ei testitud"; fi
samm "B2: järjekorras oodanud rida kohal (max 60 s)" oota S proxmox1 'sudo grep -q "siin proxmox2 $RUN" /var/log/remote/proxmox2/n01test.log'
samm "B2: kaugrida ei läinud proxmox1 messages-isse" S proxmox1 '! sudo grep -q "siin proxmox2 $RUN" /var/log/messages'
S proxmox2 'logger -p local0.info -t pood "tellimus 2001 $RUN"'; sleep 3
samm "B2 Mõtle: & stop -> 2001 ei jõua keskserverisse" S proxmox1 '! sudo grep -rq "tellimus 2001 $RUN" /var/log/remote/'

# ================= B3 =================
scp -F "$CFG" -q proxmox2:/etc/rsyslog.d/90-keskserver.conf "$R/konf/"
cat > "$R/konf/keskserver.yml" <<'YML'
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
    - name: Auditi reeglid
      ansible.builtin.copy:
        src: logid.rules
        dest: /etc/audit/rules.d/logid.rules
        mode: "0600"
      notify: Lae auditi reeglid
  handlers:
    - name: Taaskäivita rsyslog
      ansible.builtin.service:
        name: rsyslog
        state: restarted
    - name: Lae auditi reeglid
      ansible.builtin.command: augenrules --load
YML
samm "B3: playbook 1. käivitus failed=0" bash -c "cd '$R' && ANSIBLE_STDOUT_CALLBACK=default ansible-playbook -i proxmox3, konf/keskserver.yml | grep -q 'failed=0'"
samm "B3: playbook 2. käivitus changed=0" bash -c "cd '$R' && ANSIBLE_STDOUT_CALLBACK=default ansible-playbook -i proxmox3, konf/keskserver.yml | grep -q -E 'changed=0 .*failed=0'"
S proxmox3 'logger -t n01test "siin proxmox3 $RUN"'
samm "B3: proxmox3 rida keskserveris (max 60 s)" oota S proxmox1 'sudo grep -q "siin proxmox3 $RUN" /var/log/remote/proxmox3/n01test.log'
samm "B3: proxmox3 auditctl -l = 3" bash -c "[ \$(ssh ${SSHOPT[*]} proxmox3 'sudo auditctl -l' | grep -c -E 'logikonf|turvalogi|ajastus') -eq 3 ]"

# ================= B4 =================
scp -F "$CFG" -q "$R/tooriistad/tee-suur-logi.sh" proxmox2:
samm "B4: generaator 50000 rida" bash -c "ssh ${SSHOPT[*]} proxmox2 'bash tee-suur-logi.sh > /tmp/veeb.log; wc -l < /tmp/veeb.log' | grep -qx 50000"
S proxmox2 "logger -n $P1 -P 514 -T -t veeb -f /tmp/veeb.log"
samm "B4: keskserveris 50000 rida (max 60 s)" oota bash -c "[ \"\$(ssh ${SSHOPT[*]} proxmox1 'sudo cat /var/log/remote/proxmox2/veeb.log | wc -l')\" -ge 50000 ]"
samm "B4: cd keskserveri kausta ilma sudota ei õnnestu (700)" bash -c "ssh ${SSHOPT[*]} proxmox1 'cd /var/log/remote/proxmox2' 2>&1 | grep -q 'Permission denied'"
samm "B4: koopia kodukausta + chown" S proxmox1 'sudo cp /var/log/remote/proxmox2/veeb.log ~/ && sudo chown $USER ~/veeb.log && test -r ~/veeb.log'
q() { S proxmox1 "cd ~ && $1"; }
A1=$(q "wc -l < veeb.log"); A2=$(q "grep -c 'staatus=500' veeb.log")
A3=$(q "grep 'staatus=500' veeb.log | grep -o 'kell=..:..' | sort | uniq -c | sort -rn | head -1")
A4=$(q "grep 'staatus=500' veeb.log | grep -o 'url=[^ ]*' | sort | uniq -c | sort -rn | head -1")
A5=$(q "grep 'staatus=401' veeb.log | grep -o 'ip=[^ ]*' | sort | uniq -c | sort -rn | head -1; grep 'staatus=401' veeb.log | head -1 | grep -o 'kell=[^ ]*'; grep 'staatus=401' veeb.log | tail -1 | grep -o 'kell=[^ ]*'")
A6=$(q "grep 'ip=10.0.9.66' veeb.log | grep -v 'staatus=401'")
A7=$(q "grep 'id=031337' veeb.log")
G5=$(q "grep -c 500 veeb.log")
samm "B4.1-2: 50000 rida, 748 viga" bash -c "[ '$A1' = 50000 ] && [ '$A2' = 748 ]"
samm "B4.3-4: 03:12 ja /api/makse" bash -c "grep -q 'kell=03:12' <<< '$A3' && grep -q 'url=/api/makse' <<< '$A4'"
samm "B4.5: 10.0.9.66 459x 02:45:00-02:55:59" bash -c "grep -q '459 ip=10.0.9.66' <<< '$A5' && grep -q 'kell=02:45:00' <<< '$A5' && grep -q 'kell=02:55:59' <<< '$A5'"
samm "B4.6: sisse pääses 02:56:00 id=024167" bash -c "grep -q 'kell=02:56:00' <<< '$A6' && grep -q 'staatus=200' <<< '$A6' && grep -q 'id=024167' <<< '$A6'"
samm "B4.7: id=031337 = /pood 200" bash -c "grep -q 'url=/pood' <<< '$A7' && grep -q 'staatus=200' <<< '$A7'"
info "B4 Mõtle: grep -c 500 = $G5, staatus=500 = $A2"
samm "B4 Mõtle: grep 500 annab rohkem" test "$G5" -gt "$A2"
LS=$(q "awk -F'aeg=' '{ split(\$2, a, \"ms\"); if (a[1] > max) { max = a[1]; rida = \$0 } } END { print rida }' veeb.log")
info "L3 kõige aeglasem: $(grep -o 'kell=.*' <<< "$LS")"
samm "L3: awk leiab aeg >= 4900ms" bash -c "[ \$(grep -o 'aeg=[0-9]*' <<< '$LS' | tr -cd 0-9) -ge 4900 ]"
printf '1. 50000 (wc -l)\n2. 748\n3. 03:12, 120 viga\n4. /api/makse\n5. 10.0.9.66, 459 korda, 02:45:00 - 02:55:59\n6. jah, 02:56:00, id=024167\n7. /pood, 200\n' > "$R/logid/b4-otsing.md"

# ================= B5 =================
if [ -f "$KYLALINE" ]; then
  K=$(SSH_OPTS="-F $CFG" bash "$KYLALINE" proxmox3); info "öine külaline: $K"
  KCRON=$(grep -o '/etc/cron.d/[a-z]*' <<< "$K")
  samm "B5: külalise skript õnnestus" bash -c "! grep -q VIGA <<< '$K'"
else
  for u in admin root2 test; do SISSE $u proxmox3; done
  S proxmox3 "sudo truncate -s 0 /var/log/secure; echo '* * * * * root /usr/bin/logger -t uuendus kontroll' | sudo tee /etc/cron.d/uuendus >/dev/null"
  KCRON=/etc/cron.d/uuendus
fi
samm "B5: proxmox3 secure grep -c = 0" bash -c "[ \"\$(ssh ${SSHOPT[*]} proxmox3 \"sudo grep -c 'Invalid user' /var/log/secure\")\" = 0 ]"
t_b5k() { [ "$(S proxmox1 'sudo grep -rh "Invalid user" /var/log/remote/proxmox3/' | grep -oE 'Invalid user [^ ]+' | sort -u | wc -l)" -ge 3 ]; }
samm "B5.1: keskserveris >= 3 kasutajat" oota t_b5k
samm "B5.1: turvalogi.log sisaldab proxmox3 katseid" S proxmox1 'sudo grep -q "proxmox3 .*Invalid user" /var/log/remote/turvalogi.log'
t_b5a() { local o; o=$(S proxmox3 'sudo ausearch --input-logs -k turvalogi -i; sudo ausearch --input-logs -k ajastus -i'); on 'comm=truncate' "$o" && on "$KCRON" "$o"; }
samm "B5.2-3: audit: truncate ja $KCRON" t_b5a
CT=$(basename "$KCRON")
samm "B5.3: cron-töö jälg $CT.log keskserveris (max 90 s)" bash -c "for i in \$(seq 18); do ssh ${SSHOPT[*]} proxmox1 'sudo test -s /var/log/remote/proxmox3/$CT.log' && exit 0; sleep 5; done; exit 1"
S proxmox1 'sudo grep -rh "Invalid user" /var/log/remote/proxmox3/' > "$R/logid/b5-intsident.txt"
S proxmox3 'sudo ausearch --input-logs -k turvalogi -i; sudo ausearch --input-logs -k ajastus -i' > "$R/logid/b5-audit.txt"
info "auid B5-s: $(grep -o 'auid=[^ ]*' "$R/logid/b5-audit.txt" | sort -u | tr '\n' ' ')"
if [ -f "$KYLALINE" ]; then SSH_OPTS="-F $CFG" bash "$KYLALINE" --koristus proxmox3 >/dev/null; else S proxmox3 'sudo rm -f /etc/cron.d/uuendus'; fi

# ================= B6 =================
S proxmox1 'printf "/var/log/remote/*/*.log /var/log/remote/turvalogi.log {\n    daily\n    rotate 30\n    compress\n    dateext\n    missingok\n    notifempty\n    postrotate\n        /usr/bin/systemctl kill -s HUP rsyslog.service >/dev/null 2>&1 || true\n    endscript\n}\n" | sudo tee /etc/logrotate.d/remote >/dev/null'
t_b6() { local o; o=$(S proxmox1 'sudo logrotate -d /etc/logrotate.d/remote 2>&1'); on '/var/log/remote/proxmox2/' "$o" && on '/var/log/remote/proxmox3/' "$o" && on 'turvalogi.log' "$o"; }
samm "B6: logrotate -d leiab proxmox2, proxmox3, turvalogi" t_b6

# ================= Esitamine + Classroom =================
scp -F "$CFG" -q proxmox2:/etc/rsyslog.d/10-pood.conf "$R/konf/"
scp -F "$CFG" -q proxmox2:/etc/logrotate.d/pood "$R/konf/pood.logrotate"
scp -F "$CFG" -q proxmox1:/etc/rsyslog.d/50-keskserver.conf "$R/konf/"
scp -F "$CFG" -q proxmox1:/etc/logrotate.d/remote "$R/konf/remote.logrotate"
S proxmox2 'ls /var/log/pood*' > "$R/logid/a6-pood.txt"
S proxmox1 'sudo ls -R /var/log/remote' > "$R/logid/b3-remote.txt"
python3 - "$R/README.md" <<'PY'
import sys,re
p=sys.argv[1]; s=open(p,encoding='utf-8').read(); i=[0]
def f(m):
    i[0]+=1; return 'Testvastus %d: rsyslog hoidis faili lahti ja kirjutas vanasse, audit näitas auid väljal, kes tegi.'%i[0]
open(p,'w',encoding='utf-8').write(re.sub('_vastus_',f,s))
PY
run_kontroll() {
  local cnt n; cnt=$(python3 -c "import json,sys;print(len(json.load(open(sys.argv[1]))['tests']))" "$1")
  for ((n=0; n<cnt; n++)); do
    python3 -c "import json,sys;t=json.load(open(sys.argv[1]))['tests'][int(sys.argv[2])];open(sys.argv[3],'w').write(t['run']);print(t['name']+' ('+str(t['points'])+' p)')" "$1" $n "$TMP/k$n.sh" > "$TMP/nimi"
    [ -n "${4:-}" ] && ! grep -q "^$4" "$TMP/nimi" && continue
    samm "$3 $(cat "$TMP/nimi")" bash -c "cd '$2' && bash '$TMP/k$n.sh'"
  done
}
if [ -n "$CTESTS" ]; then
  run_kontroll "$CTESTS/lab01-tests.json" "$R" "Classroom:" K
  E="$TMP/tyhi"; cp -R "$STARTER" "$E"; rm -rf "$E/.git"
  TYHI=$(cd "$E" && python3 -c "
import json,subprocess
t=json.load(open('$CTESTS/lab01-tests.json'))['tests']
print(sum(x['points'] for x in t if subprocess.run(['bash','-c',x['run']],capture_output=True).returncode==0))")
  samm "Classroom: tühi starter saab 0 punkti (saab $TYHI)" test "$TYHI" -eq 0
fi

# ================= Lisaülesanded =================
samm "L1: journald piir 200M" S proxmox2 'journalctl --disk-usage | grep -q -i "take up"; sudo mkdir -p /etc/systemd/journald.conf.d; printf "[Journal]\nSystemMaxUse=200M\n" | sudo tee /etc/systemd/journald.conf.d/piir.conf >/dev/null; sudo systemctl restart systemd-journald && systemctl is-active systemd-journald'
S proxmox2 'sudo mv /etc/rsyslog.d/90-keskserver.conf /etc/rsyslog.d/05-keskserver.conf; sudo rsyslogd -N1 >/dev/null 2>&1 && sudo systemctl restart rsyslog; logger -p local0.info -t pood "tellimus 2002 $RUN"'
samm "L2: 05- -> 2002 keskserveris (max 60 s)" oota S proxmox1 'sudo grep -q "tellimus 2002 $RUN" /var/log/remote/proxmox2/pood.log'
samm "L2: 2002 ei ole proxmox2 messages-is" S proxmox2 '! sudo grep -q "tellimus 2002 $RUN" /var/log/messages'
S proxmox2 'sudo mv /etc/rsyslog.d/05-keskserver.conf /etc/rsyslog.d/90-keskserver.conf; sudo systemctl restart rsyslog'
S proxmox1 'sudo systemctl stop rsyslog'; S proxmox2 'for i in 1 2 3; do logger -t n01test "ootel $i $RUN"; done'; sleep 2; S proxmox1 'sudo systemctl start rsyslog'
L5=0; for i in $(seq 18); do L5=$(S proxmox1 'sudo cat /var/log/remote/proxmox2/n01test.log 2>/dev/null | grep -c "ootel . $RUN"'); [ "${L5:-0}" -ge 3 ] && break; sleep 5; done
info "L5: keskserver maas, kohale $L5/3 ~$((i*5)) s"
samm "L5: mälujärjekord toob 3/3 (max 90 s)" test "${L5:-0}" -ge 3
S proxmox1 'cat <<'"'"'EOF'"'"' | sudo tee /etc/rsyslog.d/49-json.conf >/dev/null
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
sudo sed -i "s#^ruleset(name=\"kaugelt\") {#ruleset(name=\"kaugelt\") {\n    action(type=\"omfile\" file=\"/var/log/remote/koik.json\" template=\"Json\")#" /etc/rsyslog.d/50-keskserver.conf'
samm "L6: JSON mall -N1 ok" S proxmox1 'sudo rsyslogd -N1 2>&1 | grep -q "End of config validation run. Bye."'
S proxmox1 'sudo systemctl restart rsyslog'; S proxmox2 "logger -p local3.warning -t jsontest 'json test $RUN'"
samm "L6: koik.json kehtiv JSON, tosidus=warning (max 60 s)" oota S proxmox1 'sudo grep "json test $RUN" /var/log/remote/koik.json | tail -1 | python3 -c "import sys,json; d=json.loads(sys.stdin.read()); assert d[\"tosidus\"]==\"warning\", d"'
S proxmox1 'sudo rm -f /etc/rsyslog.d/49-json.conf; sudo sed -i "/koik.json/d" /etc/rsyslog.d/50-keskserver.conf'
samm "L7: aureport -au" S proxmox3 'sudo aureport --input-logs -au | grep -q -i "authentication report"'
S proxmox1 'printf "module(load=\"imudp\")\ninput(type=\"imudp\" port=\"514\" ruleset=\"kaugelt\")\n" | sudo tee /etc/rsyslog.d/52-udp.conf >/dev/null; sudo firewall-cmd -q --permanent --add-port=514/udp 2>/dev/null; sudo firewall-cmd -q --reload 2>/dev/null; sudo systemctl restart rsyslog'; sleep 2
S proxmox2 "logger -n $P1 -P 514 -d -t veebudp -f /tmp/veeb.log"; sleep 8
L4=$(S proxmox1 'sudo cat /var/log/remote/proxmox2/veebudp.log 2>/dev/null | wc -l'); info "L4: UDP 50000 reast kohale $L4"
samm "L4: UDP jõuab vähemalt osaliselt" test "${L4:-0}" -gt 0

# ================= Kodutöö =================
S proxmox2 'for i in $(seq 20); do logger -p user.info -t pood "tellimus $i"; done; logger -p user.err -t pood "makse ebaõnnestus"'
for u in admin oracle guest; do SISSE $u proxmox2; done; sleep 3
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
t_kt() { on 'proxmox2' "$KT" && on 'proxmox3' "$KT" && on 'from ' "$KT" && on 'makse ebaõnnestus' "$KT"; }
samm "Kodutöö: logiraport.sh" t_kt
if [ -n "$CTESTS" ]; then
  scp -F "$CFG" -q proxmox1:logiraport.sh "$R/kodutoo/"
  echo "$KT" > "$TMP/kt.txt"
  python3 - "$R/README.md" "$TMP/kt.txt" <<'PY'
import sys
p,kt=sys.argv[1],open(sys.argv[2],encoding='utf-8').read().strip()
s=open(p,encoding='utf-8').read(); s=s.replace('_kodutöö_',kt,1)
s=s.replace('_kodutöö_','Skript loeb iga kord kõik read uuesti, 50 masina ja 1 GB päevas korral läheb see aeglaseks ja ketas täitub; raport ei hoiata ise.')
open(p,'w',encoding='utf-8').write(s)
PY
  run_kontroll "$CTESTS/lab01-tests.json" "$R" "Classroom pärast kodutööd:"
fi

# ================= Lingid =================
for u in $(grep -ho 'https\?://[^) >`]*' docs/week01/*.md | sort -u); do
  samm "Link: $u" bash -c "curl -s -o /dev/null -L --max-time 15 -w '%{http_code}' '$u' | grep -q '^2'"
done

# ================= RAM =================
RAM=$(S proxmox1 'ps -o rss= -C rsyslogd | awk "{s+=\$1} END {printf \"%.1f MB\", s/1024}"')
MEM=$(S proxmox1 'free -m | awk "/Mem:/ {print \$2\" MB kokku, \"\$7\" MB available\"}"')
info "RAM proxmox1: rsyslogd $RAM (50 000 rida veebilogi sees); $MEM"

if [ "${KEEP:-0}" = 1 ]; then echo "== KEEP=1: sõlmed jäävad labori lõppseisu"; else echo "== Koristus pärast"; koristus; fi

# ================= RESULTS.md =================
OS=$(S proxmox1 '. /etc/os-release; echo $PRETTY_NAME'); VER=$(S proxmox1 'rpm -q rsyslog logrotate audit openssh-server | tr "\n" " "')
{
  echo "## week01 - Masina logid ja keskne logiserver (labor: öövahetus)"
  echo
  echo "- Käivitatud: $(date '+%F %H:%M')"
  echo "- Keskkond: $OS ×3 (SSH-konf: \`${SSH_CONFIG:-~/.ssh/config}\`), $(ansible --version | head -1)"
  echo "- Versioonid: $VER"
  echo "- Tulemus: **$OK OK, $FAIL FAIL**"
  echo "- Märkused:"; for m in "${INFO[@]}"; do echo "    - $m"; done
  echo "- TESTIMATA: L8 (oma valvur, lahendust pole antud), L9 (TLS), L10 (kettal püsiv järjekord: eeltestis jäid kirjed kettale ega jõudnud kohale; ülesanne on uurimuslik), L11 (räsid), L12 (systemd-journal-remote)."
  echo
  echo "| Samm | Tulemus | Väljund (FAIL korral) |"
  echo "|---|---|---|"
  cat "$LOG"
  echo
} > "$TMP/week01.md"
RF=tests/RESULTS.md
[ -f $RF ] || printf '# Laborite testitulemused\n\nIga labor käiakse läbi skriptiga `tests/weekNN.sh`. Uuem tulemus asendab sama nädala vana osa.\n\n' > $RF
python3 - "$RF" "$TMP/week01.md" <<'EOF'
import sys,re
r,new=sys.argv[1],open(sys.argv[2]).read(); s=open(r).read()
s=re.sub(r'(?s)## week01 .*?(?=\n## week|\Z)', '', s).rstrip()+'\n\n'+new
open(r,'w').write(s)
EOF
rm -rf "$TMP"
echo "== $OK OK, $FAIL FAIL  -> $RF"
[ "$FAIL" -eq 0 ]
