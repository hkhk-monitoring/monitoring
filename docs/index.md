<div class="hero-section" markdown>
<div class="hero-content" markdown>
# Süsteemide monitooring

Server ei oska kurta. Ta kirjutab logi, näitab numbreid ja jätab jälgi. Sellel kursusel õpid neid lugema, ühte kohta koguma, pildiks tegema ja nende peale reageerima, et saaksid probleemist teada enne kasutajat.

[Alusta kursusega](week01/lecture.md){ .btn-primary }
[Kursuse ülesehitus](syllabus.md){ .btn-secondary }
</div>
</div>

## Mida sa õpid

Kursuse lõpuks oskad:

1. koguda laborimasinate logid ühte kohta, et need säiliksid ka siis, kui masin kaob;
2. jälgida masinate olekut ühest kohast ja saada teavitus, kui midagi läheb valesti;
3. koostada kogutud andmete põhjal päringuid ja teha neist töölaua, mille järgi saab otsustada;
4. otsida logidest nii sildi kui ka iga sõna järgi ning võrrelda nende ressursikulu ja otsinguvõimalusi;
5. leida ühe päringu teekond läbi mitme teenuse;
6. uurida turvaintsidenti ja kirjutada sellest raport.

## Teemad nädalate kaupa

| Kohtumine | Mõisteplokk |
|---|---|
| N1 | Masina logid ja keskne logiserver |
| N2 | Keskne jälgimissüsteem |
| N3 | Mõõdik, aegrida, agent *(veebiõpe)* |
| N4 | Agent räägib serverile |
| N5 | Server küsib ise |
| N6 | Numbrid pildiks ja alarm |
| N7 | Aegrea andmebaas teisiti |
| N8 | Logid sildi järgi |
| N9 | Logid täisotsinguga |
| N10 | Päringu teekond |
| N11 | Kolm sammast koos ja kas üldse töötab |
| N12 | Turvamonitooring ja intsident |
| N13 | Lõputöö ja kaitsmine |

Tundide jaotus ja tööriistad on lehel [Kursuse ülesehitus](syllabus.md).

## Enne esimest tundi

Töökeskkond on sama, mis automatiseerimise kursusel. Enne esimest tundi kontrolli, et:

- `ssh proxmox1`, `ssh proxmox2` ja `ssh proxmox3` töötavad SSH-võtmega ega küsi parooli;
- arvutis on Ansible ja VS Code.

Kui mõni neist ei tööta, järgi lehte [Töökeskkond](kodulabor.md).
