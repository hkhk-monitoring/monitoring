---
tags:
  - Loeng
  - Monitooring
  - Linux
  - Algaja
---

# Loeng: mõõdik, aegrida, agent

N2-s seadistasid Zabbixi, mis pingib masinaid ja annab teada, kui mõni ei vasta. Täna vaatad, mida masina sees mõõdetakse, kust need numbrid tulevad ja miks on nende kogumiseks vaja agenti.

??? abstract "Õpiväljundid"
    Pärast loengut ja praktikumi oskad:

    - eristada mõõdikut (number ajas) ja sündmust (kirje sellest, mis juhtus);
    - selgitada, mis on aegrida ja proovivõtu intervall;
    - eristada gauge'i ja counterit ning tuua mõlemast näite;
    - kasutada USE-meetodit uurimisküsimuste koostamiseks ja nimetada mõõtmiste piirid;
    - selgitada nelja kuldset signaali ning SLI, SLO ja SLA erinevust;
    - tõlgendada koormust (load average) tuumade arvu järgi ja mälu veeru `available` järgi;
    - selgitada, miks Zabbix näeb N2 seadistusega ainult seda, kas masin vastab, ja miks on vaja agenti.

## 1. Zabbix ütles „kõik korras“

N2 lõpuks pingis Zabbix iga minut `proxmox2` ja `proxmox3`. Kui masin ei vastanud, tekkis probleem ja pärast parandust lahenes see ise. See on juba monitooring, aga see vastab ainult ühele küsimusele: **kas masin on võrgus, jah või ei.**

Ping ei näita masina sisemist olekut. Näiteks võib e-poe server vastata pingile, kuigi leht laeb 15 sekundit, sest ketas on 100% täis: logifail kasvas terve nädala. Kolmapäeval oli ketas 85% täis ja täitus 5% päevas. Kui ketast oleks mõõdetud, oleks hoiatus tulnud kaks päeva enne, kui klient poe aeglusest teatas.

<figure markdown="span">
```mermaid
%%{init: {'theme':'base','themeVariables':{'primaryColor':'#e0f2f1','primaryBorderColor':'#00796b','primaryTextColor':'#212121','lineColor':'#26a69a'}}}%%
graph LR
    A["Kolmapäev<br/>ketas 85%"] --> B["Reede 21:00<br/>ketas 100%<br/>pood aeglane"]
    B --> C["Reede 23:00<br/>klient kurdab"]
    C --> D["Esmaspäev<br/>administraator saab teada"]
    A -. "kettat mõõdetakse: hoiatus siin" .-> E["vanade logide<br/>kustutamine<br/>5 minutit"]
```
  <figcaption>Joonis 3.1. Sama probleem kahe teekonnaga. Ping oli kogu aeg korras, seega N2 seadistusega Zabbix ei oleks midagi teatanud. Ketta mõõtmine oleks andnud hoiatuse kaks päeva varem (Talvik, 2026).</figcaption>
</figure>

Rike tuleks avastada enne kasutaja teadet. Selleks ei piisa sellest, et masin vastab. Mõõta tuleb ka masina sisu: protsessori koormust, mälu ja kettaruumi.

??? question "Kontrolli ennast"
    1. Miks ei näidanud Zabbix e-poe ketta täitumise ajal probleemi?
    2. Too oma elust üks näide, kus said probleemist teada liiga hilja, kuigi märgid olid varem olemas (telefoni aku, mäng, arvuti).

## 2. Mõõdik, sündmus ja aegrida

Mõtle telefoni akule. Ekraanil on **37%**. See on **mõõdik** (metric): üks mõõdetav suurus, millel on nimi ja väärtus. Mõõdikul on alati ka mõõtmise aeg.

Logirida on teist tüüpi andmed. `Oct 29 21:04:11 pood nginx: disk full` on **sündmus** (event): kirje sellest, mis ühel hetkel juhtus. Sündmust loed ja mõistad. Mõõdikut võrdled eelmise väärtusega.

