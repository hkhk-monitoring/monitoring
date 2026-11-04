---
tags:
  - Kodutöö
  - Monitooring
  - Logid
---

# Kodutöö: hommikune logiraport

Keskserver kogub praktikumi järel kahe masina logisid, kuid neid ei loe keegi rida realt. Kodutöös kirjutad `proxmox1`-s skripti, mis teeb logidest lühikese hommikuse raporti: mis masinad saatsid logisid, kui palju oli veateateid ja millistelt IP-aadressidelt prooviti sisse logida tundmatu kasutajanimega.

Eeldus on praktikumi osad 9–11: `proxmox1` kaustas `/var/log/remote/` on kummagi jälgitava masina kaust. Kaustade nimed on masinate tegelikud hostinimed (`ssh proxmox2 hostname`), mitte SSH aliased. Tähtaja näed Classroom 50-s.

## 1. Tekita andmeid

Raport on huvitavam, kui logides on midagi. Sinu arvutist:

```bash
ssh proxmox2 'for i in $(seq 20); do logger -p user.info -t pood "tellimus $i"; done'
ssh proxmox2 'logger -p user.err -t pood "makse ebaõnnestus"'
ssh proxmox3 'logger -p user.warning -t varundus "ketas 85% täis"'
for u in admin oracle guest; do
  ssh -o User=$u -o PubkeyAuthentication=no -o ConnectTimeout=5 proxmox2
done
```

Kui masin lubab paroolisisselogimist, küsitakse iga kasutaja puhul parooli: ära sisesta midagi, vajuta **Ctrl+C**. Kui paroolisisselogimine on keelatud, lõpeb ühendus kohe veaga `Permission denied`. Mõlemal juhul jääb logisse rida `Invalid user`, kui sellist kasutajat masinas pole.

## 2. Skript tükkhaaval

Logi sisse `proxmox1`-sse (`ssh proxmox1`) ja loo seal skript `nano ~/logiraport.sh`. Testi iga sammu järel: `sudo bash ~/logiraport.sh`.

**1. samm:** päis ja masinad, kes on logisid saatnud. Iga alamkaust `/var/log/remote/` all on üks masin (failid, mis on otse `/var/log/remote/` all, näiteks osas 9 loodud `turvalogi.log`, ei ole masinate kaustad ja jäävad välja):

```bash
#!/bin/bash
KAUST=/var/log/remote
echo "=== Logiraport $(date '+%F %H:%M') ==="
echo "Masinad:"
ls -d "$KAUST"/*/
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

**3. samm:** iga masina kohta programm, mis kirjutas kõige rohkem ridu. Iga programmi read on eraldi failis, seega loe iga faili ridade arv ja vali suurim. Vihje: `wc -l < fail` annab ainult arvu, ilma failinimeta.

**4. samm:** tundmatu kasutajanimega sisselogimised. Loe kõigist masinatest `Invalid user` read ja loenda, mitu tuli igalt IP-aadressilt:

```bash
echo "Tundmatu kasutajanimega sisselogimised (mitu korda, IP):"
grep -h "Invalid user" "$KAUST"/*/*.log \
  | grep -oE 'from [0-9.]+' | cut -d' ' -f2 \
  | sort | uniq -c | sort -rn
```

Raportis on ka IP `192.168.125.187` (kasutaja `kontroll`). See on õpetaja kontrollserver (laboritahvel), mis loeb masinate seisu iga minut. Need read ei ole rünnak.

Loe torujuhet vasakult paremale ja lisa iga etapi ette kommentaar, mis selgitab, mida see etapp teeb. Kui mõnest aru ei saa, käivita torujuhe järk-järgult (kõigepealt ainult `grep`, siis lisa järgmine osa).

**5. samm:** iga masina viis viimast veateadet. Keskserveri failides ei ole tõsidus reas kirjas (loeng, joonis 1.2), seega ei saa seda `grep`-iga otsida. Kasuta sõnu: otsi ridu, kus on `error`, `fail` või `ebaõnnestus` (tõstutundetult, `grep -i -E`). Read on eri failides, seega järjesta need enne viie viimase valimist aja järgi: `sort -k1,1M -k2,2n -k3,3`.

**Mõtle:** Miks on sõnade järgi otsimine halvem kui tõsiduse järgi? Mis rea võid nii kahe silma vahele jätta? (Praktikumi lisaülesanne 6 lahendab selle.)

## 3. Vasta

Vastused lähevad praktikumi 1 repositooriumi `README.md` lõppu, osasse **Kodutöö** (küsimused on seal juba olemas). Kirjuta vastus iga `_kodutöö_` asemele:

1. Lisa raporti väljund koodiplokki (```` ```text ````).
2. Mis IP-aadressilt tulid tundmatu kasutajanimega sisselogimised ja miks on see aadress sinu laboris just see?
3. Kui sul oleks 50 masinat ja iga masin kirjutaks 1 GB logisid päevas, mis läheks sinu skriptiga katki? Nimeta kaks asja.
4. Raport näitab, mis oli. Mida ta ei tee, mida tahaksid, et seiresüsteem teeks? (See on järgmiste kohtumiste teema.)
5. Miks on sõnade järgi vigade otsimine halvem kui tõsiduse järgi? (Samm 5 "Mõtle" küsimus.)

## Esitamine

Skript ja vastused lähevad praktikumi 1 repositooriumisse. Kui oled veel `proxmox1`-s, välju käsuga `exit`. Seejärel oma arvutis, repositooriumi juurkaustas:

```bash
scp proxmox1:logiraport.sh kodutoo/
git status
git add kodutoo/logiraport.sh README.md
git commit -m "Kodutöö 1: logiraport"
git push
```

Tulemuse näed Classroom 50-s.

## Lisaülesanded

**A. Iga hommik kell 7.** Seadista systemd taimer, mis käivitab raporti iga päev kell 07:00 ja kirjutab tulemuse faili `/var/log/logiraport.log`. Kontrolli `systemctl list-timers`-iga, millal see järgmine kord käivitub.

**B. Ainult eilne ja tänane päev.** Praegu loeb skript kõiki ridu. Muuda nii, et raportis on ainult eilse ja tänase päeva read. Vihje: logirea algus on kuupäev; `date -d yesterday '+%b %e'` annab eilse kuupäeva samas vormingus.

**C. Raport Ansible'iga.** Kirjuta playbook, mis paigaldab skripti ja taimeri `proxmox1`-le, et seda saaks korrata ka uuele keskserverile.
