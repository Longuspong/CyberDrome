#!/usr/bin/env node
/*
 * Rechnet die Werkstatt gegen die Engine.
 *
 * Warum es diese Datei gibt
 * -------------------------
 * Die Bauteilwerte stehen an genau einer Stelle -- in "stats" der Teil-JSONs,
 * erzeugt von tools/build_sample_parts.py. Die SUMMIERUNG dieser Werte gibt es
 * aber zwangslaeufig zweimal: in GDScript fuer den Kampf und in JavaScript fuer
 * die Anzeige in der Werkstatt. Zwei Rechnungen fuer dieselbe Sache laufen
 * frueher oder spaeter auseinander, und dann verspricht die Werkstatt Werte,
 * die im Kampf nicht gelten.
 *
 * Dieses Skript liest die ECHTEN Funktionen aus index.html -- nicht eine Kopie
 * davon -- und prueft sie gegen dieselben Erwartungswerte, die auch
 * tests/test_drome_build.gd prueft. Weicht eine Seite ab, faellt es hier auf.
 *
 * Massgeblich bleibt die Engine: ein Loadout speichert Teile-IDs, keine Werte.
 * Diese Pruefung sorgt nur dafuer, dass die Anzeige nicht luegt.
 *
 * Aufruf
 * ------
 *     node tools/check_workshop_stats.js
 */

"use strict";

const fs = require("fs");
const path = require("path");
const vm = require("vm");

const ROOT = path.resolve(__dirname, "..");

// ---------------------------------------------------------------------------
// Bauteile laden -- dieselbe Quelle, die auch die Werkstatt ueber /api/library
// ausliefert.
// ---------------------------------------------------------------------------
const partsById = new Map();
for (const setDir of fs.readdirSync(path.join(ROOT, "parts"))) {
  const dir = path.join(ROOT, "parts", setDir);
  if (!fs.statSync(dir).isDirectory()) continue;
  for (const file of fs.readdirSync(dir)) {
    if (!file.endsWith(".json") || file === "set.json") continue;
    const meta = JSON.parse(fs.readFileSync(path.join(dir, file), "utf8"));
    if (meta.direction !== "south") continue;   // Werte sind richtungsunabhaengig
    partsById.set(meta.id, meta);
  }
}

// ---------------------------------------------------------------------------
// Den echten Block aus index.html holen
// ---------------------------------------------------------------------------
const html = fs.readFileSync(path.join(ROOT, "index.html"), "utf8");
const start = html.indexOf("// >>> STATS-BLOCK ANFANG");
const end = html.indexOf("// <<< STATS-BLOCK ENDE");
if (start < 0 || end < 0) {
  console.error("Die Marker STATS-BLOCK fehlen in index.html. Ohne sie kann "
    + "diese Pruefung die echten Funktionen nicht lesen -- und eine Pruefung, "
    + "die still ausfaellt, ist schlimmer als keine.");
  process.exit(2);
}
const source = html.slice(start, end);

// Was der Block aus der Werkstatt heraus benutzt. Bewusst nur so viel, wie er
// wirklich braucht -- der Rest der Werkstatt gehoert nicht in diese Pruefung.
const sandbox = {
  resolvePart: (id) => partsById.get(id) || null,
  anchorsOf: (part) => {
    if (!part) return {};
    const out = {};
    for (const anchor of part.anchors || []) out[anchor.name] = anchor;
    return out;
  },
  categoryOf: (part) => part.category || "weapon",
  slotDefs: () => currentSlotDefs,
  fitsSlot: (part, def) => {
    const rule = def && def.rule;
    if (!rule) return true;
    const order = ["light", "medium", "heavy"];
    const limit = rule.max_class || "heavy";
    if (order.indexOf(part.mount_class || "light") > order.indexOf(limit)) return false;
    const allowed = rule.categories;
    return !allowed || allowed.includes(part.category || "weapon");
  },
  escapeXml: (s) => String(s),
  console,
};
vm.createContext(sandbox);
vm.runInContext(source, sandbox);

// ---------------------------------------------------------------------------
// Pruefungen
// ---------------------------------------------------------------------------
let failures = 0;

function check(label, actual, expected) {
  const ok = JSON.stringify(actual) === JSON.stringify(expected);
  if (!ok) {
    failures += 1;
    console.log(`  [FEHLER] ${label}\n           erwartet ${JSON.stringify(expected)}`
      + `, war ${JSON.stringify(actual)}`);
  }
  return ok;
}

function loadoutOf(assignment) {
  const out = {};
  for (const [slot, partId] of Object.entries(assignment)) out[slot] = { partId };
  return out;
}

let currentSlotDefs = [];

function withSlotDefs(assignment, fn) {
  const body = partsById.get(assignment.body);
  const anchors = sandbox.anchorsOf(body);
  const rules = (body && body.slot_rules) || {};
  currentSlotDefs = Object.keys(anchors)
    .filter((n) => n.startsWith("equip_"))
    .map((n) => ({ slot: n, anchor: n, type: "equipment", rule: rules[n] || null }));
  return fn();
}

