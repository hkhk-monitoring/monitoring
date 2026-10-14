---
tags:
  - Labor
  - Monitooring
  - Linux
  - Algaja
---

# Labor: masina seisundi lugemine käsitsi

**Eeldused:** [loeng](lecture.md) loetud. Automatiseerimise kursusest: `ssh proxmox1`, `ssh proxmox2`, `ssh proxmox3` töötavad ilma paroolita (nädal 1), Ansible on sinu arvutis (nädal 3).

**Keskkond:** sinu arvuti (VS Code, terminal) ja kolm Proxmoxi sõlme. Selles laboris ei paigalda sa ühtegi seiresüsteemi. Töötad ainult käsureaga.

!!! abstract "Eesmärgid"
    Pärast laborit oskad:

    1. lugeda käskudega `uptime`, `free`, `df` ja `top` välja masina neli põhinäitajat;
    2. leida samad numbrid kaustast `/proc` ja selgitada, kust käsud need saavad;
    3. tekitada `stress-ng`-ga koormust ja ennustada, mis numbritega juhtub;
    4. diagnoosida tundmatut probleemi ainult numbrite põhjal ja põhjendada oma järeldust.

    **Mis valmib:** fail `n07-tervis.md` sinu arvutis. Selles on kolme sõlme tervisetabel, sinu ennustused ja müsteeriumi diagnoos. Sama faili jätkad kodutöös.

---

## Eeltöö

### Töökaust

Loo oma arvutis kursuse jaoks kaust ja ava see VS Code'is:

```bash
mkdir -p ~/monitooring/n07/logid
cd ~/monitooring/n07
code .
```

Loo kausta fail `n07-tervis.md`. Alusta ainult pealkirjaga, sisu tuleb laboris samm-sammult:

```markdown
# N7 tervisekontroll

## Ennustused
```

### Kas sõlmed vastavad?

Seda tsüklit kasutasid automatiseerimise nädalal 1. See käib kolm sõlme läbi ja küsib igaühelt nime:

```bash
for h in proxmox1 proxmox2 proxmox3; do
  ssh $h hostname
done
```

Oodatav tulemus: kolm rida, igaühel sõlme nimi, ja parooli ei küsita.

💡 **Kui mõni sõlm ei vasta:** kontrolli kõigepealt, kas oled kooli võrgus või VPN-is. Siis `ssh -v proxmox2` näitab, kus ühendus katkeb. Kui sõlm on maas, anna õpetajale teada ja tee esialgu ülejäänutega.

### stress-ng kõigisse sõlmedesse

`stress-ng` on tööriist, mis tekitab meelega koormust. Paigalda see Ansiblega kõigisse kolme sõlme ühe käsuga:

```bash
ansible all -i proxmox1,proxmox2,proxmox3, -b -m ansible.builtin.package -a "name=stress-ng state=present"
```

| Osa | Tähendus |
|---|---|
| `-i proxmox1,proxmox2,proxmox3,` | inventory otse käsureal. **Lõpu koma on vajalik**, muidu otsib Ansible faili nimega `proxmox1,proxmox2,proxmox3` |
| `-b` | `become`, ehk sudo (paigaldus vajab root-õigust) |
| `-m ansible.builtin.package` | sama moodul, mida kasutasid automatiseerimise nädalal 3 |

*Tabel 1. Käsu osad*

Oodatav tulemus: kolm `CHANGED` (või `SUCCESS`, kui oli juba olemas).

💡 **Kui näed `No package stress-ng available`:** paigalda enne EPEL-i hoidla: `ansible all -i proxmox1,proxmox2,proxmox3, -b -m ansible.builtin.package -a "name=epel-release state=present"` ja korda.

---

## Osa A · Neli küsimust ühele masinale

Selles osas uurid ühte sõlme, `proxmox2`. Ava VS Code'is **kaks terminali** (`` Ctrl+Shift+` `` avab teise) ja logi mõlemas sisse:

```bash
ssh proxmox2
```

