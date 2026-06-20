unit BuildLogHints;

{
  Fix-Vorschlaege fuer bekannte Delphi-Compiler-Codes (dcc32/dcc64).
  Wird im BuildLog-Fenster angezeigt, wenn ein Code gefiltert wird.
}

interface

function GetHintForCode(const ACode: string): string;

implementation

uses
  System.SysUtils, System.Generics.Collections;

var
  GHints: TDictionary<string, string>;

procedure InitHints;
begin
  GHints := TDictionary<string, string>.Create;

  { ------------------------------------------------------------------ }
  {  Warnungen                                                           }
  { ------------------------------------------------------------------ }

  GHints.Add('W1000',
    'Symbol ist veraltet - ersetzen Sie es durch die empfohlene Alternative:' + sLineBreak +
    '  StartTransaction  ->  Connection.BeginTrans' + sLineBreak +
    '  Commit            ->  Connection.CommitTrans' + sLineBreak +
    '  Rollback          ->  Connection.RollbackTrans' + sLineBreak +
    '  Suspend/Resume    ->  Synchronisierungsobjekte (TEvent, TCriticalSection)' + sLineBreak +
    '  StrPas/StrPCopy   ->  Entsprechende SysUtils-Funktionen' + sLineBreak +
    '  FileAge(string)   ->  FileAge(string, TDateTime)');

  GHints.Add('W1010',
    'Methode verbirgt eine virtuelle Methode des Basistyps.' + sLineBreak +
    'Loesungen:' + sLineBreak +
    '  1. Beabsichtigt: fuegen Sie "reintroduce" hinzu:' + sLineBreak +
    '       procedure ToString: string; reintroduce;' + sLineBreak +
    '  2. Nicht beabsichtigt: Methode umbenennen.' + sLineBreak +
    '  3. Basisklassen-Methode ueberschreiben: "override" verwenden.');

  GHints.Add('W1035',
    'Rueckgabewert der Funktion ist nicht in allen Pfaden definiert.' + sLineBreak +
    'Loesung: Result am Anfang initialisieren:' + sLineBreak +
    '  Result := Default(ReturnType);  // generisch' + sLineBreak +
    '  Result := nil;   // fuer Objekte/Zeiger' + sLineBreak +
    '  Result := False; // fuer Boolean' + sLineBreak +
    '  Result := 0;     // fuer Integer');

  GHints.Add('W1036',
    'Variable wird moeglicherweise ohne Initialisierung verwendet.' + sLineBreak +
    'Loesung: Variable vor der ersten Verwendung initialisieren:' + sLineBreak +
    '  MyVar := Default(TVarType);' + sLineBreak +
    '  MyVar := 0;  // fuer Integer/Float' + sLineBreak +
    '  MyVar := '''';  // fuer String');

  GHints.Add('W1037',
    'Konstantes Objekt wird als var-Parameter uebergeben.' + sLineBreak +
    'Loesungen:' + sLineBreak +
    '  1. Parameter von "var" auf "const" aendern (wenn moeglich).' + sLineBreak +
    '  2. Eine lokale Variable als Zwischenpuffer verwenden.' + sLineBreak +
    '  3. Explizite Typumwandlung mit Variable:' + sLineBreak +
    '       var Tmp: TType := Konstante;  DoSomething(Tmp);');

  GHints.Add('W1044',
    'Bedenkliche Typumwandlung von string nach PAnsiChar.' + sLineBreak +
    'Loesung: Explizit ueber AnsiString konvertieren:' + sLineBreak +
    '  PAnsiChar(AnsiString(MyString))' + sLineBreak +
    'Oder die API durch eine Unicode-faehige Variante ersetzen.');

  GHints.Add('W1050',
    'WideChar (Char) kann nicht direkt in Set-Ausdruecken verwendet werden.' + sLineBreak +
    'Loesung: CharInSet aus System.SysUtils verwenden:' + sLineBreak +
    '  Vorher:  if C in [''a''..''z'', ''A''..''Z''] then' + sLineBreak +
    '  Nachher: if CharInSet(C, [''a''..''z'', ''A''..''Z'']) then' + sLineBreak +
    'Stellen Sie sicher, dass System.SysUtils in der uses-Klausel steht.');

  GHints.Add('W1055',
    'PUBLISHED hat RTTI ($M+) zum Typ hinzugefuegt.' + sLineBreak +
    'Loesungen:' + sLineBreak +
    '  1. Klasse von TPersistent ableiten (traegt RTTI bereits).' + sLineBreak +
    '  2. {$M+} explizit vor der Klassendefinition setzen.' + sLineBreak +
    '  3. Wenn RTTI nicht benoetigt wird: published in public aendern.');

  GHints.Add('W1057',
    'Implizite Konvertierung von AnsiChar nach string.' + sLineBreak +
    'Loesung: Explizit konvertieren:' + sLineBreak +
    '  string(MyAnsiChar)   // AnsiChar -> string' + sLineBreak +
    '  Char(MyAnsiChar)     // AnsiChar -> WideChar' + sLineBreak +
    'Oder den Code auf Unicode-Strings umstellen.');

  GHints.Add('W1058',
    'Implizite String-Konvertierung mit potenziellem Datenverlust (string -> AnsiString).' + sLineBreak +
    'Loesung: Explizit konvertieren:' + sLineBreak +
    '  AnsiString(MyString)          // direkte Umwandlung' + sLineBreak +
    '  UTF8Encode(MyString)          // fuer UTF-8-Kontext' + sLineBreak +
    'Pruefe ob die API wirklich AnsiString erfordert oder Unicode-Variante verfuegbar ist.');

  { ------------------------------------------------------------------ }
  {  Hinweise                                                            }
  { ------------------------------------------------------------------ }

  GHints.Add('H2077',
    'Ein zugewiesener Wert wird nie gelesen (Dead Assignment).' + sLineBreak +
    'Loesungen:' + sLineBreak +
    '  1. Zuweisung entfernen, wenn sie keinen Effekt hat.' + sLineBreak +
    '  2. Pruefen ob eine Exit-Bedingung fehlt.' + sLineBreak +
    '  3. Pruefen ob Result falsch initialisiert wird (Funktion).');

  GHints.Add('H2164',
    'Variable wird deklariert aber nie verwendet.' + sLineBreak +
    'Loesungen:' + sLineBreak +
    '  1. Variable entfernen.' + sLineBreak +
    '  2. Mit {$WARN SYMBOL_DEPRECATED OFF} unterdruecken (nicht empfohlen).' + sLineBreak +
    '  3. Pruefen ob die Variable versehentlich nicht gesetzt wird.');

  GHints.Add('H2219',
    'Privates Symbol (Methode/Feld) ist deklariert aber wird nie verwendet.' + sLineBreak +
    'Loesungen:' + sLineBreak +
    '  1. Symbol entfernen.' + sLineBreak +
    '  2. Pruefen ob es irrtuemlicherweise nicht aufgerufen wird.' + sLineBreak +
    '  3. Sichtbarkeit auf public erhoehen, wenn beabsichtigt.');

  GHints.Add('H2365',
    'Compiler-Direktive ist nicht standardisiert.' + sLineBreak +
    'Loesungen:' + sLineBreak +
    '  1. Schreibweise der Direktive pruefen (Gross-/Kleinschreibung).' + sLineBreak +
    '  2. Sicherstellen, dass die Direktive in dieser Delphi-Version unterstuetzt wird.');

  GHints.Add('H2443',
    'Inline-Funktion konnte nicht expandiert werden, weil eine Unit in der uses-Klausel fehlt.' + sLineBreak +
    'Haeufige Faelle und Loesungen:' + sLineBreak +
    '  MessageDlg / MessageDlgPos  ->  System.UITypes zur uses-Liste hinzufuegen' + sLineBreak +
    '  TDataSet.IsEmpty            ->  Data.DB hinzufuegen' + sLineBreak +
    '  TDataSet.Active             ->  Data.DB hinzufuegen' + sLineBreak +
    'Die fehlende Unit in der uses-Klausel der .pas-Datei erganzen.');

  GHints.Add('H2161',
    'Doppelte Resource gefunden; eine wird verworfen.' + sLineBreak +
    'Loesung: Pruefen Sie ob mehrere .res-Dateien dieselbe Resource (z.B. VERSIONINFO) enthalten.' + sLineBreak +
    'Haeufige Ursache: midas.res wird doppelt eingebunden. Enfernen Sie den expliziten' + sLineBreak +
    'Link auf midas.res oder schliessen Sie die Konflikt-Bibliothek aus.');

  { ------------------------------------------------------------------ }
  {  Fehler                                                              }
  { ------------------------------------------------------------------ }

  GHints.Add('E2003',
    'Undeklarierter Bezeichner - der verwendete Name ist nicht sichtbar.' + sLineBreak +
    'Loesungen:' + sLineBreak +
    '  1. Fehlende Unit in der uses-Klausel erganzen.' + sLineBreak +
    '  2. Tippfehler im Bezeichnernamen pruefen.' + sLineBreak +
    '  3. Sichtbarkeitsbereich (private/protected/public) pruefen.' + sLineBreak +
    '  4. Circular-Unit-Dependency aufloesen (Interface/Implementation uses trennen).');

  GHints.Add('E2010',
    'Inkompatible Typen - Ziel- und Quelltyp passen nicht zusammen.' + sLineBreak +
    'Loesungen:' + sLineBreak +
    '  1. Explizite Typumwandlung verwenden: TargetType(Value)' + sLineBreak +
    '  2. Pruefen ob ein Zeiger dereferenziert werden muss.' + sLineBreak +
    '  3. Overloaded-Operator oder Konvertierungsfunktion verwenden.');

  GHints.Add('E2555',
    'Lokale Funktion/Prozedur kann nicht in einer anonymen Methode erfasst werden.' + sLineBreak +
    'Loesung: Logik direkt in die anonyme Methode inline schreiben.' + sLineBreak +
    'Lokale Variablen (Integer, string, etc.) koennen erfasst werden - lokale' + sLineBreak +
    'Unterprogramme jedoch nicht. Alternativ als Klassenmethode auslagern.');
end;

{ --------------------------------------------------------------------------- }

function GetHintForCode(const ACode: string): string;
begin
  if not GHints.TryGetValue(UpperCase(ACode), Result) then
    Result := '';
end;

initialization
  InitHints;

finalization
  GHints.Free;

end.
