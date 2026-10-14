# Stiilijuhend

See fail kehtib kõigile selle repo materjalidele. Mehaanilisi reegleid kontrollib `scripts/lint.py` (CI kukub läbi, kui midagi on valesti). Ülejäänu on hinnangu küsimus ja seda vaadatakse üle PR-is.

Märge reegli juures: **[CI]** = kontrollib skript, **[PR]** = kontrollib inimene.

---

## 1. Keel ja hääl

- Kõik materjalid on eesti keeles. Ingliskeelne termin sulgudes esimesel kasutusel: *juurutus (deploy)*. **[PR]**
- Eesti keel peab kõlama loomulikult, mitte tõlkena. **[PR]**
- Lugeja on **sina**. Materjali autor ei räägi minavormis. **[PR]**
- Sammud on käskivas kõneviisis: „Sisesta", „Käivita", mitte „Nüüd võiks sisestada". **[PR]**
- Täiskasvanute kursustel ei seletata lahti tavalisi erialatermineid (deploy, rollback, control node). **[PR]**
- Mõttekriipsu (—) asemel kasuta sidekriipsu või lause ümber. **[CI, hoiatus]**
- Õigekiri: `scripts/spellcheck.py` (Vabamorf). Erialasõnad lisa faili `.sonastik.txt`. **[CI, hoiatus]**

### Keelatud mustrid **[CI]**

Täpne nimekiri on failis `stiil.yml` (`keelatud_fraasid`). Põhimõte:

- AI-vatt: „mitte X, vaid Y" konstruktsioonid, kolmikloetelud täiteks, iseendaga rahul olevad lõpulaused, sõnad nagu *demüstifitseeritud*, *mentaalne mudel*.
- „Valikuline. Ei mõjuta hindamist." ja sarnane boilerplate.
- „Kust alustada... kui aega on vähe" meta-proosa lisaülesannetes.

## 2. Mis materjali EI lähe **[CI]**

- Grupitähised ja kohordid (`IT-26`, `IS1-26`), kuupäevad, „Päev N". Kohtumised on „N. kohtumine".
- Õppijate nimed, nimekirjad, hostide loetelud.
- Pealkiri „Allikad" loengu lõpus. Viited käivad klikitava lingina täpselt sinna, kus neid vaja on.

## 3. Struktuur

### Loeng vs labor **[PR]**

| | Loeng | Labor |
|---|---|---|
| Eesmärk | Selgitab kuidas ja miks | Proovi ja kontrolli |
| Sisu | Eesmärk, põhimõisted, näited, küsimused, kokkuvõte | Eesmärk, tööriistad, sammud, tulemuse kontroll, kokkuvõte |
| Ei sisalda | Labori samme | Pikka teooriat (lingi loengule) |

*Tabel 1. Loengu ja labori erinevus*

### Kohustuslikud osad **[CI]**

Failitüübid ja nende kohustuslikud pealkirjad on määratud failis `stiil.yml` (`failitüübid`). Vaikimisi:

- **Loeng/teooria:** `!!! abstract` eesmärkidega, `## Kokkuvõte`, `## Enesekontroll` (`??? question`).
- **Praktikum/labor:** `!!! abstract "Eesmärgid"`, `## Kokkuvõte`.
- Igas failis täpselt üks `# H1`.

### Noorte kursuste stiil (kutseõpe) **[PR]**

- Iga sektsioon algab `!!! abstract "Miks see oluline on?"`.
- Narratiiv tegelastega (Kati, Mati), väljamõeldud lugu alati `!!! example "Näidisstsenaarium"` sees.
- `??? question "Kontrolli ennast"` iga sektsiooni lõpus, `🎯 Lõplik kontroll` faili lõpus.
- Kokkuvõttetabel „ühe pilguga" ja sild laborisse.

## 4. Frontmatter ja sildid **[CI]**

Iga `.md` fail algab nii:

```yaml
---
tags:
  - Linux
  - Loeng
---
```

- Sildid on **ainult** `stiil.yml` lubatud nimekirjast. Uue sildi lisamine = muudatus `stiil.yml`-is samas PR-is.
- Iga fail vajab vähemalt ühte **tüübi** silti (Loeng, Praktikum, Labor, Kodutöö, Lisaülesanne, Info) ja vähemalt ühte **teema** silti.

## 5. Joonised ja tabelid **[CI]**

