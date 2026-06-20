# BuildLogStats

Ein **Delphi-IDE-Plugin** (RAD Studio 12 / Delphi 12) das nach jedem Build
automatisch das Compiler-Log einsammelt und in einem **dockbaren Werkzeugfenster**
als übersichtliche Statistik aufbereitet: Fehler, Warnungen, Hinweise, häufigste
Meldungs-Codes, veraltete Symbole und die Dateien mit den meisten Meldungen.

Zusätzlich schreibt das Plugin nach jedem Build eine **Brücke nach VS Code**
(`%TEMP%\DelphiBuildBridge`), sodass ein VS-Code-Task einen IDE-Build auslösen
und auf das Ergebnis warten kann.

---

## Funktionsweise

Das Plugin ist ein Design-Time-Package (`requires designide`) und klinkt sich
über die **ToolsAPI** in die IDE ein:

1. **Menüeintrag** – fügt unter *Ansicht / View* den Punkt **„Build Log"** ein,
   der das dockbare Toolfenster öffnet.
2. **Build-Mitschnitt** – hängt sich an den Kompiliervorgang:
   - `IOTAToolsFilterNotifier` (roher Compiler-Stdout; seit MSBuild meist inaktiv)
   - `IOTACompileNotifier` – merkt sich die Projektverzeichnisse und lädt nach dem
     Build die jüngste `*.log`/`*.all`-Datei.
3. **Auswertung** – parst die `dcc32/dcc64`-Ausgabe (deutschsprachige Formate) und
   erzeugt den Statistik-Report.
4. **Anzeige** – stellt Log und Statistik im Toolfenster dar, inkl.
   Behebungsvorschlägen zu einzelnen Meldungs-Codes.

---

## Quelldateien

| Unit | Aufgabe |
|---|---|
| `BuildLogStats.dpk` | Package-Definition (Ausgabe: `BuildLogStats.bpl`) |
| `BuildLogReg.pas` | Registrierung: Menüeintrag *Ansicht › Build Log* |
| `BuildLogIDEWin.pas` | `INTACustomDockableForm` – dockbares IDE-Toolfenster |
| `BuildLogCapture.pas` | Build-Mitschnitt (ToolsAPI-Notifier) + VS-Code-Bridge |
| `BuildLogParser.pas` | Parser der Compiler-Ausgabe + Statistik-Report |
| `BuildLogHints.pas` | Behebungsvorschläge zu Compiler-Codes (W…/H…/E…) |
| `BuildLogFrame.pas/.dfm` | UI (Toolbar, Tabs, Listen) |

---

## Voraussetzungen

- RAD Studio 12 / Delphi 12 (ToolsAPI; nutzt u. a. `INTAServices270`)
- Windows
- Laufende IDE zum Bauen — siehe [Build-Hinweis](#build-hinweis)

---

## Installation

1. `BuildLogStats.dproj` in der RAD-Studio-IDE öffnen.
2. Im Projekt-Manager **Rechtsklick** auf `BuildLogStats.bpl` → **Installieren**.
3. Die IDE lädt das Package und fügt unter **Ansicht** den Eintrag
   **Build Log** hinzu.

Deinstallieren: **Tools › Optionen › IDE › Packages**, `Build Log IDE Fenster Plugin`
auswählen und entfernen.

---

## Bedienung

Fenster öffnen über **Ansicht › Build Log** (dockbar, frei platzierbar).

**Toolbar**

| Button | Funktion |
|---|---|
| Log öffnen… | Log-Datei manuell auswählen |
| Zuletzt geöffnet ▼ | Popup mit den zuletzt geöffneten Dateien |
| Leeren | Ansicht zurücksetzen |
| Aus IDE-Meldungen | das zuletzt mitgeschnittene Build-Log laden |

**Tabs**

| Tab | Inhalt |
|---|---|
| Statistik | Aufbereiteter Report (Projekt, Konfiguration, Bauzeit, Zählungen, Top-Listen) |
| Fehlercodes | Liste aller Codes mit Typ, Anzahl und Beschreibung |
| Code | Filter nach einem Code; zeigt Behebungsvorschlag, Rohzeile und Trefferliste |
| Rohlog | unverändertes Log |

Die zuletzt geöffneten Dateien werden in
`%APPDATA%\BuildLogStats\recent.ini` gespeichert.

---

## Unterstützte Log-Formate

```
[dcc64 Warnung] datei.pas(42): W1000 Symbol '...' ist veraltet
[dcc64 Hinweis] datei.pas(42): H2443 Inline-Funktion ...
[dcc64 Fehler]  datei.pas(42): E2003 Undeklarierter Bezeichner
Erzeugen von rhd.dproj (Debug, Win64)
Vergangene Zeit 00:00:17.43
605 Warnung(en)
0 Fehler
```

---

## VS-Code-Bridge

Nach jedem Build schreibt das Plugin in `%TEMP%\DelphiBuildBridge`:

| Datei | Inhalt |
|---|---|
| `build.log` | das gesammelte Compiler-/Messages-Log |
| `build.status` | `SUCCEEDED` / `FAILED` / `BACKGROUND` + Zeitstempel |

`build.status` wird **zuletzt** geschrieben — sein Erscheinen signalisiert dem
VS-Code-Task „Build fertig". Die Bridge ist bewusst fehlertolerant und stört den
Build niemals.

---

## Build-Hinweis

Je nach Delphi-Edition (Starter/Community) sind die Kommandozeilen-Compiler
`dcc32`/`msbuild` lizenzgesperrt. Das Package lässt sich dann **nur über die
laufende IDE** bauen und installieren (Rechtsklick › Installieren).

---

## Projektstruktur

```
BuildLogStats/
├─ BuildLogStats.dpk        Package
├─ BuildLogStats.dproj      Projektdatei
├─ BuildLogStats.res        Versionsressource
├─ BuildLog*.pas / .dfm     Quellen
├─ .gitignore / .gitattributes
└─ README.md
```
