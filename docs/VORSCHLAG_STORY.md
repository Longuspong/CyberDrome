# Vorschläge: Story, Fraktionen, Gegnergruppen, Klassen, Anstieg

Stand 10. Nov. 2026. **Nichts hiervon ist entschieden** – das ist der Input, um
den der Spieler gebeten hat. Was schon gebaut ist, steht in `PROJEKTSTAND.md`;
die Teams in `data/encounters.json` sind die spielbare Fassung von Abschnitt 3.

---

## 1. Der Aufhänger: „Die Liga und der Virus"

> **Ersetzt (14. Nov. 2026)** durch den Story-Leitfaden in `STORY_LEITFADEN.md`.

**Empfehlung.** Ein Satz: *Neon City trägt seine Revierkämpfe in der DROME-Liga
aus – und ein Virus bringt die Liga gerade zum Kippen.*

* **Die Welt.** Vier Fraktionen teilen sich die Stadt. Statt auf der Straße
  kämpfen sie in Arenen, mit DROMEs. Wer gewinnt, hält sein Revier.
* **Du.** Ein neuer *Dromer* (Mechaniker und Teamchef) mit vier gebrauchten
  Standard-DROMEs. Eine alte Mechanikerin nimmt dich an und bringt dich durch
  die Zulassung – das sind **Level 1 und 2**, das Training mit kleinem Squad.
* **Der Chaos-Virus.** Er befällt die Arena-Netze. Befallene DROMEs bauen sich
  selbst um – beliebige Waffen, beliebige Module – und greifen alles an. Die
  Liga vertuscht es. Das ist der **Chaos-Kampf**: der einzige Ort, an dem
  gewürfelt wird, und jetzt hat das einen Grund.
* **Die Fraktionen** reagieren verschieden, und daraus kommt ihr Spielstil:

  | Fraktion | Haltung zum Virus | Spielstil |
  |---|---|---|
  | Neon Ninja's (Neon City) | „Eine Prüfung. Wer besteht, ist würdig." | Kämpfer, suchen den Nahkampf |
  | Solar Sentients (Parkanlage) | „Kein Feind – ein neuer Zweig." Sie nehmen ihn auf. | Rudel, teilen und vermehren sich |
  | Mega Mechas (Factory 5) | „Einsperren und verkaufen." | Festung, Schilde, Artillerie |
  | Hipstar Hackers (Dachterrassen) | Sie haben ihn freigesetzt – aus Versehen, sagen sie. | Trickser (Vorschlag, Abschnitt 3) |

* **Der Endlos-Modus** ist das *Chaos-Netz*: die Simulation unter der Stadt, in
  der der Virus wohnt. Dort tauchen Chaos-Knoten auf, dort gibt es kein Ende.
  Freigeschaltet, sobald man Neon City bezwungen hat – man hat bewiesen, dass
  man es aushält.

Warum dieser Aufhänger: er erklärt **alles, was das Spiel ohnehin tut** –
Training, Fraktionsteams, Bosse (die Champions der Fraktion), Chaos, Endlos –
und braucht dafür keine Zwischensequenzen. Zwei Sätze vor jedem Level reichen.

Zwei Alternativen, falls das nicht passt: *Schrottplatz* (du baust aus Wracks
die erste Mannschaft, jede Fraktion ist ein Zulieferer, den man überzeugt) oder
*Meisterschaft* (reine Sport-Geschichte ohne Virus – dann fehlt dem Chaos-Kampf
der Grund).

---

## 2. Story-Modus Neon City: zehn Level

Baut auf `NEUANFANG.md` 6h auf (jedes Level eine eigene Reihe Kämpfe, 3 Leben
je Level, ein verlorener Kampf wird wiederholt, Fortschritt bleibt). Neu ist
nur, **was** in den Leveln steht.

