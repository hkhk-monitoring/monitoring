<div class="hero-section" markdown>
<div class="hero-content" markdown>
# Süsteemide monitooring

Server ei oska kurta. Ta kirjutab logi, näitab numbreid ja jätab jälgi. Sellel kursusel õpid neid lugema, ühte kohta koguma, pildiks tegema ja nende peale reageerima, et saaksid probleemist teada enne kasutajat.

[Alusta kursusega](week01/lecture.md){ .btn-primary }
[Kursuse ülesehitus](syllabus.md){ .btn-secondary }
</div>
</div>

## Mida sa õpid

1. Koguda kõigi masinate logid ühte kohta, et need säiliksid ka siis, kui masin kaob
2. Jälgida kõiki masinaid ühest kohast ja saada teada, kui midagi läheb valesti
3. Küsida andmetelt küsimusi ja teha neist töölaud, millest on kasu
4. Otsida logidest nii sildi kui ka iga sõna järgi ja teada, mida kumbki maksab
5. Leida ühe päringu teekond läbi mitme teenuse
6. Uurida turvaintsidenti ja kirjutada sellest raport

---

## Programm

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

Tunnid, tööriistad ja hindamine: [Kursuse ülesehitus](syllabus.md).

---

## Enne esimest tundi

Sul on kõik juba olemas automatiseerimise kursusest:

- `ssh proxmox1`, `ssh proxmox2`, `ssh proxmox3` töötavad ilma paroolita;
- Ansible ja VS Code on sinu arvutis.

Kui midagi neist ei tööta, vaata [Töökeskkond](kodulabor.md).