Kogu osa A jooksul on terminal 1 "vaatamiseks" ja terminal 2 "tegemiseks".

### A1. Enne mõõtmist ennusta

Kirjuta faili `n07-tervis.md` osa "Ennustused" alla oma arvamus, **enne** kui midagi käivitad:

```markdown
- proxmox2 tuumade arv: ?
- proxmox2 mälu kokku: ?
- proxmox2 kõvaketas / täituvus: ?
- kaua on proxmox2 üleval olnud: ?
```

Ennustus võib olla vale, ja see ongi mõte. Hiljem näed, kui hästi sa oma masinat tundsid.

### A2. Kas ta on üleval?

Terminal 1:

```bash
uptime
```

```text
 10:14:02 up 12 days,  3:41,  1 user,  load average: 0.08, 0.03, 0.01
```

Rida algab kellaajaga, siis `up` ja aeg alates viimasest käivitusest. Sama numbrit sekundites näitab tuum otse:

```bash
cat /proc/uptime
```

```text
1050123.45 2088410.12
```

Esimene number on sekundid alates käivitusest. Teine on aeg, mille kõik tuumad kokku on tühjalt seisnud (seepärast võib see olla esimesest suurem).

Inimesele loetav kuju:

```bash
uptime -p
```

💭 **Mõtle:** Miks hoiab tuum aega sekundites, mitte "12 päeva, 3 tundi"? Kumb sobib paremini masinale, kes peab numbreid võrdlema?

### A3. Kas ta jõuab?

Kõigepealt: mitu "kassat" on? (Meenuta loengust poe kassade võrdlust.)

```bash
nproc
```

Nüüd koormus otse tuumast:

```bash
cat /proc/loadavg
```

```text
0.08 0.03 0.01 1/142 23817
```

| Väli | Tähendus |
|---|---|
| `0.08 0.03 0.01` | koormus 1, 5 ja 15 minuti keskmisena (sama, mis `uptime` näitab) |
| `1/142` | praegu töötab 1 protsess, kokku on 142 |
| `23817` | viimati loodud protsessi number |

*Tabel 2. `/proc/loadavg` väljad*

Arvuta: esimene number jagatud tuumade arvuga. Kas tulemus on alla 1?

✅ **Kontrollpunkt:** tead `proxmox2` tuumade arvu ja oskad öelda, kas masin on praegu koormatud. Kontrolli oma ennustust A1-st.

### A4. Kas tal on ruumi mõelda?

```bash
free -h
```

```text
               total        used        free      shared  buff/cache   available
Mem:           1.7Gi       412Mi       187Mi       4.0Mi       1.3Gi       1.3Gi
Swap:          2.0Gi          0B       2.0Gi
```

Sinu numbrid on teised. Leia rida `Mem:` ja vaata kolme veergu:

- `total`: kogu mälu;
- `free`: täiesti puutumata mälu (tavaliselt väike, ja see on normaalne);
- `available`: mälu, mida programm saab kohe kasutada. **Seda veergu vaata.**

Kust `free` oma numbrid saab? Vaata ise:

```bash
grep -E '^(MemTotal|MemFree|MemAvailable|Cached)' /proc/meminfo
```

```text
MemTotal:        1799124 kB
MemFree:          191488 kB
MemAvailable:    1376540 kB
Cached:          1189224 kB
```

`/proc/meminfo` annab kilobaitides. `free -h` muudab need inimesele loetavaks (`Mi`, `Gi`).

💭 **Mõtle:** Võrdle `MemAvailable` ja `free -h` veergu `available`. Kas need on sama number? Kui palju on vahet `MemFree` ja `MemAvailable` vahel ja kuhu see mälu "läks"?

### A5. Kas tal on ruumi hoida?

```bash
df -h
```

Sa näed mitut rida. Paljud neist (`tmpfs`, `devtmpfs`) on mälus elavad ajutised failisüsteemid. Meid huvitab rida, mille `Mounted on` on `/`:

```bash
df -h /
```

```text
Filesystem                  Size  Used Avail Use% Mounted on
/dev/mapper/almalinux-root   17G  3.1G   14G  19% /
```