| Level | Titel | Squad | Kämpfe | Gegner | Neu für den Spieler |
|---|---|---|---|---|---|
| 1 | Zulassung I | **2** | 3 | Sparring, je 2 | Aufstellen, Kampf lesen |
| 2 | Zulassung II | **3** | 3 | Sparring, je 3 | Laden, erstes Modul |
| 3 | Erster Ligakampf | 4 | 4 | Straßenbande, Klingentrupp | Gegnertypen, Gegnerwahl |
| 4 | Die Werfer | 4 | 4 | Wurfsterne, Hornissen | Elite-Knoten |
| 5 | Das Dojo | 4 | 5 | Eisenfaust + **Boss Oni** | Rezepte, erster Boss |
| 6 | Schattenviertel | 4 | 5 | Schattenläufer, Klingentrupp | Gegner tragen Rezepte |
| 7 | Rivalen | 4 | 5 | gemischt, Gegner Level 2 | Matrix-BIOS |
| 8 | Die Meister | 4 | 6 | Schattenrat, Nachtwache | nur noch Elite-Teams als Elite |
| 9 | Vor dem Turm | 4 | 6 | alles, Gegner Level 3 | – |
| 10 | Der Turm | 4 | 6 | Klingenmeister + **Boss Shogun Kage** | Endlos-Modus |

* **Level 1 und 2 mit normalen DROMEs**, wie gewünscht: die Sparring-Teams
  sind die vier Standard-DROMEs in Standardausstattung, ohne Module.
* **Ab Level 3 Fraktions-DROMEs.** Solange es keine eigenen Chassis gibt
  (Abschnitt 3), sind das die handverlesenen Teams mit Namen – Kiri, Oni,
  Yumi –, die der Spieler wiedererkennt.
* **Heute gebaut** ist die Vorstufe: *ein* Lauf mit 8 Kämpfen, die ersten zwei
  als Training. Die Level-Struktur selbst steht aus (siehe Abschnitt 6).

---

## 3. Fraktionen und Gegnergruppen

Jede Fraktion braucht drei Dinge: einen **Stil**, den man am ersten Kampf
erkennt, eine **Antwort**, die der Spieler finden kann, und **eigene DROMEs**,
die es nur dort gibt.

### Gegnertypen (gebaut)

Jedes Team hat einen Typ. Zwei Normal-Knoten einer Reihe haben verschiedene
Typen – die Wahl ist dann „welches Problem will ich lösen", nicht nur „wie
schwer".

| Typ | Was er tut | Was hilft |
|---|---|---|
| Sturm | Nahkämpfer, rücken sofort ran | feste Front, Stacheln, Abstand |
| Schützen | bleiben weg und schießen | schnell ran, Schild, Locken |
| Bollwerk | dicke Front mit Schild und Reparatur | Energie gegen Schild, Feuer bündeln |
| Kontrolle | betäuben, locken, Flächen | verteilt aufstellen, den Wirker zuerst |
| Gemischt | von allem etwas | – |

### Teams der Neon Ninja's (gebaut, `data/encounters.json`)

| Team | Typ | Aufstellung (in dieser Reihenfolge) | Stufe |
|---|---|---|---|
| Straßenbande | Gemischt | Vireo Blaster, Vireo Klinge, Molok Hammer + Blaster, Strix Neon-Blaster | Leicht, Normal |
| Klingentrupp | Sturm | Vireo Klinge, Molok Hammer + Ramme, Vireo Klinge, Vireo Bumerang | Leicht, Normal |
| Hornissen | Sturm | Vireo Bumerang, Nimbus Bumerang, Vireo Klinge, Vireo Bumerang | ab Runde 3 |
| Wurfsterne | Schützen | Vireo Bumerang, Strix Lanze, Vireo Neon-Blaster, Molok Deflektor + Blaster | Leicht, Normal |
| Eisenfaust | Bollwerk | Molok Hammer + Ramme, Vireo Schraubenschlüssel, Molok Deflektor + Hammer, Vireo Klinge | Leicht, Normal |
| Schattenläufer | Kontrolle | Nimbus Klinge, Molok Hammer + Deflektor, Vireo Klinge, Vireo Bumerang | Leicht, Normal |
| Schattenrat | Kontrolle | Strix Lanze, Nimbus Runenstab, Molok Deflektor + Hammer, Vireo Klinge | **Elite** |
| Klingenmeister | Sturm | Nimbus Klinge, Molok Hammer + Ramme, Vireo Klinge, Vireo Klinge | **Elite** |
| Nachtwache | Schützen | Strix Lanze, Molok Deflektor + Hammer, Strix Lanze, Molok Hammer + Ramme | **Elite** |

