# Puuduvad ekraanipildid

Kõik siin loetletud failid on praegu hallid kohatäitjad (800×300). Tee ekraanipilt oma sõlmest ja kirjuta sama nimega fail üle. Soovitus: PNG, kuni ~150 kB, terminali font suur, tume või hele teema läbivalt sama.

| Fail | Kus kasutatakse | Mida näidata | Millal pildistada |
|---|---|---|---|
| `n07_top_pais.png` | `week07/lab.md`, A6 | `top` päis (5 rida) + paar protsessi, rahulik masin, `id` > 95% | `ssh proxmox2`, `top` kohe pärast käivitust |
| `n07_top_stress.png` | `week07/lab.md`, A7 | `stress-ng-cpu` protsessid nimekirja tipus, `id` ~0, koormus tõuseb | ~60 s pärast `stress-ng --cpu $(nproc) --timeout 90s` |