??? note "Tabel 3.1. Sündmus ja mõõdik"
    | | Sündmus (N1) | Mõõdik (N2–N7) |
    |---|---|---|
    | Näide | `Failed password for root from 10.0.9.66` | `ketas_kasutusel = 85` |
    | Mis see on | tekst sellest, mis juhtus | number, mis näitab olekut |
    | Millal tekib | siis, kui midagi juhtub | iga kindla aja tagant, ka siis, kui midagi ei juhtu |
    | Kuidas loed | otsid, filtreerid, loed läbi | võrdled, joonistad graafiku |

Kas 37% akut on hea või halb? Sellest numbrist üksi ei saa aru. Kui hommikul oli 100% ja praegu on kell 10, on midagi valesti. Kui kell on 22, on kõik hästi.

Telefoni seadetes on aku graafik: sama number iga paari minuti järel terve päeva jooksul. Sellist numbrite rida koos ajatemplitega nimetatakse **aegreaks** (time series).

<figure markdown="span">
```text
aku %
100 |█
 80 |  █
 60 |    █ █
 40 |        █ █ █
 20 |              █
  0 +--------------------
     8  10  12  14  16  18  kell
```
  <figcaption>Joonis 3.2. Aegrida: sama mõõdik (aku laetus) mõõdetuna iga kahe tunni järel. Graafikult on näha, et kell 12–14 ei kulunud akut peaaegu üldse (Talvik, 2026).</figcaption>
</figure>

Mõõtmiste vahe on **proovivõtu intervall** (sampling interval). Zabbixi *ICMP Ping* template mõõdab iga 1 minuti järel. See tähendab, et 20-sekundilist katkestust ta tõenäoliselt ei näe: see jääb kahe mõõtmise vahele. Mida tihedam intervall, seda rohkem andmeid tuleb hoida. Masina mõõdikute jaoks on tavaline 15 kuni 60 sekundit.

??? question "Kontrolli ennast"
    1. Mis vahe on mõõdikul ja aegreal? Too näide autost.
    2. Kas `sshd: Accepted publickey for kasutaja` on mõõdik või sündmus? Aga `Mem available: 1.3 GiB`?
    3. Zabbix pingib iga minut. Server oli 30 sekundit maas. Kas Zabbix märkab seda kindlasti? Miks?

## 3. Gauge ja counter

Mõtle autole. Armatuurlaual on kaks numbrit, mis näevad sarnased välja:

- **Spidomeeter** näitab, kui kiiresti sõidad **praegu**: 50, siis 90, siis 0. Number käib üles ja alla.
- **Läbisõidumõõdik** näitab, mitu kilomeetrit auto on **kokku** sõitnud: 152 300, siis 152 301. Number ainult kasvab.

Mõõdikute maailmas on need kaks tüüpi:

??? note "Tabel 3.2. Gauge ja counter"
    | Tüüp | Mis teeb | Auto | Masinas |
    |---|---|---|---|
    | **Gauge** (näidik) | käib üles ja alla, näitab hetkeseisu | spidomeeter, kütusenäit | koormus, vaba mälu, ketta täituvus, temperatuur |
    | **Counter** (loendur) | ainult kasvab, loeb kokku alates algusest | läbisõidumõõdik | protsessori aeg, võrgukaardi baidid, päringute arv |

Gauge'i väärtust saad lugeda otse: „vaba mälu on 1,3 GiB“ on kohe arusaadav.

Counteri väärtus üksi ei ütle peaaegu midagi. Väärtus `bytes received: 8 412 663 210` on võrgukaardi kaudu saabunud baitide arv alates masina käivitusest. Huvitav on **kui kiiresti** number kasvab. Selleks loed counterit kaks korda ja arvutad vahe:

```text
kell 10:00:00   8 412 663 210 baiti
kell 10:00:10   8 425 163 210 baiti
vahe 10 sekundiga: 12 500 000 baiti → 1,25 MB sekundis
```