Für Solar Sentients und Mega Mechas liegen je vier Teams als erste Fassung in
derselben Datei (Schwarm, Lichtfänger, Wurzelwerk, Mutterblüte / Panzerkeil,
Batterie, Walze, Werkschutz).

### Eigene DROMEs je Fraktion (Vorschlag, nicht gebaut)

Je Fraktion **ein** neues Chassis genügt für den Anfang – es ist der DROME, den
man aus diesem Gebiet mitnimmt.

| Fraktion | Neues Chassis | Rolle | Passive | Warum |
|---|---|---|---|---|
| Neon Ninja's | **Shinobi** | Jäger | *Hinterhalt:* der erste Treffer auf ein neues Ziel +50 % | Die geplante Jägerklasse (`NEUANFANG.md` 6f): jagt den Verwundbarsten. Der Ausgleich zum Strix. |
| Solar Sentients | **Spore** | Rudel | *Teilung:* zerfällt beim Tod in zwei schwache Sporlinge | Der DROME, der sich aufteilt (steht schon in `MODULE_KONZEPT.md` 9). |
| Mega Mechas | **Bastion** | Geschütz | *Verankert:* läuft nicht, dafür +2 Reichweite und ein Schildwall für Nachbarn | Eine Festung braucht einen Turm. Antwort: flankieren, Mörser. |
| Hipstar Hackers | **Hook** | Trickser | *Greifhaken:* jede Fähigkeit zieht ihr Ziel 2 Felder heran | Zerreißt die Aufstellung des Spielers – der einzige Gegner, der das kann. |

**Hipstar Hackers = Trickser** ist der Vorschlag für das offene Profil: sie
ziehen die Hinterreihe nach vorn, stellen Hologramm-Köder und stören den Takt.
Antwort des Spielers: Wurzeln, robuste Hinterreihe, Fluchtpunkt-BIOS.

### Bosse

Ein Boss ist ein Team mit **einem** besonderen DROME, der ein BIOS-Rezept
trägt (`MODULE_KONZEPT.md`: Bosse tragen eins, droppen dauerhafte Beute).

* **Oni** (Level 5): Molok mit Hammer + Ramme und *Berserker*. Lehrt: nicht
  alle in den Nahkampf schicken.
* **Shogun Kage** (Level 10): Nimbus mit Plasmaklinge und *Taktgeber* – Echo
  macht aus jedem dritten Hieb einen doppelten Aufschlitzer. Lehrt: den
  Wirker zuerst, mit Betäubung oder Locken.

---

## 4. Klassen

Heute gibt es vier Rollen (Vorhut, Plänkler, Kontrolle, Scharfschütze), jede
genau einmal. Vorschlag: **sechs Rollen**, und jede Fraktion betont zwei.

