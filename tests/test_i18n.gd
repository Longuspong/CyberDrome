extends RefCounted

## Uebersetzung (19. Nov. 2026): Standard Deutsch, Englisch aus i18n/texte.csv.


var t


func test_translation() -> void:
	t.ok(Accessibility.language == "de" or Accessibility.language == "en", "Sprache bekannt")
	var before := TranslationServer.get_locale()
	TranslationServer.set_locale("en")
	t.ok(TranslationServer.translate("Neues Spiel") == "New Game", "en: Neues Spiel -> New Game")
	t.ok(TranslationServer.translate("Gibt es nicht") == "Gibt es nicht", "en: ohne Zeile bleibt Deutsch")
	TranslationServer.set_locale("de")
	t.ok(TranslationServer.translate("Neues Spiel") == "Neues Spiel", "de: Text bleibt")
	TranslationServer.set_locale(before)


## Jede Zeile der CSV hat eine englische Uebersetzung, keine Dopplungen.
func test_csv_complete() -> void:
	# Jede Zeile der CSV hat eine englische Uebersetzung, keine Dopplungen.
	var file := FileAccess.open("res://i18n/texte.csv", FileAccess.READ)
	t.ok(file != null, "texte.csv lesbar")
	if file == null:
		return
	var seen := {}
	file.get_csv_line()
	while not file.eof_reached():
		var row := file.get_csv_line()
		if row.size() < 2 or row[0] == "":
			continue
		t.ok(not seen.has(row[0]), "doppelt in texte.csv: " + row[0])
		t.ok(row[1].strip_edges() != "", "ohne Englisch: " + row[0])
		seen[row[0]] = true
