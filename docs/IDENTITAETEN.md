# Identitaeten der DROMEs und Waffen -- Bestandsaufnahme

Stand 8. Nov. 2026. Grundlage fuer das Gespraech mit dem Spieler, BEVOR Level
fuer DROMEs und Waffen gebaut werden (Wunsch des Spielers: erst Identitaet
und Werte klaeren, daraus folgt, was ein Levelaufstieg bringt). Zahlen aus
`parts/` und `DromeBuild.stats()` der Standardausstattung.

## 1. Die vier DROMEs heute

| | Vireo | Molok | Nimbus | Strix |
|---|---|---|---|---|
| Rolle (KI) | Plaenkler | Vorhut / Tank | Kontrolle | Scharfschuetze |
| Integritaet | 60 | 200 | 85 | 70 |
| Schild | 30 | 10 | 50 | 30 |
| Panzerung (DEF) | 1 | 14 (mit Deflektor) | 2 | 2 |
| SPD (Tempo) | 14 (1,88 Felder/s) | 6 (1,20) | 13 (1,79) | 8 (1,37) |
| ATK | 0 | 0 | 0 | 4 (Kopf) |
| Passive | Sprint: Treffer -> 2 s +40 % Tempo | Praesenz: lockt im Umkreis 2, faengt 30 % Schaden von Nachbarn ab | Echo: Faehigkeiten wirken doppelt, Takt +50 % | **keine** |
| Waffenhalter | 1 (bis mittel) | 2 (schwer + Schild/Support) | 1 (bis mittel) | 1 (bis schwer) |
| Standardwaffe | Puls-Blaster | Hammer + Deflektor | Runenstab | Schienen-Lanze |
| Kampfwert | 130 | 362 | 168 | 186 |

## 2. Die Waffen heute (roher Schaden ohne Panzerung)

| Waffe | Klasse | Angriff | Rw | Faehigkeit (Takt) | grob Schaden/s |
|---|---|---|---|---|---|
| Puls-Blaster | leicht | 10 alle 1,4 s, halb Energie | 3 | Doppelschuss 2x7 (jeder 3.) | ~10 |
| Neon-Blaster | leicht | 10 alle 1,4 s, halb Energie | 3 | Schildbrecher 12, doppelt gegen Schild (jeder 3.) | ~10, viel gegen Schild |
| Plasmaklinge | leicht | 12 alle 1,0 s | 1 | Aufschlitzen 18 + verwundbar 5 s (jeder 3.) | ~18 |
| Runenstab | leicht | 9 alle 1,2 s, Energie | 3 | Vortex 14 Flaeche r2 + Sog + verlangsamt (alle 3 s) | ~14 mit Echo, Flaeche |
| Hammer | schwer | 16 alle 1,8 s | 1 | Betaeubungsschlag 16 + 1 s betaeubt (jeder 3.) | ~12 |
| Schienen-Lanze | schwer | 22 alle 2,6 s | 8 | Praezisionsschuss 26 (jeder 4.) | ~10 (+ ATK 4 -> ~13) |
| Deflektor-Schild | mittel | 6 alle 1,5 s | 1 | Schildladung +15 Schild (jeder 4.), +5 DEF | ~4 |
| Drohnen-Pod | leicht | 4 Schaden / 6 Heilung alle 1,5 s | 3 | Schutzdrohne +15 Schild an Verbuendeten (jeder 4.) | ~3 + Heilung |
| Orbit-Fokus | leicht | -- | 4 | Orbit-Sog: zieht 2 Felder (alle 6 s) | 0 |
| Hologramm-Boost | leicht | -- | 3 | Sprung weg, wenn Gegner daneben (alle 4 s) | 0 |
| Koedersender | leicht | -- | -- | lockt im Umkreis 2 | 0 |

## 3. Was auffaellt

1. **Der Strix hat keine Passive** und keine eigene Idee ausser Reichweite.
   Seine ATK 4 kommt nur aus dem Kopf -- ATK hat sonst niemand.
2. **Vireo und Strix sind sich in den Werten aehnlich** (60-70 / 30 Schild),
   unterscheiden sich nur ueber Tempo und Waffe.
3. **Der Nimbus macht den meisten Schaden** und hat dazu den groessten Schild
   -- er ist Kontrolle UND Schadensquelle.
4. **Drei Teile sind keine Waffen**: Orbit-Fokus, Hologramm-Boost,
   Koedersender. Laut 6g sollten sie Module werden (der Koedersender ist es
   als Modul schon zusaetzlich).
5. **Waffen gehoeren zu niemandem**: jede leichte Waffe passt in jeden Halter.
   Die Identitaet steckt bisher im Chassis, nicht in der Waffe.
6. **Werte-Satz**: Integritaet, Schild, Panzerung, Tempo und ATK -- ATK ist
   fast tot (nur Strix-Kopf). 6b schlug eine "Leistung" (LST) fuer
   Faehigkeitsschaden vor, nie entschieden.

## 4. Fragen zur Klaerung (mit Vorschlag)

**A. Ein Satz Identitaet je DROME** (daraus folgt das Level):

| DROME | Vorschlag Identitaet | Level koennte bringen |
|---|---|---|
| Vireo | schnell, trifft oft, lebt vom Bewegen | Tempo / Sprint laenger |
| Molok | haelt aus und schuetzt andere | Integritaet / mehr abfangen |
| Nimbus | Faehigkeiten, Flaeche, Kontrolle | Faehigkeitsschaden / Takt |
| Strix | wenige, sehr harte Treffer aus der Ferne | Schaden je Treffer / Reichweite |

**B. Passive fuer den Strix**, Vorschlag: "Zielerfassung" -- jeder Treffer
auf dasselbe Ziel macht den naechsten haerter (z. B. +15 % je Treffer, bis
3x), Zielwechsel setzt zurueck. Passt zur Regel "Ziel halten".

**C. Werte-Satz verschlanken**: ATK streichen (der Strix-Kopf gibt dann ueber
die Passive seine Haerte) oder als "Schaden %" je DROME fuehren?

**D. Waffen und Identitaet**: bleiben Waffen frei fuer alle (Halter regelt
nur die Klasse), oder bekommt jede Waffe einen "Heimat-DROME" mit Bonus?

**E. Die drei Nicht-Waffen** (Orbit-Fokus, Hologramm-Boost, Koedersender):
zu Modulen machen und als Ausruestung streichen?

**F. Waffen-Level allgemein**: steigt die Waffe in ihrem Kernwert (Schaden
oder Tempo), oder in ihrer Faehigkeit (Takt kuerzer, Wirkung staerker)?