| Rolle | Heute | Zielregel | Fraktion, die sie betont |
|---|---|---|---|
| Vorhut | Molok | den Nächsten | Mega Mechas |
| Plänkler | Vireo | den Nächsten, kitet | Neon Ninja's |
| Kontrolle | Nimbus | den, um den die meisten Gegner stehen | Solar Sentients |
| Scharfschütze | Strix | den, der am meisten Schaden macht | Mega Mechas |
| **Jäger** (neu) | – | den Verwundbarsten (Regel „hunter" liegt schon bereit) | Neon Ninja's |
| **Stütze** (neu) | nur als Waffe (Schraubenschlüssel) | heilt den Verletztesten | Solar Sentients |

Die Messung zum Kampfwert stützt das: **Reichweite entscheidet heute fast
alles** (Strix 146, Molok 71). Ein Jäger, der Schützen erreicht, und eine
Stütze, die eine Front am Leben hält, sind die zwei Rollen, die dem Nahkampf
fehlen.

---

## 5. Anstieg

### Womit man planen kann

Der neue Kampfwert sagt den Ausgang gut genug voraus, um damit Stufen zu
bauen. Gemessen an 3000 Kämpfen zufälliger Squads
(`tools/playtest/power_bench.gd`):

| Kampfwert Gegner / eigener | Siegchance |
|---|---|
| unter 0,6 | 97 % |
| 0,6 – 0,8 | 89 % |
| 0,8 – 0,95 | 72 % |
| 0,95 – 1,05 | 50 % |
| 1,05 – 1,2 | 25 % |
| 1,2 – 1,4 | 10 % |

**Vorschlag für die Stufen:** Leicht 0,6–0,75 · Normal 0,85–1,0 · Elite
1,05–1,15 · Boss 1,15–1,25. Der eigene Kampfwert zählt Module und Level mit –
ein Elite-Team, das zu Beginn bei 1,15 liegt, rutscht mit zwei guten Modulen
auf 1,0. Die Vorschau zeigt beide Werte schon an; ein Team, das aus dem Band
fällt, sieht man dort sofort.

### Gegner je Story-Level (Vorschlag)

Stärker werden die Gegner wie beschlossen **nicht über einen Faktor**, sondern
über Zahl, Level und Module.

| Level | Gegner | DROME-Level | Waffenlevel | Module je Gegner |
|---|---|---|---|---|
| 1–2 | 2 / 3 | 0 | 0 | 0 |
| 3–4 | 4 | 0 | 0–1 | 0–1 |
| 5–6 | 4 | 1 | 1–2 | 1, ab hier ein Rezept bei Elite |
| 7–8 | 4 | 2 | 2–3 | 2 |
| 9–10 | 4 | 2–3 | 3–4 | 2–3, Boss mit BIOS |

Elite jeweils +1 DROME-Level, +2 Waffenlevel, +1 Modul (wie heute).

### Endlos-Modus

Heute steigen die Gegner nach dem Ende der Tabellen einfach weiter (alle 3
Runden ein DROME-Level, alle 2 ein Waffenlevel, alle 4 ein Modul) – das ist ein
Platzhalter. Vorschlag:

* **Sektoren zu je 5 Runden.** Jeder Sektor gehört einer freigeschalteten
  Fraktion; am Ende steht ihr Boss-Knoten. So wechselt das Problem, statt nur
  zu wachsen.
* **Chaos-Knoten** ab Sektor 1, im Schnitt jede vierte Reihe (gebaut).
* **Beute wächst mit dem Sektor**: ab Sektor 2 Waffen mit einem Level, ab
  Sektor 3 Aufstiegswaffen. Wer verliert, verliert sie – das ist der Reiz.

---

## 6. Was als Nächstes zu entscheiden ist

1. **Aufhänger** – „Die Liga und der Virus" so übernehmen?
2. **Level-Struktur bauen** – zehn Level nach der Tabelle in Abschnitt 2,
   Level 1 mit zwei und Level 2 mit drei DROMEs? Das ist der größte offene
   Baustein; die Teams dafür sind da.
3. **Wege zwischen den Reihen** – sie sind entfallen, weil „immer ein
   leichter Kampf" sonst nicht zu halten war. Wenn die Wege zurück sollen:
   jeder Knoten führt zum Leichten und zu *einem* der beiden schwereren.
4. **Erstes Fraktions-Chassis** – Shinobi (Jäger) zuerst? Er braucht ein
   Bild aus der Werkstatt.
5. **Hipstar Hackers = Trickser?**
6. **Schwierigkeit** – Normal ist für einen Squad ohne Module in Runde 8 zu
   63 % zu gewinnen, Elite zu 41 %. Mit Modulen wird das leichter. So lassen
   und im Playtest prüfen, oder die Elite-Teams anziehen?
7. **Aufstellung** – der erste Treffer fällt jetzt nach 5,6 s statt 2,0 s.
   Wenn das zu lang ist: `deployment.inset` in `data/config.json` (1 → 3).
8. **Umlaute in der Anzeige** – das Spiel schreibt „Kaempfe", „waehlen".
   Die Schrift kann ä, ö, ü; soll die Anzeige umgestellt werden?