Vaata veergu `Use%`. Kui see läheneb 90%-le, on aeg tegutseda.

Kus ruum kulub? Logid on tavaline süüdlane (meenuta Kati e-poodi):

```bash
sudo du -sh /var/log
```

✅ **Kontrollpunkt:** tead `proxmox2` mälu (`total` ja `available`) ja ketta täituvust (`Use%`). Kirjuta need faili `n07-tervis.md` ja võrdle oma ennustusega.

### A6. Kõik korraga: top

Neli käsku on hea, aga `top` näitab kõike ühel ekraanil ja uuendab iga 3 sekundi järel. Terminal 1:

```bash
top
```

Ülemised viis rida on kogu masina kohta:

```text
top - 10:31:44 up 12 days,  3:58,  1 user,  load average: 0.00, 0.01, 0.00
Tasks: 142 total,   1 running, 141 sleeping,   0 stopped,   0 zombie
%Cpu(s):  0.3 us,  0.3 sy,  0.0 ni, 99.3 id,  0.0 wa,  0.0 hi,  0.0 si,  0.0 st
MiB Mem :   1756.9 total,    186.5 free,    411.8 used,   1302.4 buff/cache
MiB Swap:   2048.0 total,   2048.0 free,      0.0 used.   1345.1 avail Mem
```

<figure markdown="span">
  ![top programmi päis proxmox2 sõlmes, viis rida koormuse, protsesside, protsessori ja mälu kohta](../images/n07_top_pais.png)
  <figcaption>Joonis 7.1. Oodatav tulemus: `top` päis rahulikus masinas. `id` (idle) on üle 95%.</figcaption>
</figure>
<!-- TODO Maria: ekraanipilt proxmox2-st, `top` kohe pärast käivitust, rahulik masin. -->

| Rida | Mida sealt vaatad |
|---|---|
| 1 | `load average`, sama mis `uptime` |
| 2 | mitu protsessi on kokku ja mitu töötab |
| 3 | protsessori aeg: `us` = programmid, `sy` = tuum, `id` = tühi, `wa` = ootab ketast |
| 4-5 | mälu (`avail Mem` = sama mis `free` veerg `available`) |

*Tabel 3. `top` päise read*

Allpool on protsesside nimekiri. Proovi klahve, kuni `top` on lahti:

| Klahv | Mida teeb |
|---|---|
| `P` | sorteeri protsessori järgi (vaikimisi) |
| `M` | sorteeri mälu järgi |
| `1` | näita iga tuuma eraldi |
| `q` | välju |

*Tabel 4. `top` klahvid*

Vajuta `M`. Milline protsess kasutab `proxmox2`-s kõige rohkem mälu? Jäta `top` lahti, seda on kohe vaja.

### A7. Pane protsessor tööle

**Ennusta enne:** kirjuta faili `n07-tervis.md`, mis juhtub `top`-is, kui käivitad ühe protsessorit koormava protsessi:

- mis juhtub `id` väärtusega?
- mis juhtub esimese koormuse numbriga (1 min) ja mis kolmandaga (15 min)?

Terminal 2:

```bash
stress-ng --cpu 1 --timeout 90s
```

`--cpu 1` käivitab ühe töötaja, mis arvutab vahetpidamata. `--timeout 90s` lõpetab 90 sekundi pärast ise.

Vaata terminal 1-s `top`-i. Protsesside nimekirja tippu ilmub `stress-ng-cpu`, umbes 100% juures. Kui sul on 2 tuuma, langeb `id` umbes 50%-le: üks kassa töötab, teine on vaba.

Kui esimene jooks on läbi, käivita nii palju töötajaid, kui on tuumi:

```bash
stress-ng --cpu $(nproc) --timeout 90s
```

`$(nproc)` asendub sinu tuumade arvuga. Nüüd peaks `id` olema 0 lähedal ja koormus (1 min) ronib tuumade arvu poole.

