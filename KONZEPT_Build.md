# Konzept: Build-Auslösung mit MSBuild + Fortschrittsanzeige

> Status: **Konzept / Vorab** – noch keine Implementierung.
> Ziel-Edition: **RAD Studio Professional oder höher** (CLI-Compiler/`msbuild.exe` lizenziert).

> **⚠️ Lauffähigkeit / Editions-Hinweis (empirisch geprüft 2026-06-20):**
> Der **aktuelle Entwicklungsrechner** hat **Delphi 12 / BDS 23.0 Starter** installiert.
> Ein Trivial-Compile via `rsvars.bat` + `dcc32` bricht hier ab mit
> *„This version of the product does not support command line compiling."* →
> **Variante B (externer MSBuild) ist auf dieser Maschine NICHT lauffähig**; sie
> funktioniert nur auf einem **Pro+-Zielrechner**. Auf dem Starter-Rechner ist allein
> **Variante A (In-IDE-Build, §9)** ausführbar. Umsetzungsreihenfolge daher: **B zuerst**
> (für Pro+-Ziel), **A als zweiter, hier lauffähiger Modus**.

---

## 1. Ziel

Das Tool soll das **aktuell geladene Projekt** oder die **Projektgruppe** in der
eingestellten Variante (Scope + aktive Config/Plattform) **selbst bauen**:

1. Build über **`msbuild.exe`** als externen Prozess anstoßen.
2. Die **Log-Ausgabe** des Builds in die bestehende Statistik-Pipeline einspeisen.
3. Den Build-Fortschritt in einer **Progressbar** darstellen.

