---
tags:
  - Kodutöö
  - Monitooring
  - Zabbix
---

# Kodutöö: sama teade Zabbixist

Praktikumis saatis Alertmanager teate Discordi kanalisse `#it-24`. Webhook ei sõltu Prometheusest: sama aadressi kaudu saab teateid saata iga tööriist. Kodutöös seadistad N4 Zabbixi nii, et kettaruumi probleem jõuab samasse kanalisse, ja võrdled kahte teed. Kodutöö on boonus.

Eeldus on N4 praktikum: Zabbix töötab `proxmox1`-s kaustas `~/zabbix` ja `proxmox2`-l on kettaruumi trigger. Tähtaja näed Classroom 50-s.

## Osa 1 · Zabbix uuesti tööle

N5-s peatasid Zabbixi mälu säästmiseks. Käivita see ja kontrolli mälu:

```bash
ssh proxmox1 "cd ~/zabbix && docker compose start && free -h"
```

Kui veerus `available` on alla 300 MB, peata enne Grafana: `ssh proxmox1 "cd ~/prometheus && docker compose stop grafana"`.

## Osa 2 · Meediatüüp ja kasutaja

Zabbix saadab teateid **meediatüübi** (media type) kaudu. Zabbix 7.0-s on Discordi meediatüüp valmis ([Discord integratsioon](https://www.zabbix.com/integrations/discord)). See saadab teate webhookile, mille aadress on kasutaja meedia väljal **Send to**.

1. **Alerts → Media types**: kontrolli, et **Discord** on olemas ja olekus **Enabled**.
2. **Users → Users → Admin → Media → Add**: tüüp **Discord**, väljal **Send to** webhooki aadress failist `~/prometheus/saladus/discord_url`. Vajuta **Add** ja **Update**.
3. Meediatüübi lehel vajuta **Test**, et kontrollida, kas teade jõuab kanalisse.

??? warning "Kui Discordi meediatüüpi pole"
    Impordi see failist `media_discord.yaml` Zabbixi repositooriumist: **Alerts → Media types → Import**.

## Osa 3 · Tegevus

**Tegevus** (action) ütleb, millise sündmuse korral ja kellele Zabbix teate saadab ([Actions](https://www.zabbix.com/documentation/7.0/en/manual/config/notifications/action)).

**Alerts → Actions → Trigger actions → Create action**:

- nimi `Discord`;
- tingimus: **Trigger severity** on vähemalt **Warning**;
- vahekaardil **Operations**: saada kasutajale **Admin** meediatüübiga **Discord**, lisaks **Recovery operations** sama sihtkohaga.

Tekita N4 kettaruumi probleem uuesti nagu N4 osas 4 ja kustuta fail pärast teadet. Kanalisse peab tulema kaks Zabbixi teadet: probleem ja lahenemine.

## Osa 4 · Vastused

Vasta failis `BOONUS.md` jaotises **Zabbix**:

1. Kus on Zabbixis teate tekst kirjas ja kus Alertmanageris?
2. Kus on Zabbixi seadistus: failis või andmebaasis? Mida see tähendab, kui Zabbixi konteiner luuakse uuesti?
3. Kumb tööriist grupeerib sama probleemi mitmest masinast üheks teateks?