<figure markdown="span">
  ![top programmi vaade koormuse ajal: stress-ng protsessid nimekirja tipus, protsessor täis hõivatud](../images/n07_top_stress.png)
  <figcaption>Joonis 7.2. Oodatav tulemus: `stress-ng --cpu $(nproc)` ajal on `id` nulli lähedal ja `stress-ng-cpu` protsessid on nimekirja tipus.</figcaption>
</figure>
<!-- TODO Maria: ekraanipilt proxmox2-st, `top` umbes 60 s pärast `stress-ng --cpu $(nproc)` käivitust. -->

Kui `stress-ng` lõpetab, ära sulge `top`-i. Vaata 2 minutit, kuidas koormus langeb. Või sulge `top` (`q`) ja vaata ainult koormust:

```bash
watch -n 5 cat /proc/loadavg
```

`watch` käivitab käsu iga 5 sekundi järel uuesti. Välju `Ctrl+C`-ga.

💭 **Mõtle:** Protsessor oli 90 sekundit täis. Miks 1 minuti koormus tõusis kiiresti, aga 15 minuti koormus vaevu liikus? Mida see ütleb sulle, kui näed kunagi `load average: 0.30, 0.50, 3.90`?

Võrdle tulemust oma ennustusega. Kirjuta faili üks lause: mis läks nii, nagu arvasid, ja mis üllatas.

### A8. Pane mälu tööle

**Ennusta enne:** mis juhtub `free -h` veergudega `used`, `buff/cache` ja `available`, kui üks programm võtab 60% mälust?

Terminal 1:

```bash
free -h -s 2
```

`-s 2` kordab väljundit iga 2 sekundi järel.

Terminal 2:

```bash
stress-ng --vm 1 --vm-bytes 60% --timeout 60s
```

`--vm 1` käivitab ühe mälutöötaja, `--vm-bytes 60%` ütleb, kui palju mälu see võtab.

⚠️ **Ära mine üle 80%.** Kui mälu saab päriselt otsa, hakkab Linuxi tuum programme sulgema (OOM killer) ja võib sulgeda ka sinu SSH-ühenduse.

Jälgi terminal 1-s, kuidas `used` kasvab ja `available` kahaneb. Mis juhtub `buff/cache`-ga? Kui `stress-ng` lõpetab, kas numbrid lähevad tagasi?

💭 **Mõtle:** `buff/cache` jäi pärast testi väiksemaks, kui see enne oli. Kas see on probleem? (Vihje: loeng, osa 5.)

✅ **Kontrollpunkt:** failis `n07-tervis.md` on kaks ennustust (protsessor ja mälu) ja kummagi järel üks lause selle kohta, mis päriselt juhtus.

---

!!! info "Paus"
    Enne pausi välju kummastki SSH-sessioonist (`exit`). Pärast pausi töötad iseseisvalt.

---

## Osa B · Kolm sõlme ja üks müsteerium

Osas A uurisid ühte masinat ja teadsid, mida tegid. Osas B kasutad sama oskust kahes uues olukorras: kolm masinat korraga ja probleem, mille põhjust sa ei tea.

### B1. Tervisetabel kolmest sõlmest

Ehita oma arvutis käsk, mis küsib kõigilt kolmelt sõlmelt samad numbrid. Ehita see **tükkhaaval** ja testi iga tüki järel.

**1. samm:** ainult üks käsk ühele sõlmele.

```bash
ssh proxmox1 "nproc"
```

**2. samm:** sama kolmele sõlmele, ja nimi ette, et oleks näha, kes vastas.

```bash
for h in proxmox1 proxmox2 proxmox3; do
  echo "== $h"
  ssh $h "nproc"
done
```

**3. samm:** lisa ise jutumärkide sisse ülejäänud käsud, eraldatuna semikooloniga. Sul on vaja:

- koormust (millise käsuga?);
- mälu rida `Mem:` (vihje: `free -h | grep Mem`);
- juurfailisüsteemi rida (vihje: `df -h / | tail -1`).