Seda arvutust nimetatakse **kiiruseks** (rate). Täpselt nii töötab ka `top`: protsessori protsendi arvutab ta, lugedes protsessori aja counterit kaks korda ja võrreldes vahet. Praktikumis teed seda ise.

Counteril on üks lõks: kui masin taaskäivitub, algab loendur nullist. Hea monitooringusüsteem tunneb selle ära ega joonista graafikule tohutut negatiivset hüpet.

On ka kolmas tüüp, **histogramm** (histogram), mis jagab mõõtmised korvidesse, näiteks „mitu päringut vastas alla 100 ms, mitu alla 1 s“. Sellega kohtud N5-s Prometheuses.

??? question "Kontrolli ennast"
    1. Kumb on gauge ja kumb counter: ketta täituvus protsentides, sisse loginud kasutajate arv, kokku saadetud e-kirjade arv, protsessori temperatuur?
    2. Miks ei ole mõtet joonistada graafikut counteri toorväärtusest?
    3. Võrgukaardi counter näitas kell 12:00 väärtust 5 000 000 ja kell 12:01 väärtust 1 200. Mis juhtus?

## 4. Mida masinas mõõta: neli küsimust ja USE

Auto armatuurlaual on kümneid tulesid, aga juht vaatab kõigepealt mõnda: kiirus, kütus, mootori temperatuur ja kas mõni punane tuli põleb. Serveriga on sama. Alusta neljast küsimusest:

??? note "Tabel 3.3. Neli küsimust, mida igalt serverilt esimesena küsitakse"
    | Küsimus | Mida mõõdetakse | Käsk | Võrdlus autoga |
    |---|---|---|---|
    | Kas masin töötab? | tööaeg (uptime) | `uptime` | kas mootor käib |
    | Kas protsessor jõuab? | protsessori koormus | `uptime`, `top` | pöörded |
    | Kas mälu jätkub? | mälu (RAM) | `free -h` | kindalaegas: mis on käepärast |
    | Kas kettaruumi jätkub? | ketas | `df -h` | pagasiruum |

**Mälu** on kiire ja väike ning kaob, kui masin välja lülitada. Seal on asjad, millega praegu töötatakse. **Ketas** on aeglane ja suur ning jääb alles. Kui mälu saab täis, läheb masin aeglaseks. Kui ketas saab täis, lakkavad programmid töötamast, sest need ei saa enam midagi kirjutada (nagu e-poe näites).

Brendan Gregg sõnastas sama mõtte **USE-meetodina**. Iga ressursi kohta küsid kolme asja:

- **U**tilization (kasutus): kui suure osa ajast või mahust ressurss on hõivatud?
- **S**aturation (küllastus): kas tekib järjekord, kas keegi peab ootama?
- **E**rrors (vead): kas on vigu?

??? note "Tabel 3.4. USE-meetod kolme ressursi kohta"
    | Ressurss | Kasutus | Küllastus | Vead |
    |---|---|---|---|
    | Protsessor | `top`: `us` + `sy` (või 100 - `id`) | koormus suurem kui tuumade arv | harva, vaata `dmesg` |
    | Mälu | `free -h`: `used` võrreldes `total`-iga | `available` nulli lähedal, swap kasutusel | OOM killer logis (`journalctl -k`) |
    | Ketta maht | `df -h`: `Use%` | failisüsteem täis, programmid ei saa kirjutada | `No space left on device` logis |
    | Ketta sisend-väljund | `iostat -x`: `%util` | `iostat -x`: järjekord `aqu-sz`, ooteaeg `r_await`; `top`: `wa` | `I/O error` logis |