// Dieselben Standardaufbauten, die check_stats() in build_sample_parts.py und
// test_drome_build.gd durchrechnen.
const STOCK = {
  bot1: { body: "scout_body", head: "scout_head", feet: "scout_feet",
          core: "scout_core", equip_left: "eq_pulse_blaster",
          equip_right: "eq_deflector" },
  bot2: { body: "jugg_body", head: "jugg_head", feet: "jugg_feet",
          core: "jugg_core", equip_left: "eq_siege_cannon",
          equip_shoulder: "eq_drone_pod" },
  bot3: { body: "mage_body", head: "mage_head", feet: "mage_drive",
          core: "mage_core", equip_left: "eq_rune_staff",
          equip_right: "eq_orbit_focus" },
  bot4: { body: "strix_body", head: "strix_head", feet: "strix_feet",
          core: "strix_core", equip_center: "eq_rail_lance" },
};

// Erwartungswerte aus dem Testlauf der Engine (tests/test_drome_build.gd).
const EXPECTED = {
  // SPD enthaelt den Abzug der Zuladung (DromeBuild.payload_slowdown): je vier
  // Punkte Ausruestungsgewicht ein Punkt weniger. Der Molok bleibt bei 6, weil
  // sein pauschales Chassis-SPD von -2 im selben Zug entfallen ist -- dieselbe
  // Schwere, jetzt aus dem Gewicht statt aus einer Konstante.
  bot1: { hp: 60, en_max: 40, spd: 13, mov: 4, atk: 0, def: 6, power: 207 },
  bot2: { hp: 145, en_max: 70, spd: 6, mov: 2, atk: 0, def: 9, power: 314 },
  bot3: { hp: 85, en_max: 110, spd: 13, mov: 5, atk: 1, def: 2, power: 257 },
  bot4: { hp: 70, en_max: 50, spd: 8, mov: 4, atk: 6, def: 2, power: 219 },
};

console.log("\n=== Werkstatt gegen Engine ===\n");

for (const [setId, assignment] of Object.entries(STOCK)) {
  const loadout = loadoutOf(assignment);
  withSlotDefs(assignment, () => {
    const stats = sandbox.buildStats(loadout);
    const want = EXPECTED[setId];
    for (const key of ["hp", "en_max", "spd", "mov", "atk", "def"]) {
      check(`${setId}.${key}`, stats[key], want[key]);
    }
    check(`${setId}.power`, Math.round(sandbox.powerScore(loadout)), want.power);
    const problems = sandbox.validateLoadout(loadout);
    check(`${setId} ist gueltig`, problems, []);
  });
}

// Die Validierung muss dieselben Regeln nennen wie DromeBuild.validate().
withSlotDefs({ body: "scout_body" }, () => {
  const problems = sandbox.validateLoadout(loadoutOf({ body: "scout_body" }));
  // "Keine Waffe bestueckt" steht hier bewusst NICHT mehr: ein waffenloser
  // Aufbau ist eine Entscheidung, kein Fehler (DromeBuild.structural_problems).
  for (const expected of ["Sensorik fehlt", "Antrieb fehlt", "Kern fehlt"]) {
    if (!problems.includes(expected)) {
      failures += 1;
      console.log(`  [FEHLER] leerer Aufbau meldet "${expected}" nicht`);
    }
  }
});

// Und die Gegenprobe zu derselben Regel: der waffenlose Techniker ist baubar.
// Ohne sie koennte die Waffenpflicht hier unbemerkt wieder einziehen, waehrend
// die Engine sie laengst abgelegt hat -- zwei Werkstaetten, zwei Wahrheiten.
{
  const technician = { body: "jugg_body", head: "jugg_head", feet: "jugg_feet",
                       core: "jugg_core", equip_left: "eq_deflector",
                       equip_shoulder: "eq_drone_pod" };
  withSlotDefs(technician, () => {
    check("waffenloser Techniker ist baubar",
      sandbox.validateLoadout(loadoutOf(technician)), []);
  });
}

// Schwer, aber baubar: die Bau-Deckel (Traglast, Energiebedarf) sind gestrichen.
// Gewicht ist Tempo, Energie ist Mana -- kein Riegel in der Werkstatt. Diese
// Gegenprobe haelt fest, dass die HTML-Werkstatt keine Traglast-Grenze mehr
// nennt, waehrend die Engine sie laengst abgelegt hat (DromeBuild.validate()).
withSlotDefs(
  { body: "scout_body", head: "jugg_head", feet: "jugg_feet", core: "jugg_core",
    equip_left: "eq_pulse_blaster" },
  () => {
    const problems = sandbox.validateLoadout(loadoutOf(
      { body: "scout_body", head: "jugg_head", feet: "jugg_feet",
        core: "jugg_core", equip_left: "eq_pulse_blaster" }));
    if (problems.some((p) => p.startsWith("Traglast"))) {
      failures += 1;
      console.log("  [FEHLER] die Traglast-Grenze lebt in der Werkstatt weiter: "
        + problems.join(", "));
    }
  });

if (failures === 0) {
  console.log("Alle Werte stimmen mit der Engine ueberein.\n");
}
process.exit(failures === 0 ? 0 : 1);