**4. samm:** kui väljund on õige, salvesta see faili. `tee` näitab väljundi ekraanil **ja** kirjutab faili:

```bash
for h in proxmox1 proxmox2 proxmox3; do
  echo "== $h"
  ssh $h "..."   # sinu 3. sammu käsud siia
done | tee logid/tervis.txt
```

Nüüd täida failis `n07-tervis.md` tabel. Numbrid võta failist `logid/tervis.txt`:

```markdown
## Tervisetabel

| Sõlm | Tuumi | Koormus (1 min) | Mälu kokku | available | Ketas / Use% |
|---|---|---|---|---|---|
| proxmox1 | | | | | |
| proxmox2 | | | | | |
| proxmox3 | | | | | |
```

✅ **Kontrollpunkt:** tabelis on kõik 15 lahtrit täidetud ja `logid/tervis.txt` on olemas.

💭 **Mõtle:** Järgmisel kohtumisel käivitad `proxmox1`-s seiresüsteemi (Prometheus), mis vajab umbes 300 MB mälu, hiljem rohkem. Kas `proxmox1`-l on selleks ruumi? Kirjuta tabeli alla üks lause.

### B2. Müsteerium

Nüüd tekitab skript `proxmox3`-s **ühe juhusliku probleemi**, ja sa ei tea, millise. Sinu töö on see leida ainult numbrite põhjal.

Logi sisse `proxmox3`-sse ja loo seal fail `mysteerium.sh`:

```bash
ssh proxmox3
nano mysteerium.sh
```

Skript on lühike. Loe see enne läbi, et teaksid, mida see sinu masinas teeb:

```bash
#!/bin/bash
# Tekitab 5 minutiks ühe juhusliku probleemi. Vastus: /tmp/.vastus
valikud=(protsessor malu ketas)
v=${valikud[$RANDOM % 3]}
echo "$v" > /tmp/.vastus

case $v in
  protsessor) nohup stress-ng --cpu "$(nproc)" --timeout 300s >/dev/null 2>&1 & ;;
  malu)       nohup stress-ng --vm 1 --vm-bytes 65% --vm-keep --timeout 300s >/dev/null 2>&1 & ;;
  ketas)      vaba=$(df --output=avail -k ~ | tail -1)
              fallocate -l $((vaba * 4 / 10))K ~/.peidus
              nohup bash -c 'sleep 300; rm -f ~/.peidus' >/dev/null 2>&1 & ;;
esac
echo "Midagi juhtub järgmise 5 minuti jooksul. Leia, mis."
```

| Rida | Mida teeb |
|---|---|
| `${valikud[$RANDOM % 3]}` | valib kolmest juhuslikult ühe |
| `nohup ... &` | käivitab taustal; töö jätkub ka siis, kui sulged terminali |
| `fallocate -l ...` | loob faili, mis võtab 40% vabast kettaruumist |
| `sleep 300; rm -f` | 5 minuti pärast kustutab faili ise |

*Tabel 5. Mida müsteeriumiskript teeb*

Salvesta (`Ctrl+O`, `Enter`, `Ctrl+X`) ja käivita:

```bash
bash mysteerium.sh
```

**Ära vaata faili `/tmp/.vastus`.** Kasuta ainult nelja küsimust ja käske, mida osas A kasutasid. Diagnoosimiseks on sul 5 minutit.

Kirjuta faili `n07-tervis.md`:

```markdown
## Müsteerium 1

- Mida kontrollisin (käsud järjekorras):
- Mis number oli tavalisest erinev:
- Minu diagnoos:
- Õige vastus (cat /tmp/.vastus):
```

Kui diagnoos on kirjas, kontrolli:

```bash
cat /tmp/.vastus
```

Oota, kuni 5 minutit on läbi (või kontrolli `top`-iga, et `stress-ng` on kadunud), ja **käivita skript uuesti**. Tee vähemalt kaks müsteeriumi. Kui sama probleem tuleb kaks korda järjest, käivita kolmas kord.