Hauptweg = **Variante B (externer MSBuild-Prozess)**. Variante A (In-IDE-Build über
ToolsAPI) ist als editions-unabhängiger Fallback in [§9](#9-fallback-variante-a--in-ide-build) skizziert.

---

## 2. Rahmenbedingungen

- RAD Studio 12 / Delphi 12. **Variante B setzt Edition Pro+ voraus** (`dcc32/dcc64`/`msbuild`
  per CLI erlaubt). **Dev-Rechner ist Starter** → B dort nicht ausführbar (siehe Hinweis oben),
  Variante A läuft auf jeder Edition.
- Plugin läuft als Design-Time-Package in der IDE → Zugriff auf die **ToolsAPI** zur
  Ermittlung von Projekt/Gruppe, Config und Plattform.
- Eine `.dproj`/`.groupproj` **ist** eine MSBuild-Datei → der Build über `msbuild`
  ist äquivalent zum IDE-internen Build, nur als eigener Prozess.

---

## 3. Architektur-Überblick

```
[Button "Bauen"]
      │
      ▼
[BuildController]  ── ermittelt Scope/Config/Plattform via ToolsAPI
      │            ── speichert offene Module (Save all)
      │            ── baut MSBuild-Kommandozeile
      ▼
[Externer Prozess]  cmd /c "call rsvars.bat && msbuild …"
      │ stdout/stderr (Pipe)
      ▼
[Reader-Thread]  ── liest zeilenweise, marshalt in den UI-Thread (TThread.Queue)
      │
      ├──► [Progressbar/Status]   (Live: Phase, Projekt i/N, Zähler)
      ├──► [Rohlog-Tab]           (vollständiges Roh-Log in Echtzeit)
      └──► [TBuildStats-Parser]   (nach Build-Ende → Statistik-Tabs)
```

Neue Logik-Einheit (Vorschlag): **`BuildRunner.pas`** – kapselt Prozessstart,
Pipe-Lesen, Threading und Fortschritts-Events; hält die UI ([BuildLogFrame.pas](BuildLogFrame.pas))
schlank.

---

## 4. Build-Auslösung

### 4.1 Scope & Variante (ToolsAPI)

| Information | Quelle |
|---|---|
| Projektgruppe | `(BorlandIDEServices as IOTAModuleServices).MainProjectGroup` |
| Gruppendatei (`.groupproj`) | `ProjectGroup.FileName` |
| Aktives Projekt | `ProjectGroup.ActiveProject` |
| Projektdatei (`.dproj`) | `Project.FileName` |
| Aktive Plattform | `Project.CurrentPlatform` (z. B. `Win32`, `Win64`) |
| Aktive Konfiguration | aktive `IOTABuildConfiguration` über `IOTAProjectOptionsConfigurations` (z. B. `Debug`, `Release`) |

**Einstellung „Variante" (Scope):**

- **Projekt** → Ziel = aktives `*.dproj`
- **Gruppe** → Ziel = `*.groupproj`

→ als ComboBox/Toggle im Tool-Fenster, Default = „Projekt".

### 4.2 Vor dem Build

- **Speichern erzwingen:** offene/geänderte Module speichern
  (`IOTAModuleServices` iterieren, `IOTAModule.Save(False, True)`), da `msbuild`
  vom Datei­stand auf der Platte baut.

### 4.3 MSBuild-Kommandozeile

`rsvars.bat` setzt die nötige Umgebung (Pfade, `BDS`, Framework-Dir):

```bat
call "%BDS%\bin\rsvars.bat"
msbuild "<Ziel>.dproj" /t:Build /p:Config=<Config> /p:Platform=<Platform> /nologo
```

- `BDS`-Wurzel: `GetEnvironmentVariable('BDS')` oder
  `(BorlandIDEServices as IOTAServices).GetRootDirectory`.
- `/t:Build` (oder `/t:Make` für inkrementell, `/t:Clean;Build` für Rebuild).
- Für die Gruppe identisch mit `<Ziel>.groupproj`.
- Optional `/clp:Verbosity=normal;NoSummary` zur Steuerung der Ausgabemenge.

### 4.4 Prozessstart & Pipe

- `CreateProcess` mit umgeleitetem `stdOut`/`stdErr` auf eine **anonyme Pipe**
  (`CreatePipe`, `STARTF_USESTDHANDLES`, Fenster versteckt).
- Aufruf über `cmd.exe /c "call ""%BDS%\bin\rsvars.bat"" && msbuild …"`,
  damit die von `rsvars` gesetzte Umgebung für `msbuild` gilt.
- Ein **Reader-Thread** liest die Pipe zeilenweise bis EOF; danach `GetExitCodeProcess`
  (0 = Erfolg).

---

## 5. Log → Statistik

- Jede gelesene Zeile geht an:
  1. den **Rohlog-Tab** (Echtzeit-Anzeige),
  2. einen Zeilenpuffer für die spätere Parser-Auswertung.
- Nach Build-Ende: `TBuildStats.ParseLines(buffer)` → die vorhandenen Tabs
  (Statistik / Fehlercodes / Code) füllen sich wie gewohnt.

### 5.1 Parser-Erweiterung (wichtig)

Der aktuelle Parser in [BuildLogParser.pas](BuildLogParser.pas) erkennt das
**deutsche IDE-Meldungsformat** mit Klammern: `[dcc64 Warnung] datei.pas(42): W1000 …`.
Roher `msbuild`-/`dcc`-Output sieht anders aus und ist **sprachabhängig**, z. B.:

```
Main.pas(42): warning W1000: Symbol '...' is deprecated
Main.pas(42): error E2003: Undeclared identifier '...'
```

→ Zweite Regex-Familie ergänzen (ohne Klammern; EN- **und** DE-Schlüsselwörter:
`warning|warnung`, `error|fehler`, `hint|hinweis`). Footer ebenso EN ergänzen
(`N Warning(s)` / `N Error(s)` zusätzlich zu `N Warnung(en)` / `N Fehler`).

**Empfehlung:** `msbuild` per Umgebungsvariable auf eine feste Sprache zwingen
(z. B. invariant/EN) für stabiles Parsing, oder beide Sprachen abdecken.

---

## 6. Fortschrittsanzeige

Da der Build in einem **eigenen Prozess** läuft, bleibt der IDE-Hauptthread frei →
die Progressbar animiert flüssig.

**Mehrstufiges Modell:**

| Ebene | Quelle | Darstellung |
|---|---|---|
| Gesamt (Gruppe) | Projektgrenzen im Log (`Building … .dproj` / `Done Building Project`) bzw. vorab gezählte `ProjectCount` | **determinate** Balken „Projekt i/N" |
| Innerhalb Projekt | keine zuverlässige Gesamtzahl an Units | **Marquee** + Live-Zähler |
| Live-Zähler | gelesene Zeilen, erkannte Warnungen/Fehler | Label „123 Zeilen · 5 Warnungen · 0 Fehler" |
| Abschluss | Exit-Code | „ERFOLG"/„FEHLER" + Dauer |

- **Einzelprojekt:** Marquee + Zähler (keine sinnvolle Prozentbasis).
- Alle UI-Updates aus dem Reader-Thread via `TThread.Queue`/`Synchronize`
  (niemals direkt aus dem Thread auf VCL zugreifen).

---

## 7. UI-Änderungen ([BuildLogFrame](BuildLogFrame.pas))

Neu in der Toolbar/Statusleiste:

- **Button „Bauen"** (startet Build; während des Builds disabled).
- **ComboBox „Variante"**: Projekt | Gruppe.
- (optional) **ComboBox „Aktion"**: Make | Build | Rebuild.
- **TProgressBar** + Status-Label (Phase/Zähler).
- **Button „Abbrechen"** (siehe §8).

Anzeige von Config/Plattform (read-only) aus der ToolsAPI, damit klar ist, *was*
gebaut wird.

---

## 8. Abbruch

- Externer Prozess ist sauber abbrechbar: Prozessbaum beenden
  (`TerminateProcess` bzw. `taskkill /T /PID`), Reader-Thread beenden, UI zurücksetzen.
- Status „Abgebrochen" anzeigen, keine Statistik auswerten.

---

## 9. Fallback: Variante A — In-IDE-Build

Falls auf einer Maschine doch keine CLI-Lizenz vorliegt (oder als zweiter Modus):

- Build über `IOTAProject.ProjectBuilder.BuildProject(cmOTAMake/cmOTABuild …)`.
- Stats über den **bereits vorhandenen** `IOTACompileNotifier` in
  [BuildLogCapture.pas](BuildLogCapture.pas) (keine Parser-Erweiterung nötig).
- Fortschritt **grob** (pro Projekt) aus `ProjectGroupCompileStarted` (Max =
  `ProjectCount`) und `ProjectCompileFinished` (Step); blockiert den Hauptthread.

→ Als Einstellung „Build-Modus: MSBuild (extern) | IDE (intern)" denkbar.

---

## 10. Betroffene Dateien / Aufwand (grob)

| Datei | Änderung | Aufwand |
|---|---|---|
| `BuildRunner.pas` (neu) | Prozessstart, Pipe, Threading, Fortschritts-Events | mittel–hoch |
| [BuildLogFrame.dfm/.pas](BuildLogFrame.pas) | Button, ComboBoxen, Progressbar, Status, Verdrahtung | mittel |
| [BuildLogParser.pas](BuildLogParser.pas) | zweite Regex-Familie (roh, EN/DE) | gering–mittel |
| [BuildLogCapture.pas](BuildLogCapture.pas) | nur für Fallback A relevant | gering |

---

## 11. Umsetzungs-Phasen (Vorschlag)

1. **Scope/Variante ermitteln** (ToolsAPI) + UI-Gerüst (Button, ComboBox, read-only Config/Plattform).
2. **Prozess-Runner** (`BuildRunner.pas`): `rsvars`+`msbuild` starten, stdout async lesen, Rohlog live.
3. **Fortschritt** (Marquee + Projekt-i/N + Zähler) inkl. Thread-Marshalling.
4. **Parser-Erweiterung** für Rohformat → Statistik-Tabs.
5. **Abbruch** + Fehlerbehandlung + „Save all" vor Build.
6. **Variante A als zweiter Modus** (In-IDE-Build, §9) – editions-unabhängig, auf dem
   Starter-Dev-Rechner der einzig lauffähige Weg; Modus-Umschaltung „MSBuild | IDE".

---

## 12. Offene Punkte / Risiken

- **Sprache des `msbuild`-Outputs** fixieren (EN empfohlen) – sonst Parser zweisprachig.
- **`BDS`/`rsvars` finden** robust (Env vs. `GetRootDirectory`).
- **Determinate Prozent** innerhalb eines Projekts nicht zuverlässig → Marquee.
- **Lange Builds**: UI responsiv halten, Abbruch testen, Doppel-Start verhindern.
- **Pfade mit Leerzeichen** sauber quoten.
- **Exit-Code-Mapping** auf Erfolg/Fehler konsistent mit der Statistik-Anzeige.