```markdown
<figure markdown="span">
  ![Kirjeldav alt-tekst eesti keeles](../assets/t02_keerdpaar_utp.png)
  <figcaption>Joonis 2.1. Keerdpaarkaabel (Talvik, 2025). Loodud tehisintellekti abil.</figcaption>
</figure>
```

- Pilt ja Mermaid alati `<figure markdown="span">` sees, `figcaption` all.
- Alt-tekst on kohustuslik ja ei kordu pealkirjana.
- Numbrid `Joonis N.n.` ja `Tabel N.n.` on faili piires unikaalsed.
- Tabeli pealkiri on tabeli **all**, kaldkirjas: `*Tabel 2.1. Kirjeldus*`. Mitte blockquote.
- Pildifaili nimi: väiketähed, ASCII, alakriips, prefiks (`t##_`, `p##_`, `lab_`, `diag_`, `hero_`, `logo_`). Ilma `_v2`, `_final`.
- Viidatud pildifail peab olemas olema.
- AI-ga tehtud pildil lõpeb figcaption „Loodud tehisintellekti abil." või „Loodud <tööriist> abil." **[PR]**

## 6. Kood **[CI]**

- Igal koodiplokil on keel: `bash`, `yaml`, `python`, `text`, `mermaid`...
- Väikesed lõigud koos selgitusega, mitte pikad kopeeritavad skriptid. **[PR]**
- OpenTofu käsk on `tofu`, mitte `terraform`. **[CI]**

## 7. Viited **[CI]**

- Joonealuse märkuse ID on kirjeldav: `[^rfc791]`, mitte `[^1]`.
- Igal markeril on definitsioon ja igal definitsioonil marker.
- Praktikumides joonealuseid märkusi ei kasutata. **[PR]**

## 8. Navigatsioon **[CI, hoiatus]**

- Iga `docs/` all olev `.md` fail on `mkdocs.yml` `nav` all. Orvuks jäänud lehte keegi ei leia.

## 9. Konkursimaterjalid („Digitaalne kutseharidus“, E-koolikott)

Kutseõppe tasemekursused, mis lähevad konkursile, peavad lisaks täitma [hindamiskriteeriumid](https://hm.ee/sites/default/files/documents/2026-01/Lisa%202_%20Hindamiskriteeriumid_0.pdf) ja [oppevara.edu.ee soovitused](https://oppevara.edu.ee/kvaliteet). **[PR]**

- `kursuse_info.md`: autor, kool, sihtrühm, maht, õpiväljundid, üldpädevused, seos õppekavaga, kasutusjuhend, TI-kasutuse kirjeldus.
- Litsents CC BY-SA 4.0 `mkdocs.yml` `copyright` all.
- Enesekontroll annab **automaatse tagasiside** (test, H5P vms), mitte ainult kokkupandav vastus.
- Allikad ühtse standardi järgi (APA) ja loeteluna peatüki lõpus (joonealused). Erand §2 „Allikad“-reeglist kehtib ainult täiskasvanute kursustele.
- Mõistete sõnastik eraldi lehena.
- Mermaid-diagrammi järel 1-2 lauset, mis ütlevad sama tekstina (ekraanilugeja ei loe SVG-d).
- Pilt kuni ~150 kB (linter hoiatab üle 300 kB). Fotod JPG, joonised PNG/SVG.
- Video MP4, subtiitritega, kuni ~10 min.
- Testi arvutis, tahvlis ja telefonis, heledas ja tumedas režiimis.
- E-koolikotis metaandmed: autor, kool, eriala, võtmesõnad.

## 10. Versioonid

Kursus kordub igal aastal, seega materjalis aastat pole. Repo tag märgib läbiviimist: `kevad2026-1`, `sugis2026-1`. Number kasvab paranduste korral.

---

## Kasutamine kursuse repos

Kopeeri kursuse repo juurkausta (`mkdocs.yml` kõrvale): `STYLE.md`, `stiil.yml`, `.sonastik.txt`, `scripts/`, `.github/workflows/kvaliteet.yml`.

## Kontrollimine lokaalselt

```bash
pip install pyyaml
python scripts/lint.py                 # kõik docs/ failid
python scripts/lint.py docs/n03/loeng.md

pip install estnltk                    # Python 3.10-3.12
python scripts/spellcheck.py --uued    # tundmatud sõnad .sonastik.txt jaoks
```