💡 **Kui sa ei leia midagi:** käi neli küsimust läbi järjekorras ja võrdle numbreid oma tervisetabeliga (B1). Mis on teisiti kui enne? Üks probleemidest ei mõjuta protsessorit ega mälu üldse.

💭 **Mõtle:** Milline kolmest probleemist oleks Märteni `monitor.sh` (kontrollib ainult, kas nginx käib) avastanud? Milline oleks Kati e-poe reede õhtul uuesti katki teinud?

✅ **Kontrollpunkt:** failis on vähemalt kaks müsteeriumi, igaühes käsud, number, diagnoos ja õige vastus.

---

## Kokkuvõte

Lugesid käsitsi kolme masina seisundi ja nägid, et kõik käsud võtavad numbrid samast kohast, tuuma `/proc` kaustast. Tekitasid koormust ja nägid, kuidas protsessor, koormus ja mälu reageerivad. Müsteeriumis kasutasid nelja küsimust järjekorras, et leida probleem, mida ei näinud.

Märkasid ehk ka seda, et kõik see nõudis sinu kohalolekut: pidid olema terminalis just sel hetkel, kui midagi juhtus. Järgmisel kohtumisel paned masina neid numbreid ise koguma.

## ✅ Lõpukontroll

- [ ] `ansible all -i proxmox1,proxmox2,proxmox3, -m ansible.builtin.command -a "stress-ng --version"` annab kolm vastust
- [ ] failis `n07-tervis.md` on ennustused (A1, A7, A8) ja iga järel lause selle kohta, mis päriselt juhtus
- [ ] tervisetabelis on 15 täidetud lahtrit ja `logid/tervis.txt` on olemas
- [ ] oskad `top`-is näidata, kus on koormus, `id` ja `avail Mem`
- [ ] vähemalt kaks müsteeriumi on lahendatud ja kirja pandud koos tõenditega

---

## 🚀 Lisaülesanded

Kergemad on eespool. Tee nii palju, kui jõuad.

**1. Mälusööjad.** Leia `proxmox1`-s viis protsessi, mis kasutavad kõige rohkem mälu, ilma `top`-ita.

??? success "Lahendus"
    ```bash
    ps aux --sort=-%mem | head -6
    ```
    `--sort=-%mem` sorteerib mälu järgi kahanevalt, `head -6` näitab päist ja viit rida.

**2. Kas ketas võib olla täis, kui `df -h` näitab vaba ruumi?** Käivita `df -i /`. Mis on inode ja millal see otsa saab?

??? success "Lahendus"
    Inode on failisüsteemi "kaart" iga faili kohta. Igal failil on üks inode, ükskõik kui väike fail on. Kui keegi loob miljoneid pisikesi faile (näiteks vigane programm, mis kirjutab igale päringule eraldi faili), saavad inode'id otsa enne baite. Siis näitab `df -h` vaba ruumi, aga uut faili luua ei saa (`No space left on device`). `df -i` veerg `IUse%` näitab inode'ide täituvust.

**3. vmstat.** Käivita `vmstat 2 10` (10 mõõtmist iga 2 sekundi järel) ja samal ajal teises terminalis `stress-ng --cpu 1 --timeout 20s`. Millised veerud muutuvad? Leia `man vmstat`-ist, mida tähendavad `r`, `us` ja `id`.

**4. Ketta ootamine.** Käivita `top` ja teises terminalis `stress-ng --hdd 1 --timeout 60s`. Vaata `%Cpu(s)` rea väärtust `wa`. Miks kasvab koormus (load average), kuigi `us` jääb väikeseks? (Loe loengu osa "Taust ja edasijõudnutele".)

**5. Ansible kogub kõik.** Tee B1 tervisetabel ühe Ansible ad-hoc käsuga ilma `for`-tsüklita, nii et kõik kolm sõlme vastavad paralleelselt.

??? success "Lahendus"
    ```bash
    ansible all -i proxmox1,proxmox2,proxmox3, -m ansible.builtin.shell \
      -a "nproc; cat /proc/loadavg; free -h | grep Mem; df -h / | tail -1"
    ```
    `shell` moodul on vajalik, sest käsus on toru (`|`). `command` moodul toru ei mõista. Ansible käivitab kõik kolm korraga, seepärast tulevad vastused suvalises järjekorras.

