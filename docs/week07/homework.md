---
tags:
  - Kodutöö
  - Monitooring
  - Linux
---

# Kodutöö: oma väike mõõtja

!!! abstract "Eesmärk"
    Laboris lugesid numbreid siis, kui ise terminalis olid. Kodutöös kirjutad skripti, mis loeb samu numbreid iga 10 sekundi järel ja kirjutab need faili. Nii saad oma esimese **aegrea**: sama mõõdik mitu korda ajas (meenuta loengu osa 2).

    Maht umbes 1 tund. Jätkad laboris alustatud kausta `~/monitooring/n07`.

---

## 1. Skript tükkhaaval

Skript jookseb sõlmes `proxmox2`. Loo see seal (`ssh proxmox2`, siis `nano tervis.sh`) või VS Code Remote-SSH-ga.

**1. samm:** üks rida, ainult kellaaeg ja koormus.

```bash
#!/bin/bash
aeg=$(date +%H:%M:%S)
koormus=$(cut -d' ' -f1 /proc/loadavg)
echo "$aeg,$koormus"
```

`cut -d' ' -f1` võtab tühikutega eraldatud reast esimese välja, ehk 1 minuti koormuse. Käivita `bash tervis.sh`. Oodatav tulemus on midagi sellist nagu `18:02:11,0.04`.

**2. samm:** lisa vaba mälu megabaitides. Number on failis `/proc/meminfo` real `MemAvailable` (kilobaitides). Lisa skripti muutuja `malu` ja pane see `echo` reale koma järel (bashi muutuja nimes ei tohi olla täpitähti). Vihje:

```bash
awk '/MemAvailable/ {print int($2/1024)}' /proc/meminfo
```

**3. samm:** lisa ketta täituvus protsentides. Vihje: `df --output=pcent / | tail -1` annab näiteks ` 19%`. Eemalda tühik ja protsendimärk (`tr -d ' %'`), et jääks ainult number.

**4. samm:** pane mõõtmine tsüklisse. Kogu senine sisu (peale esimese rea) läheb tsükli sisse:

```bash
while true; do
  # sinu senised read siia
  sleep 10
done
```

Käivita, vaata paar rida ja peata `Ctrl+C`-ga.

**5. samm:** lisa faili algusesse päis, et oleks teada, mis veerg mis on. Päis kirjutatakse **üks kord**, enne tsüklit:

```bash
echo "aeg,koormus,mälu_mb,ketas_pct"
```

Oodatav tulemus:

```text
aeg,koormus,mälu_mb,ketas_pct
18:10:01,0.02,1344,19
18:10:11,0.02,1343,19
18:10:21,0.01,1344,19
```

Sellist vormingut nimetatakse CSV-ks (comma-separated values). Selle avab iga tabelarvutusprogramm.

## 2. Kogu aegrida koormuse ajal

Kasuta kahte terminali, mõlemas `ssh proxmox2`.

Terminal 1, mõõtja kirjutab faili:

```bash
bash tervis.sh | tee aegrida.csv
```

Oota 30 sekundit (kolm rahulikku rida). Siis terminal 2:

```bash
stress-ng --cpu $(nproc) --timeout 60s
```

Kui see on lõppenud, oota veel 60 sekundit ja käivita:

```bash
stress-ng --vm 1 --vm-bytes 50% --timeout 40s
```

Oota pärast seda veel 60 sekundit ja peata mõõtja (`Ctrl+C`). Kopeeri fail oma arvutisse:

```bash
scp proxmox2:aegrida.csv ~/monitooring/n07/logid/
scp proxmox2:tervis.sh ~/monitooring/n07/
```

## 3. Loe oma aegrida

Ava `logid/aegrida.csv` ja vasta failis `n07-tervis.md` uue pealkirja `## Kodutöö` all:

1. Mitmendal real (kell mis) hakkas koormus tõusma? Mitu rida (mitu korda 10 sekundit) kulus, et see jõuaks tippu?
2. Mis oli koormuse tipp? Võrdle tuumade arvuga.
3. Kas mälu testi ajal on `mälu_mb` langus näha? Kui suur?
4. Kas ketta veerg muutus? Miks?
5. Kui oleksid laboris vaadanud ainult üht `top`-i hetke, mida oleksid sellest aegreast näinud ja mida mitte?
6. Kujuta ette, et sul on 50 serverit ja tahad seda tabelit iga 10 sekundi järel terve aasta. Nimeta kaks probleemi, mis sinu skriptiga tekiksid.

Küsimus 6 on järgmise kohtumise teema.

## Esitamine

Laadi Tahvlis selle kohtumise iseseisva töö alla üles kolm faili: `n07-tervis.md`, `tervis.sh` ja `logid/aegrida.csv`.

---

## Lisapunktideks

**A. Graafik.** Ava `aegrida.csv` tabelarvutusprogrammis (LibreOffice Calc, Excel, Google Sheets) ja tee koormusest joongraafik, kus x-teljel on aeg. Lisa pilt `n07-tervis.md` faili. Kas graafikult on midagi näha, mida tabelist kohe ei märganud?

**B. Hoiatus.** Täienda `tervis.sh` nii, et kui koormus on suurem kui tuumade arv, lisatakse rea lõppu `HOIATUS`. Bash ei oska komakohaga arve võrrelda, seega kasuta `awk`-i või `bc`-d. See on sinu esimene alarm.

**C. Kõik kolm sõlme.** Muuda skript nii, et see jookseb **sinu arvutis** ja küsib SSH kaudu numbreid kõigist kolmest sõlmest, lisades igale reale veeru `sõlm`. Mis juhtub mõõtmise täpsusega, kui üks sõlm vastab aeglaselt?
