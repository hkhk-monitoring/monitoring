---
tags:
  - Monitooring
  - Linux
  - Praktikum
---

# Praktikum: masina näidud enne, ajal ja pärast koormust

N2 Zabbix kontrollib ainult seda, kas masin vastab pingile. Täna mõõdad `proxmox2` sees käsitsi protsessorit, mälu ja ketast ning võrdled näite enne koormust, koormuse ajal ja pärast seda. N4-s kogub samu numbreid Zabbixi agent.

**Edenemine:** laboritahvel <http://192.168.125.187:8092/> (VPN-iga).

??? abstract "Õpiväljundid"
    Pärast loengut ja praktikumi oskad:

    1. eristada mõõdikut, mõõteväärtust, aegrida ja sündmust;
    2. eristada gauge'i ja counterit ning arvutada kahe loendurilugemi põhjal keskmist muutumiskiirust;
    3. võrrelda masina näite enne piiratud koormuskatset, katse ajal ja pärast seda;
    4. selgitada mõõterea põhjal, kuidas proovivõtu intervall mõjutab lühikese muutuse märkamist;
    5. kasutada USE-meetodit uurimisküsimuste koostamiseks ja nimetada mõõtmiste piirid;
    6. põhjendada, miks ei piisa masina sisemise oleku hindamiseks pingist.

Rida **Ennusta** tähendab, et enne käsku mõtled läbi, mis juhtub. Ennustuse kirjutad README-sse enne käsu käivitamist.

## Osa 1 · Repositoorium ja stress-ng

