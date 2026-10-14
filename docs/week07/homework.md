---
tags:
  - Kodutöö
  - Monitooring
  - Logid
---

# Kodutöö: hommikune logiraport

!!! abstract "Eesmärk"
    Keskserver kogub nüüd kahe masina logisid. Keegi ei loe neid rida-realt. Kodutöös kirjutad `proxmox1`-s skripti, mis teeb logidest lühikese hommikuse raporti: kes saatis, kui palju vigu oli ja kas keegi proovis sisse murda.

    Maht umbes 1 tund. Eeldus: labori osa B on tehtud (`/var/log/remote/proxmox2/` ja `/var/log/remote/proxmox3/` on olemas).

---

## 1. Tekita andmeid

Raport on huvitavam, kui logides on midagi. Sinu arvutist:

```bash
ssh proxmox2 'for i in $(seq 20); do logger -p local0.info -t pood "tellimus $i"; done'
ssh proxmox2 'logger -p local0.err -t pood "makse ebaõnnestus"'
ssh proxmox3 'logger -p user.warning -t varundus "ketas 85% täis"'
for u in admin oracle guest; do
  ssh -o User=$u -o PubkeyAuthentication=no -o ConnectTimeout=5 proxmox2
done
```

## 2. Skript tükkhaaval

Kirjuta skript `proxmox1`-s (`nano ~/logiraport.sh`). Testi iga sammu järel: `sudo bash ~/logiraport.sh`.

**1. samm:** päis ja masinad, kes on logisid saatnud. Iga alamkaust `/var/log/remote/` all on üks masin:

```bash
#!/bin/bash
KAUST=/var/log/remote
echo "=== Logiraport $(date '+%F %H:%M') ==="
echo "Masinad:"
ls "$KAUST"
```

**2. samm:** iga masina kohta ridade arv kokku. Lisa tsükkel:

```bash
for m in "$KAUST"/*/; do
  nimi=$(basename "$m")
  read=$(cat "$m"*.log | wc -l)
  echo "  $nimi: $read rida"
done
```

`"$m"*.log` tähendab kõiki `.log` faile selle masina kaustas.

**3. samm:** iga masina kohta programm, kes kirjutas kõige rohkem. Vihje: failide suurus ridades on `wc -l "$m"*.log`, sorteeri `sort -n` ja võta eelviimane rida (viimane on "total"). Või lihtsam: `wc -l "$m"*.log | sort -n | tail -2 | head -1`.

**4. samm:** sissetungi katsed. Loe kõigist masinatest `Invalid user` read ja loenda, mitu tuli mis IP-lt:

```bash
echo "Sissetungi katsed (IP, mitu korda):"
grep -h "Invalid user" "$KAUST"/*/*.log \
  | grep -oE 'from [0-9.]+' \
  | sort | uniq -c | sort -rn
```

Loe torud vasakult paremale ja kirjuta iga `|` järel olev osa kommentaarina skripti, mida see teeb. Kui mõnest aru ei saa, käivita torujuhe järk-järgult (kõigepealt ainult `grep`, siis lisa järgmine osa).

**5. samm:** viimased 5 viga. Keskserveri failides ei ole tõsidus reas kirjas (loeng, joonis 7.1), seega ei saa seda `grep`-iga otsida. Kasuta sõnu: otsi ridu, kus on `error`, `fail` või `ebaõnnestus` (tõstutundetult, `grep -i -E`). Näita ainult 5 viimast.

💭 **Mõtle:** Miks on sõnade järgi otsimine halvem kui tõsiduse järgi? Mis rea võid nii kahe silma vahele jätta? (Lisaülesanne 5 laboris lahendab selle.)

## 3. Vasta

Pane raporti väljund ja vastused oma arvutis faili `n07-logid.md` uue pealkirja `## Kodutöö` alla:

1. Kopeeri raporti väljund (``` plokki).
2. Mis IP-lt tulid sissetungi katsed ja miks on see IP sinu laboris just see?
3. Kui sul oleks 50 masinat ja iga masin kirjutaks 1 GB logisid päevas, mis läheks sinu skriptiga katki? Nimeta kaks asja.
4. Raport näitab, mis oli. Mida ta ei tee, mida tahaksid, et seiresüsteem teeks? (See on järgmiste kohtumiste teema.)

## Esitamine

Laadi Tahvlis selle kohtumise iseseisva töö alla üles `logiraport.sh` ja `n07-logid.md`.

---

## Lisapunktideks

**A. Iga hommik kell 7.** Pane raport käima `systemd` timeriga iga päev kell 07:00 ja kirjutama tulemuse faili `/var/log/logiraport.log`. Kontrolli `systemctl list-timers`-iga, millal see järgmine kord käivitub.

**B. Ainult viimased 24 tundi.** Praegu loeb skript kõiki ridu. Muuda nii, et raportis on ainult viimase ööpäeva read. Vihje: logirea algus on kuupäev; `date -d yesterday '+%b %e'` annab eilse kuupäeva samas vormingus.

**C. Raport Ansiblega.** Kirjuta playbook, mis paigaldab skripti ja timeri `proxmox1`-le, et seda saaks korrata ka uuele keskserverile.