Pane tähele viimast veergu: vead leiad sageli **logidest**, mitte mõõdikutest. Siin saavad N1 ja N2 kokku. Lähemalt loe [Greggi lehelt](https://www.brendangregg.com/usemethod.html).

??? question "Kontrolli ennast"
    1. E-pood jäi seisma täis ketta tõttu. Kas see oli kasutuse, küllastuse või vea probleem?
    2. Protsessor on 100% hõivatud, aga järjekorda pole. Kas see on halb? Mis siis, kui järjekorras ootab 6 protsessi?

## 5. Teenuse vaade: neli kuldset signaali, SLI, SLO ja SLA

USE vaatab masinat. Kasutaja masinat ei näe, ta näeb teenust: kas leht avaneb ja kui kiiresti. Google'i SRE raamat soovitab teenuse kohta mõõta [nelja kuldset signaali](https://sre.google/sre-book/monitoring-distributed-systems/#xref_monitoring_golden-signals) (golden signals).

??? note "Tabel 3.5. Neli kuldset signaali"
    | Signaal | Küsimus | E-poe näide |
    |---|---|---|
    | **Latentsus** (latency) | kui kaua vastus võtab | 95% päringutest vastab alla 300 ms |
    | **Liiklus** (traffic) | kui palju on nõudlust | 40 päringut sekundis |
    | **Vead** (errors) | kui suur osa päringutest ebaõnnestub | 0,3% päringutest annab vea 500 |
    | **Küllastus** (saturation) | kui täis teenus on | andmebaasi ühendustest on kasutusel 90% |

<figure markdown="span">
  ![Kasutaja saadab päringud e-poodi; teenuse kohta mõõdetakse latentsust, liiklust, vigu ja küllastust](../images/n03_kuldsed_signaalid.svg)
  <figcaption>Joonis 3.3. Neli kuldset signaali kirjeldavad teenust kasutaja vaatest. Väärtused on illustratiivsed (Talvik, 2026).</figcaption>
</figure>

Küllastus on sama mõte mis USE-s: kui ressurss saab täis, tekib järjekord ja latentsus kasvab. Masina mõõdikud näitavad põhjust, kuldsed signaalid näitavad, kas kasutaja seda tunneb. Latentsust ja vigu mõõdetakse päringute kohta, kursusel teed seda N11-s.

Kuldsetest signaalidest saab teenuse kvaliteedi mõõdupuu ([Measurement is critical](https://manishagarwal.hashnode.dev/measurement-is-critical)):

- **SLI** (service level indicator) on mõõdetud näitaja, näiteks õnnestunud päringute osakaal viimase 30 päeva jooksul.
- **SLO** (service level objective) on meeskonna eesmärk sellele näitajale, näiteks 99,5%.
- **SLA** (service level agreement) on leping kliendiga. Kui teenus jääb lubatud tasemest allapoole, maksab teenusepakkuja hüvitist.

SLA on tavaliselt madalam kui SLO, et meeskond märkaks probleemi enne lepingu rikkumist. SLO ja 100% vahe on **veaeelarve** (error budget). SLO 99,5% tähendab, et 30 päeva jooksul võib teenus olla häiritud umbes 3,6 tundi (30 × 24 h × 0,005). Kui veaeelarve on kulunud, tegeleb meeskond töökindlusega, mitte uute funktsioonidega.

<figure markdown="span">
  ![Skaala 98 kuni 100 protsenti: SLA 99,0 protsenti, SLO 99,5 protsenti, mõõdetud SLI 99,7 protsenti; SLO ja 100 protsendi vahe on veaeelarve](../images/n03_sli_slo_sla.svg)
  <figcaption>Joonis 3.4. SLI on mõõdetud, SLO on eesmärk, SLA on lubadus kliendile. Väärtused on illustratiivsed (Talvik, 2026).</figcaption>
</figure>

??? question "Kontrolli ennast"
    1. E-poe leht avaneb, aga vastus võtab 8 sekundit. Ping ja USE näitavad, et masinal on kõik korras. Milline kuldne signaal seda näitab ja kust selle mõõtmise saaksid?
    2. SLO on 99,9% 30 päeva kohta. Mitu minutit võib teenus selle aja jooksul olla häiritud?
    3. Miks ei panda SLA-sse sama numbrit kui SLO-sse?

## 6. Kust numbrid tulevad ja kes neid kogub

Masina kohta käivaid numbreid haldab Linuxis **tuum** (kernel): mitu protsessi ootab, kui palju mälu on kasutusel, kaua masin on üleval olnud. Tuum ei kirjuta neid numbreid kettale, vaid näitab neid kaustas **`/proc`**. See näeb välja nagu tavaline kaust failidega, kuid failide sisu koostab tuum lugemise hetkel.

<figure markdown="span">
```mermaid
%%{init: {'theme':'base','themeVariables':{'primaryColor':'#e0f2f1','primaryBorderColor':'#00796b','primaryTextColor':'#212121','lineColor':'#26a69a'}}}%%
graph LR
    K["Linuxi tuum"] --> P["/proc<br/>loadavg, meminfo,<br/>uptime, stat, net/dev"]
    P --> U["uptime, free, top"]
    U --> S["sina terminalis"]
    P -. "N4" .-> A["Zabbix agent"]
    P -. "N5" .-> N["node_exporter"]
```
  <figcaption>Joonis 3.5. Käsud `uptime`, `free` ja `top` ei mõõda midagi ise. Nad loevad tuuma numbreid kaustast `/proc`. Hiljem teevad sama Zabbix agent ja node_exporter (Talvik, 2026).</figcaption>
</figure>

??? note "Tabel 3.6. Olulisemad failid kaustas `/proc`"
    | Fail | Mis seal on | Tüüp | Mis käsk seda loeb |
    |---|---|---|---|
    | `/proc/uptime` | sekundid alates käivitusest | counter | `uptime` |
    | `/proc/loadavg` | koormus 1, 5 ja 15 minuti keskmisena | gauge | `uptime`, `top` |
    | `/proc/meminfo` | mälu, umbes 50 rida | gauge | `free`, `top` |
    | `/proc/stat` | protsessori aeg alates käivitusest | counter | `top` |
    | `/proc/net/dev` | võrgukaardi baidid ja paketid | counter | `ip -s link` |

Ketta kohta küsib `df` tuumalt otse iga failisüsteemi kohta eraldi. Põhimõte on sama: number tuleb tuumast.

Neid faile saab lugeda **ainult masina seest**. N2 Zabbix töötab `proxmox1`-s ja saadab `proxmox2`-le pingi. Ping näitab ainult, kas masin vastab ja kui kiiresti. Mälu ega ketast ta ei näe.

Mõõdikute kogumiseks on kaks võimalust:

??? note "Tabel 3.7. Agendiga ja agendita kogumine"
    | | Agendita (agentless) | Agendiga |
    |---|---|---|
    | Kuidas | server mõõdab väljast: ping, kas port on lahti, kas veebileht vastab | masinas töötab väike programm (agent), mis loeb `/proc`-i ja annab numbrid serverile |
    | Mida näeb | kas masin või teenus vastab, vastuse aeg | protsessor, mälu, ketas, protsessid, logid |
    | Eelis | masinasse pole vaja midagi paigaldada | näeb sisse |
    | Näide | N2 *ICMP Ping* | Zabbix agent (N4), node_exporter (N5) |

??? question "Kontrolli ennast"
    1. Miks näitab `cat /proc/uptime` iga kord erinevat numbrit, kuigi keegi faili ei muuda?
    2. Tahad teada, millal e-poe ketas täis saab. Kas N2 Zabbix suudab seda öelda? Mida on vaja juurde?
    3. Too üks olukord, kus agendita kontroll on parem kui agent.

## 7. Kuidas numbreid õigesti lugeda

### Koormus ja poe kassad

Käsk `uptime` näitab rea lõpus kolme numbrit:

```text
 10:14:02 up 3 days,  2:41,  1 user,  load average: 1.85, 0.92, 0.40
```

Need on **koormus** (load average): keskmiselt mitu protsessi tahtis viimase 1, 5 ja 15 minuti jooksul protsessorit kasutada (kas töötas või ootas järjekorras).

Mõtle poele. Kassad on protsessori **tuumad** (core). Ostjad on protsessid.

- 2 kassat, koormus 1: üks kassa töötab, teine ootab ostjat. Kõik on rahulik.
- 2 kassat, koormus 2: mõlemad kassad töötavad, järjekorda pole. Täis, aga hea.
- 2 kassat, koormus 6: mõlemad töötavad ja 4 inimest seisab järjekorras. Asjad venivad.

<figure markdown="span">
```mermaid
%%{init: {'theme':'base','themeVariables':{'primaryColor':'#e0f2f1','primaryBorderColor':'#00796b','primaryTextColor':'#212121','lineColor':'#26a69a'}}}%%
graph LR
    subgraph J["Järjekord (ootavad)"]
        P3((P3))
        P4((P4))
        P5((P5))
        P6((P6))
    end
    subgraph C["Protsessor: 2 tuuma"]
        T1["Tuum 1<br/>P1"]
        T2["Tuum 2<br/>P2"]
    end
    J --> C
```
  <figcaption>Joonis 3.6. Koormus 6 kahe tuumaga masinas: kaks protsessi töötavad, neli ootavad. Koormus jagatud tuumade arvuga on 3: masin on kolm korda üle koormatud. See on USE-meetodi küllastus (Talvik, 2026).</figcaption>
</figure>

**Koormus ilma tuumade arvuta ei tähenda midagi.** Tuumade arvu näitab käsk `nproc`. Rusikareegel: jaga koormus tuumade arvuga. Kuni 1 on korras, üle selle tekib järjekord.

Kolm numbrit koos näitavad suunda. `1.85, 0.92, 0.40` (viimane minut on kõrgeim) tähendab, et koormus **kasvab**. `0.40, 0.92, 1.85` tähendab, et koormus **langeb** ja hullem on möödas.

### Mälu: miks „vaba“ on väike

Käsk `free -h` näitab umbes nii:

```text
               total        used        free      shared  buff/cache   available
Mem:           3.8Gi       1.1Gi       210Mi        12Mi       2.5Gi       2.4Gi
```

Väike väärtus veerus `free` ei tähenda selles näites probleemi.

Linux ei lase mälul tühjalt seista. Kõik, mida programmid parasjagu ei kasuta, läheb **puhvrisse ja vahemällu** (buff/cache): seal hoitakse hiljuti loetud faile, et järgmine lugemine oleks kiire. Kui mõni programm vajab mälu, annab tuum selle vahemälust kohe ära.

Seepärast vaata veergu **`available`**: see on mälu, mille programm saaks kohe kasutada. Selles näites 2,4 GiB, mis on täiesti piisav. Kui `available` läheb nulli lähedale, alles siis on mure.

??? question "Kontrolli ennast"
    1. Kahel masinal on koormus 4. Ühel on 2 tuuma, teisel 8. Kumb on hädas ja miks?
    2. Mida tähendab `load average: 0.20, 1.50, 3.80`? Kas olukord läheb paremaks või halvemaks?
    3. Sõber saadab sulle `free -h` väljundi, kus `free` on 90 MiB ja `available` on 3 GiB. Mida talle vastad?

## 8. Number üksi ei ütle midagi

Sama number võib ühes masinas tähendada tavalist olekut ja teises riket. Varukoopiaserver pakib iga öö kell 02:00 failid kokku ja protsessor on tund aega 95% hõivatud. See on tavaline öö. Kui sama 95% on keskpäeval, kui varukoopiat ei tehta, on midagi valesti.

Masina tavaline olek on **baasjoon** (baseline). Ilma baasjooneta ei saa öelda, kas number on hea või halb. Baasjoone leiad ainult aegreast: pead nägema, millised on numbrid tavaliselt päeval, öösel ja nädalavahetusel.

Siin on käsitsi vaatamise piir. `top` näitab ainult **praegust hetke**. Kui avad selle kolmapäeval kell 10, ei tea sa midagi sellest, mis juhtus öösel kell 3. Sellepärast kogub monitooringusüsteem numbreid ise ja hoiab neid andmebaasis, nagu N2-s nägid.

Testides tekitatakse koormus meelega. Tööriist **`stress-ng`** paneb protsessori, mälu või ketta tööle nii kauaks, kui ütled. Nii näed, mis juhtub numbritega, kui masin hätta jääb, ja tead hiljem, mida otsida.

??? question "Kontrolli ennast"
    1. Miks ei ole varukoopiaserveri 95% protsessorikoormus öösel probleem?
    2. Miks ei piisa sellest, et vaatad serverit `top`-iga kord päevas?

??? info "Koormus ja ketas"
    Linuxi koormuse sees on ka protsessid, mis ootavad ketast. Seega võib koormus olla kõrge ka siis, kui protsessor on peaaegu tühi. Seda näed `top`-is real `%Cpu(s)` väärtusena `wa` (wait).

??? info "Push ja pull"
    Zabbix agent saab töötada kahel moel: server küsib (passiivne) või agent saadab ise (aktiivne). Prometheus (N5) küsib andmeid ise, Telegraf (N7) saadab need ise. Kumb on parem, sõltub võrgust: kas server pääseb masinani või ainult masin serverini.

??? abstract "Kokkuvõte"
    Monitooring mõõdab masinate olekut, et rike tuleks välja enne kasutaja teadet. Mõõdik on number ajas, sündmus on kirje sellest, mis juhtus. Gauge käib üles-alla, counter ainult kasvab ja sealt loed kiirust. Masina mõõdikud loetakse tuumast kausta `/proc` kaudu ja neid saab lugeda ainult masina seest, selleks on agent. Koormust loe tuumade arvu järgi, mälu puhul vaata `available` veergu. Üks number ütleb vähe, aegrida ja baasjoon ütlevad palju.

    | Mõiste | Selgitus | Kuidas näed |
    |---|---|---|
    | **Mõõdik (metric)** | number, millel on nimi ja mõõtmise aeg | `free -h` veerg `available` |
    | **Sündmus (event)** | kirje sellest, mis juhtus | logirida |
    | **Aegrida (time series)** | sama mõõdik mitu korda ajas | Zabbixi graafik |
    | **Intervall** | kui tihti mõõdetakse | ICMP Ping: 1 minut |
    | **Gauge** | käib üles ja alla, hetkeseis | `cat /proc/loadavg` |
    | **Counter** | ainult kasvab, loeb kokku | `cat /proc/net/dev` |
    | **USE** | kasutus, küllastus, vead iga ressursi kohta | Tabel 3.4 |
    | **Neli kuldset signaali** | latentsus, liiklus, vead, küllastus teenuse kohta | Tabel 3.5 |
    | **SLI, SLO, SLA** | mõõdetud näitaja, eesmärk, leping kliendiga | Joonis 3.4 |
    | **Koormus (load average)** | mitu protsessi tahab protsessorit, 1/5/15 min | `uptime` |
    | **Agent** | programm masinas, mis loeb `/proc`-i ja annab numbrid serverile | N4 |
    | **Baasjoon (baseline)** | masina tavaline olek | ainult aegreast |

??? question "Kontrolli ennast"
    1. Selgita oma sõnadega, miks N2 seadistusega Zabbix ei oleks e-poe täis ketast märganud.
    2. Too kaks gauge'i ja kaks counterit oma telefonist või arvutist.
    3. Selgita poe kassade abil, mida tähendab koormus 3.0 neljatuumalises masinas.
    4. Miks Linux kasutab peaaegu kogu „vaba“ mälu ära ja miks see ei ole viga?
    5. Kasutajad ütlevad: „Server on täna aeglane.“ Käi USE-meetod läbi protsessori, mälu ja ketta kohta ja ütle, millise käsuga igale küsimusele vastuse leiad.
    6. Miks on vaja agenti? Mida see näeb, mida ping ei näe?
