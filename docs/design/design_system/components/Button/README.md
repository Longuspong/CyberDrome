# Button

Grosse Knoepfe in drei Arten: gelber Hauptknopf, violetter Zweitknopf mit abgeschraegten Ecken, Rahmenknopf in einer Akzentfarbe -- dazu der Textknopf zum Loeschen.

## Wann
- **Hauptknopf** (`cd-btn--primary`): die eine Hauptaktion des Bildschirms (ZUR KARTE, WEITERSPIELEN). Nie zwei auf einem Bildschirm.
- **Rahmenknopf** (`cd-btn--outline`, Farbe ueber `--btn-color`): Nebenwege wie REZEPTBUCH (`cyan`) oder NEUES SPIEL (`yellow`).
- **Zweitknopf** (`cd-btn--secondary`): gleichrangige Aktionen in Listen und Popups.
- **Textknopf** (`cd-btn--text`, `rose`): LOESCHEN; bestaetigt durch zweites Tippen.

## Aufbau
`<button class="cd-btn cd-btn--primary"><span class="cd-btn__face">Text</span></button>`. Die Flaeche (`cd-btn__face`) traegt Farbe und Schraege; der Knopf selbst den Schatten. Ein Symbol kommt als `cd-icon` in die Flaeche, hinter den Text (Pfeil) oder davor.

## Regeln
- Mindesthoehe `button-height`, Fokusrahmen `line-focus` in `focus`.
- Haupt- und Rahmenknopf GROSS in Bungee; Zweitknopf normal geschrieben in Chakra Petch 700.
- Der Hauptknopf traegt `shadow-primary`; ausgegraut ohne Schatten.

Nachgebaut aus `UiKit.button`, `UiKit.outline_button`, `Arcade.button`, `Arcade.text_button`.
