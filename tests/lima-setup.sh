#!/bin/bash
# Testkeskkond: kolm AlmaLinux 9 VM-i (lima), mis matkivad automatiseerimise kursuse proxmox1-3 sõlmi.
# Kasutus:  bash tests/lima-setup.sh up      # loob/käivitab VM-id, seab hostinimed, paigaldab firewalld
#           bash tests/lima-setup.sh down    # peatab ja kustutab VM-id
# Loob SSH-konfi tests/.ssh_config (Host proxmox1-3), mida week*.sh kasutab: SSH_CONFIG=tests/.ssh_config
set -euo pipefail
cd "$(dirname "$0")"
CFG="$PWD/.ssh_config"
SOLMED="proxmox1 proxmox2 proxmox3"

case "${1:-up}" in
  up)
    for n in $SOLMED; do
      if ! limactl list -q 2>/dev/null | grep -qx "$n"; then
        limactl create --tty=false --name="$n" --cpus=1 --memory=1 --disk=10 \
          --network=lima:user-v2 --set '.mounts=[]' template:almalinux-9
      fi
      limactl list "$n" --format '{{.Status}}' | grep -q Running || limactl start --tty=false "$n"
    done
    : > "$CFG"
    for n in $SOLMED; do sed "s/^Host lima-$n/Host $n/" ~/.lima/"$n"/ssh.config >> "$CFG"; done
    for n in $SOLMED; do
      ssh -F "$CFG" "$n" "sudo hostnamectl set-hostname $n
        rpm -q firewalld >/dev/null || sudo dnf -y -q install firewalld
        sudo systemctl enable --now firewalld >/dev/null 2>&1
        sudo systemctl restart rsyslog"
      echo "$n: $(ssh -F "$CFG" "$n" 'hostname; hostname -I' | tr '\n' ' ')"
    done
    ;;
  down)
    for n in $SOLMED; do limactl stop "$n" 2>/dev/null || true; limactl delete "$n" 2>/dev/null || true; done
    rm -f "$CFG"
    ;;
esac