Ava Classroom 50 link ([Praktikum 3 - Masina näidud](https://classroom50.org/hkhk-monitoring/it24-monitooring/assignments)) ja klooni oma repositoorium. Käivita käsud oma arvutis:

```bash
git clone <sinu-repo-URL>
cd <repo-kaust>
ls -R
```

??? success "Oodatav tulemus"
    ```text
    .:
    README.md  logid  tooriistad

    ./tooriistad:
    mootmine.sh
    ```

    README-sse kirjutad ennustused ja vastused, `logid/` on mõõtmiste jaoks. Skript `tooriistad/mootmine.sh` mõõdab masinat kolm minutit, iga viie sekundi järel ühe rea.

Koormuse tekitamiseks on vaja programmi `stress-ng`. See on EPEL-i hoidlas. Paigalda see ainult `proxmox2`-sse:

```bash
ssh proxmox2 "sudo dnf install -y epel-release && sudo dnf install -y stress-ng && stress-ng --version"
```

??? success "Oodatav tulemus"
    Viimane rida on näiteks `stress-ng, version 0.17.x`.

??? warning "Kui näed `No match for argument: stress-ng`"
    EPEL-i hoidla ei ole sees. Kontrolli `ssh proxmox2 "dnf repolist"`: nimekirjas peab olema `epel`.

## Osa 2 · Masina tavaolek

Enne koormust on vaja teada, millised on näidud tavaolekus. Muidu ei ole koormuse ajal millegagi võrrelda. Logi sisse `proxmox2`-sse ja käivita:

```bash
ssh proxmox2
nproc
uptime
top -bn1 | head -5
free -h
df -h /
```

??? success "Oodatav tulemus"
    `nproc` annab loogiliste protsessorite arvu, näiteks `2`. `uptime` lõpus on kolm koormuse keskmist (load average) viimase 1, 5 ja 15 minuti kohta. `top` real `%Cpu(s)` on `id` (idle) tavaolekus üle 90. `free -h` real `Mem:` on mitu veergu, nende hulgas `free` ja `available`. `df -h /` veerus `Use%` on juurfailisüsteemi täituvus.

Protsessori kasutus ja koormuse keskmine on erinevad näidud. Mida koormuse keskmine täpselt loeb, on kirjas dokumentatsioonis.

**Leia dokumentatsioonist:** ava [proc_loadavg(5)](https://man7.org/linux/man-pages/man5/proc_loadavg.5.html). Milliseid protsesse koormuse keskmine loeb? Kas kõrge koormus tähendab alati, et protsessorist jääb puudu?

??? success "Vastus"
    Koormuse keskmine loeb protsesse, mis töötavad või ootavad protsessorit (olek R), ja protsesse, mis ootavad ketast (olek D). Seepärast võib koormus olla kõrge ka siis, kui protsessor on peaaegu tühi ja masin ootab ketast.

**Leia dokumentatsioonist:** ava [free(1)](https://man7.org/linux/man-pages/man1/free.1.html). Mille poolest erineb veerg `available` veerust `free`? Kumba vaatad, kui tahad teada, kas uus programm mahub mällu?

??? success "Vastus"
    `free` on mälu, mida ei kasuta keegi. `available` on hinnang mälule, mille saab uus programm kätte ilma swap'ita, sest sinna kuulub ka vahemälu, mille tuum saab vabastada. Programmi mahtumise kohta vaata `available`.

Vali igast väljundist (`uptime`, `top`, `free`, `df`) üks näit. Kirjuta README tabelisse **Osa 2** selle nimi, väärtus, ühik ja küsimus, millele see näit vastab.

Välju masinast käsuga `exit`.

## Osa 3 · Ennusta koormuskatse tulemust

Järgmises osas käivitad `proxmox2`-s 60 sekundiks nii mitu protsessorit koormavat protsessi, kui masinas on protsessoreid. Enne katset kirjuta README jaotisse **Osa 3** vastused:

1. Milline näit muutub sinu arvates kõigepealt?
2. Kas protsessori kasutus ja 1 minuti koormuse keskmine muutuvad samas tempos?
3. Kas mälu `available` muutub?

## Osa 4 · Mõõda enne, ajal ja pärast

Skript mõõdab kolm minutit. Esimesed 30 sekundit on tavaolek, siis tuleb 60 sekundit koormust ja viimased 90 sekundit näitavad taastumist. Vaja on kahte terminali.

**Terminal 1** (oma arvutis, repositooriumi kaustas) alustab mõõtmist:

```bash
ssh proxmox2 'bash -s' < tooriistad/mootmine.sh | tee logid/n3-mootmine.txt
```

!!! warning "Koormuskatse ainult `proxmox2`-s"
    Käivita `stress-ng` ainult oma `proxmox2`-s. Katse lõpeb ise 60 sekundi pärast, varem saad selle peatada klahvidega **Ctrl+C**. Ära alusta katset, kui `uptime` näitab juba koormust üle protsessorite arvu: siis töötab masinas midagi muud ja tulemus ei ole võrreldav.

**Terminal 2:** oota, kuni terminalis 1 on kuus mõõterida (umbes 30 sekundit). Seejärel käivita koormus:

```bash
ssh proxmox2 'stress-ng --cpu $(nproc) --timeout 60s'
```

??? success "Oodatav tulemus"
    Terminal 1 lõpetab umbes kolme minuti pärast. Failis `logid/n3-mootmine.txt` on päis ja 36 rida:

    ```text
    aeg cpu_% load1 available_MiB
    10:02:11 2 0.08 1405
    ...
    10:02:47 100 0.62 1398
    ...
    10:04:52 1 1.31 1404
    ```

    Koormuse ajal on `cpu_%` 100 lähedal. `load1` tõuseb aeglaselt ja langeb aeglaselt, sest see on keskmine.

Skript võtab protsessori kasutuse käsu `vmstat` väljundist ja arvutab selle kujul 100 − `id`.

**Leia dokumentatsioonist:** ava [vmstat(8)](https://man7.org/linux/man-pages/man8/vmstat.8.html), jaotis **CPU**. Mida tähendab veerg `id` ja miks ei ole 100 − `id` sama mis veerg `us`?

??? success "Vastus"
    `id` on aeg, mil protsessor ei teinud midagi. 100 − `id` sisaldab kõike muud: kasutaja programme (`us`), tuuma (`sy`) ja ketta ootamist (`wa`). `us` on ainult kasutaja programmide aeg.

Täida README jaotises **Osa 4** tabel: vali failist üks rida enne koormust, üks koormuse ajal ja üks pärast. Seejärel vasta:

1. Milline näit kinnitab, et koormuskatse mõjutas masinat?
2. Milline näit ei muutunud nii, nagu ennustasid?
3. Kas nendest näitudest piisab, et väita, et masinas töötav rakendus muutus aeglaseks?
4. Millist lisamõõtmist selle väite jaoks vajaksid?

## Osa 5 · Mida hõre mõõtmine peidab

Skript mõõtis iga viie sekundi järel. Zabbixi ping-template mõõdab iga minuti järel. Vaata, mis jääb alles, kui mõõta harvem. Jäta failist alles iga kuues rida ehk mõõtmine iga 30 sekundi järel:

```bash
awk 'NR==1 || (NR-2)%6==0' logid/n3-mootmine.txt
```

**Ennusta:** kas koormuse algus ja lõpp on hõredas reas sama täpselt näha kui täielikus reas?

Kirjuta README jaotisse **Osa 5**, mis kell algas ja lõppes koormus täieliku rea järgi ja mis kell hõreda rea järgi. Kui pikk võib olla koormus, mis 30-sekundilise intervalliga üldse vahele jääb?

## Osa 6 · Gauge ja counter

`load1` ja `available_MiB` on **gauge**'id: need näitavad hetkeolekut ja käivad üles-alla. **Counter** ainult kasvab. Counteri väärtus üksi ei ütle palju, huvitav on, kui kiiresti see kasvab. Failis `/proc/stat` on üks counter real `ctxt`.

**Leia dokumentatsioonist:** ava [proc_stat(5)](https://man7.org/linux/man-pages/man5/proc_stat.5.html) ja otsi `ctxt`. Mida see arv loeb ja millest alates?

??? success "Vastus"
    Kontekstivahetuste arvu ehk seda, mitu korda on tuum protsessoril ühe töö teise vastu vahetanud. Arv loetakse alates masina käivitusest.

Loe counterit kaks korda kümnesekundilise vahega:

```bash
ssh proxmox2 'grep ctxt /proc/stat; sleep 10; grep ctxt /proc/stat' | tee logid/n3-loendur.txt
```

??? success "Oodatav tulemus"
    Kaks rida, näiteks `ctxt 48211763` ja `ctxt 48230115`. Teine arv on suurem.

Arvuta README jaotises **Osa 6** keskmine muutumiskiirus: (teine väärtus − esimene väärtus) / 10 sekundit. Tulemus on kontekstivahetusi sekundis. Liigita samas jaotises veel neli näitu gauge'iks või counteriks.

??? question "Kontrolli ennast"
    Masin taaskäivitati kahe lugemise vahel. Mis juhtub sinu arvutusega ja kuidas seda märgata?

## Osa 7 · USE-tabel

USE-meetodi järgi küsitakse iga ressursi kohta kolme asja: kasutus (utilization), küllastus (saturation) ja vead (errors). Need on kolm eri küsimust, mitte ühe näidu kolm nime.

Täida README jaotises **Osa 7** tabel protsessori, mälu ja ketta kohta. Kirjuta lahtrisse näit, mille sa mõõtsid, või „ei mõõtnud“. „Ei mõõtnud“ on parem vastus kui põhjendamata „korras“.

`df -h` näitab, kui palju failisüsteemi mahust on kasutusel. Ketta sisend-väljundtöö kohta see midagi ei ütle.

**Leia dokumentatsioonist:** ava [iostat(1)](https://man7.org/linux/man-pages/man1/iostat.1.html). Millised võtmega `-x` kuvatavad veerud näitavad, et kettale tekib järjekord ja päringud peavad ootama?

??? success "Vastus"
    `aqu-sz` on keskmine järjekorra pikkus, `r_await` ja `w_await` on lugemise ja kirjutamise keskmine aeg koos järjekorras ootamisega. `iostat` on paketis `sysstat`. Kui sa seda ei mõõtnud, kirjuta USE-tabelisse „ei mõõtnud“.

Lõpuks vasta README jaotises **Osa 7** viimasele küsimusele: milliseid kolme näitu peaks agent N4-s automaatselt koguma ja miks just neid?

## Töö esitamine

Repositooriumis on mõõtmised kaustas `logid/` ja README-s on vastused kõigis jaotistes.

```bash
git status
git add README.md logid
git commit -m "Praktikum 3: masina näidud"
git push
```

Tulemuse näed Classroom 50-s.

## Lisaülesanded

??? example "1 · Ketta ootamine"
    Käivita mõõtmisskript uuesti ja koormuse ajal `ssh proxmox2 'stress-ng --hdd 1 --timeout 60s'`. Vaata `top`-is real `%Cpu(s)` väärtust `wa`. Miks tõuseb `load1`, kuigi `cpu_%` jääb väikeseks?

??? example "2 · Pool protsessorit"
    Piira koormus poole protsessoriga: `ssh proxmox2 'sudo systemd-run --scope -p CPUQuota=50% stress-ng --cpu 1 --timeout 60s'`. Mõõda uuesti. Kuidas erineb `cpu_%` ja `load1` täiskoormusest?
