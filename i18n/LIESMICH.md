# Uebersetzungen (seit 19. Nov. 2026, Vorbereitung Englisch)

* `texte.csv` -- erste Spalte `keys` ist der **deutsche Anzeigetext selbst**,
  daneben `en`. Fehlt eine Zeile, zeigt das Spiel einfach den deutschen Text.
* Godot macht beim Import (`godot --headless --path . --import`) daraus
  `texte.en.translation` (nicht eingecheckt, `.gitignore`).
* Sprache: `Accessibility.language` / `set_language()` (Standard `de`, noch
  kein Schalter in den Optionen).

## Regeln fuer neue Texte

* In Nodes `tr("Deutscher Text")`, in statischem Code
  `TranslationServer.translate("Deutscher Text")`.
* Platzhalter erst nach der Uebersetzung einsetzen:
  `tr("%d Kaempfe gewonnen") % n` -- nie `tr("%d ..." % n)`.
* Begriffe (Einsatz, Fusion, Halter ...) englisch so, wie sie im Glossar der
  SPOT stehen (`CyberDrome_SPOT_Entscheidungen.xlsx`, Spalte Englisch).
* Daten (`data/*.json`, `parts/`) bleiben vorerst deutsch -- wie sie
  uebersetzt werden, ist noch offen.
