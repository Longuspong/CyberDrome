# GlitchTitle

Das Glitch-Logo und die Bildschirmtitel: Bungee in `white`, darunter Cyan und Magenta versetzt (Bildschirm-Mischung).

## Wann
- Logo CYBER / DROME auf Titel und Spielstand-Wahl (`logo`, `logo-small`).
- Bildschirmtitel links in der Kopfzeile (`screen-title`, gedreht um `tilt-title`).

## Aufbau
`<span class="cd-glitch" data-text="HANGAR"><span>HANGAR</span></span>`; `cd-glitch--live` laesst ihn alle 3,6 s springen (nur ohne „Bewegung reduzieren").

## Regeln
- Es gibt kein Logo als Bild: das Logo ist immer dieser Satz.
- Nie mehr als ein Glitch-Element je Bildschirm.

Nachgebaut aus `Arcade.GlitchLogo` / `UiKit.header`.
