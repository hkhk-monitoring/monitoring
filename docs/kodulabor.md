---
tags:
  - Info
  - Monitooring
---

# Töökeskkond ja eelkontroll

Kursusel kasutad automatiseerimise kursusest tuttavaid laborimasinaid `proxmox1`, `proxmox2` ja `proxmox3`. Enne esimest praktikumi kontrolli, et pääsed neisse SSH-ga ja saad käivitada Ansible'i ülesandeid. Selle lehe abil kontrollid olemasoleva keskkonna valmisolekut. Monitooringuteenused paigaldad vastavates praktikumides.

## 1. Masinad ja nende rollid

`proxmox1`, `proxmox2` ja `proxmox3` on kooli Proxmoxis töötavad AlmaLinux 9 virtuaalmasinad.

| Töökoht | Roll |
|---|---|
| Sinu arvuti | VS Code, terminal, Ansible, Git ja brauser |
| `proxmox1` | keskne logiserver ja praktikumides kasutatavad monitooringusüsteemid |
| `proxmox2` | jälgitav laborimasin |
| `proxmox3` | jälgitav laborimasin |

Ansible'i ja Giti käivitad oma arvutis, samas käsukeskkonnas, mille seadistasid automatiseerimise kursusel. SSH-ga käivitad käske laborimasinas. Veebiliideseid avad oma arvuti brauseris. Masinanimed `proxmox1`–`proxmox3` peavad olema kirjeldatud failis `~/.ssh/config`.

Kui varasem keskkond puudub, järgi automatiseerimise kursuse [1. nädala praktikumi](https://hkhk-automation.github.io/devops/week01/lab/).

## 2. Ühenda kooli võrku

Koolis on laborimasinad otse kättesaadavad. Kodust töötades ühenda enne kontrollimist kooli VPN. Kasuta automatiseerimise kursusel saadud VPN-i seadistust. Kui VPN-ühendus ei õnnestu, lahenda see enne SSH ja Ansible'i kontrolli.

## 3. Kontrolli SSH-ühendusi

Käivita oma arvuti terminalis:

```bash
for h in proxmox1 proxmox2 proxmox3; do
  echo "== $h"
  ssh "$h" hostname
done
```

??? success "Oodatav tulemus"
    Iga masina tähise järel on selle hostinimi. Konto parooli ei küsita, sest ühendus kasutab SSH-võtit. Kui privaatvõti on kaitstud paroolifraasiga, võib SSH küsida võtme paroolifraasi.

??? warning "Kui mõni ühendus ei õnnestu"
    1. Kodust töötades kontrolli VPN-ühendust.
    2. Kontrolli vastava masina kirjet failis `~/.ssh/config`: aadress, kasutajanimi ja SSH-võti.
    3. Vajadusel järgi automatiseerimise kursuse [1. nädala praktikumi](https://hkhk-automation.github.io/devops/week01/lab/).

    Ära jätka, enne kui kõik kolm ühendust töötavad.

## 4. Kontrolli Ansible'i ligipääsu

Käivita oma arvutis samas käsukeskkonnas:

```bash
ansible all -i proxmox1,proxmox2,proxmox3, -m ping
```

Koma masinaloendi lõpus näitab Ansible'ile, et `-i` järel on masinate loend, mitte inventarifaili nimi. Moodul `ping` ei ole võrgu ICMP-ping: see kontrollib, kas Ansible saab masinaga ühenduda ja seal mooduli käivitada.

??? success "Oodatav tulemus"
    Kõigi kolme masina kohta on olek `SUCCESS` ja vastuses `"ping": "pong"`.

??? warning "Kui kontroll ebaõnnestub"
    Loe konkreetse masina veateadet. SSH-ühenduse töötamine ei tõenda veel, et kõik Ansible'i eeldused on täidetud, näiteks võib sihtmasinas puududa Python.

## 5. Millal oled valmis?

Oled valmis, kui SSH ja Ansible'i kontroll õnnestuvad kõigi kolme masina puhul. Monitooringuteenused ei pea selles etapis töötama: iga praktikum nimetab oma eeltingimused.

??? note "Kontrollnimekiri"
    - [ ] Kodust töötades on VPN ühendatud.
    - [ ] SSH-ühendus töötab masinatega `proxmox1`, `proxmox2` ja `proxmox3`.
    - [ ] Ansible'i kontroll lõpeb kõigi kolme masina puhul olekuga `SUCCESS`.
    - [ ] Tead, millises käsukeskkonnas käivitad Ansible'i ja Giti.

## 6. Veebiliidesed ja ühendused

Praktikum ütleb, millises masinas teenus töötab, millisel aadressil sellele ligi pääsed ja milliseid ühendusi see vajab. Veebiliidese avad oma arvuti brauseris aadressil `http://<proxmox1-IP>:<port>`, port on praktikumi juhendis.

Kõik pordid ei ole veebiliideste jaoks: agentide ja serverite vahelisi ühendusi kontrollid praktikumi juhendi järgi. Ära ava kõiki kursusel kasutatavaid porte ette, muuda tulemüüri ainult ülesande nõuete järgi.

## 7. Teenuste peatamine ja taaskäivitamine

`proxmox1` ressursid on piiratud. Iga praktikumi alguses on kirjas, millised varasemad teenused peavad töötama ja millised peatada. Ära peata teenust, mida järgmine ülesanne vajab.

Enne uue seirekomplekti käivitamist kontrolli saadaval olevat mälu:

```bash
ssh proxmox1 "free -h"
```

Vaata veergu `available` ja võrdle seda praktikumi eeltingimusega. Kui mälu ei jätku ja pole selge, mida võib peatada, küsi õpetajalt enne järgmise komplekti käivitamist.

Compose'i projekti peatamiseks ühendu `proxmox1`-sse ja liigu projekti kausta, näiteks Zabbixi puhul `~/zabbix`. Kontrolli enne peatamist, et väljundis on õige projekti teenused:

```bash
ssh proxmox1
cd ~/zabbix
docker compose ps
docker compose stop
docker compose ps -a
```

`stop` peatab konteinerid neid eemaldamata. Olemasolevad konteinerid käivitad uuesti sama kausta käsuga `docker compose start` ([docker compose stop](https://docs.docker.com/reference/cli/docker/compose/stop/)). Pärast käivitamist kontrolli teenuse valmisolekut praktikumi juhendi järgi: konteineri olek `Up` ei tähenda veel, et rakendus on kasutamiseks valmis. Lõpuks naase oma arvuti terminali käsuga `exit`.

!!! warning "Peatamine ei ole eemaldamine"
    Ära asenda `docker compose stop` käsuga `docker compose down -v`. See eemaldab konteinerid ja projekti andmeköited, näiteks Zabbixi andmebaasi koos kõigi hostidega. Eemaldamise sammud on kirjas vastavas praktikumis.