**6. Protsessori kasutus `/proc/stat`-ist.** `top` arvutab protsessori protsendi ise. Loe kaks korda (1 sekundilise vahega) faili `/proc/stat` esimest rida ja arvuta, mitu protsenti ajast protsessor tööd tegi. Kirjuta selleks väike bash-skript.

??? success "Lahendus"
    `/proc/stat` esimene rida sisaldab protsessori aega alates käivitusest (ühikutes, mida nimetatakse jiffy). Neljas number on `idle`. Protsent = 100 × (kogu muutus − idle muutus) / kogu muutus.
    ```bash
    #!/bin/bash
    read -r _ a b c idle1 rest < /proc/stat
    kokku1=$((a + b + c + idle1))
    sleep 1
    read -r _ a b c idle2 rest < /proc/stat
    kokku2=$((a + b + c + idle2))
    echo "CPU: $(( 100 * ((kokku2 - kokku1) - (idle2 - idle1)) / (kokku2 - kokku1) ))%"
    ```
    See on lihtsustus: arvesse on võetud ainult neli esimest välja (`user`, `nice`, `system`, `idle`). Täpsem arvutus liidab kõik väljad. Käivita skripti ajal `stress-ng --cpu 1` ja võrdle `top`-iga.

**7. Piira protsessi.** Käivita `stress-ng` nii, et see saab kasutada maksimaalselt pool ühest tuumast, ükskõik kui palju ta tahab. Tõesta `top`-iga. Vihje: `systemd-run` ja `CPUQuota`.

??? success "Lahendus"
    ```bash
    sudo systemd-run --scope -p CPUQuota=50% stress-ng --cpu 1 --timeout 60s
    ```
    `top` näitab `stress-ng-cpu` juures umbes 50%. Seda piirangut teeb tuuma võimalus cgroups, sama, mis hoiab Dockeri konteinereid üksteist segamast.

**8. Müsteeriumi neljas probleem.** Lisa skripti `mysteerium.sh` neljas valik, mis tekitab ketta ootamise (`stress-ng --hdd`). Lase paarilisel see oma sõlmes lahendada. Millise numbri järgi ta selle leidis?

**9. Päris raske: kes kirjutab ketast?** Ilma lisatööriistu paigaldamata (`iotop` jms) leia protsess, mis kirjutab praegu kõige rohkem kettale. Vihje: igal protsessil on `/proc/<PID>/io`. Kirjuta skript, mis loeb kõigi protsesside `write_bytes` kaks korda ja näitab, kelle number kasvas kõige rohkem.

---

## Veaotsing

| Probleem | Põhjus | Lahendus |
|---|---|---|
| `ssh: Could not resolve hostname proxmox2` | `~/.ssh/config` puudub või on teises arvutis | automatiseerimise nädal 1, osa 3: `Host proxmox2` plokk |
| `Permission denied (publickey)` | võti pole agendis või vale võti | `ssh-add ~/.ssh/kursus_ed25519` |
| Ansible: `Could not match supplied host pattern` | lõpu koma puudub `-i` järel | `-i proxmox1,proxmox2,proxmox3,` |
| `No package stress-ng available` | EPEL puudub | Eeltöö, EPEL samm |
| `stress-ng: command not found` | paigaldus ebaõnnestus selles sõlmes | korda Ansible käsku, vaata selle sõlme väljundit |
| SSH-ühendus katkes mälutesti ajal | mälu sai otsa, tuum sulges protsesse | ühendu uuesti, kasuta väiksemat `--vm-bytes` |
| Müsteerium ei näita midagi | 5 minutit on läbi | käivita `bash mysteerium.sh` uuesti |
| Ketas on pärast müsteeriumi endiselt täis | sulgesid sõlme enne 5 minuti möödumist | `rm -f ~/.peidus` |
