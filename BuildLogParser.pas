unit BuildLogParser;

{
  Parst Delphi-Compiler-Ausgaben (dcc32/dcc64) aus dem Build-Log
  und liefert eine formatierte Statistik.

  Unterstuetzte Zeilenformate:
    [dcc64 Warnung] datei.pas(42): W1000 Symbol '...' ist veraltet
    [dcc64 Hinweis] datei.pas(42): H2443 Inline-Funktion ...
    [dcc64 Fehler]  datei.pas(42): E2003 Undeklarierter Bezeichner
    Erzeugen von rhd.dproj (Debug, Win64)
    Vergangene Zeit 00:00:17.43
    605 Warnung(en)
    0 Fehler
}

interface

uses
  System.SysUtils, System.Classes,
  System.Generics.Collections, System.Generics.Defaults,
  System.RegularExpressions, System.StrUtils, System.Math;

type
  TMessageKind = (mkFehler, mkWarnung, mkHinweis);

  TBuildMessage = record
    Kind:     TMessageKind;
    FileName: string;
    Line:     Integer;
    Code:     string;
    Text:     string;
    RawLine:  string;
  end;

  TBuildStats = class
  private
    FMessages:      TList<TBuildMessage>;
    FProjectName:   string;
    FConfig:        string;
    FPlatform:      string;
    FBuildTime:     string;
    FSuccess:       Boolean;
    FTotalErrors:   Integer;
    FTotalWarnings: Integer;
    FTotalHints:    Integer;

    procedure ParseLine(const ALine: string);
  public
    constructor Create;
    destructor Destroy; override;

    procedure Clear;
    procedure ParseFile(const AFileName: string);
    procedure ParseLines(ALines: TStrings);

    function FormatReport: string;

    property ProjectName:   string  read FProjectName;
    property Config:        string  read FConfig;
    property Platform:      string  read FPlatform;
    property BuildTime:     string  read FBuildTime;
    property Success:       Boolean read FSuccess;
    property TotalErrors:   Integer read FTotalErrors;
    property TotalWarnings: Integer read FTotalWarnings;
    property TotalHints:    Integer read FTotalHints;
    property Messages:      TList<TBuildMessage> read FMessages;
  end;

implementation

{ --------------------------------------------------------------------------- }

constructor TBuildStats.Create;
begin
  inherited;
  FMessages := TList<TBuildMessage>.Create;
  FSuccess  := True;
end;

destructor TBuildStats.Destroy;
begin
  FMessages.Free;
  inherited;
end;

procedure TBuildStats.Clear;
begin
  FMessages.Clear;
  FProjectName   := '';
  FConfig        := '';
  FPlatform      := '';
  FBuildTime     := '';
  FSuccess       := True;
  FTotalErrors   := 0;
  FTotalWarnings := 0;
  FTotalHints    := 0;
end;

{ --------------------------------------------------------------------------- }

procedure TBuildStats.ParseLine(const ALine: string);
const
  RX_DCC  = '^\s*\[dcc\d+\s+(Warnung|Hinweis|Fehler|Fatal)\]\s+(.+?)\((\d+)\):\s+([WHEF]\d+)\s+(.*)$';
  RX_PROJ = '^\s*Erzeugen von\s+(.+?\.dproj)\s+\(([^,]+),\s*([^)]+)\)';
  RX_TIME = '^\s*Vergangene Zeit\s+(\d+:\d+:\d+\.\d+)';
  RX_WARN = '^\s*(\d+)\s+Warnung\(en\)';
  RX_ERR  = '^\s*(\d+)\s+Fehler\s*$';
var
  M:   TMatch;
  Msg: TBuildMessage;
begin
  M := TRegEx.Match(ALine, RX_DCC, [roIgnoreCase]);
  if M.Success then
  begin
    Msg.Code     := M.Groups[4].Value;
    Msg.FileName := ExtractFileName(M.Groups[2].Value);
    Msg.Line     := StrToIntDef(M.Groups[3].Value, 0);
    Msg.Text     := M.Groups[5].Value;
    Msg.RawLine  := Trim(ALine);
    if SameText(M.Groups[1].Value, 'Warnung') then
      Msg.Kind := mkWarnung
    else if SameText(M.Groups[1].Value, 'Hinweis') then
      Msg.Kind := mkHinweis
    else
    begin
      Msg.Kind := mkFehler;
      FSuccess  := False;
    end;
    FMessages.Add(Msg);
    Exit;
  end;

  M := TRegEx.Match(ALine, RX_PROJ);
  if M.Success then
  begin
    FProjectName := M.Groups[1].Value;
    FConfig      := Trim(M.Groups[2].Value);
    FPlatform    := Trim(M.Groups[3].Value);
    Exit;
  end;

  M := TRegEx.Match(ALine, RX_TIME);
  if M.Success then
  begin
    FBuildTime := M.Groups[1].Value;
    Exit;
  end;

  M := TRegEx.Match(ALine, RX_WARN);
  if M.Success then
  begin
    FTotalWarnings := StrToIntDef(M.Groups[1].Value, FTotalWarnings);
    Exit;
  end;

  M := TRegEx.Match(ALine, RX_ERR);
  if M.Success then
  begin
    FTotalErrors := StrToIntDef(M.Groups[1].Value, FTotalErrors);
    if FTotalErrors > 0 then FSuccess := False;
  end;
end;

{ --------------------------------------------------------------------------- }

procedure TBuildStats.ParseFile(const AFileName: string);
var
  Lines: TStringList;
begin
  Clear;
  Lines := TStringList.Create;
  try
    Lines.LoadFromFile(AFileName, TEncoding.UTF8);
    ParseLines(Lines);
  finally
    Lines.Free;
  end;
end;

procedure TBuildStats.ParseLines(ALines: TStrings);
var
  I:   Integer;
  Msg: TBuildMessage;
begin
  for I := 0 to ALines.Count - 1 do
    ParseLine(ALines[I]);

  { Hinweise immer selbst zaehlen (kein eigener Footer-Eintrag) }
  FTotalHints := 0;
  for I := 0 to FMessages.Count - 1 do
  begin
    Msg := FMessages[I];
    if Msg.Kind = mkHinweis then
      Inc(FTotalHints);
  end;

  { Falls keine Footer-Zusammenfassung gefunden, alles selbst zaehlen }
  if (FTotalWarnings = 0) and (FTotalErrors = 0) then
  begin
    for I := 0 to FMessages.Count - 1 do
    begin
      Msg := FMessages[I];
      case Msg.Kind of
        mkWarnung: Inc(FTotalWarnings);
        mkFehler:  Inc(FTotalErrors);
      end;
    end;
  end
  else
    { Footer-Wert = Warnungen + Hinweise zusammen; Warnungen = Gesamt - Hinweise }
    FTotalWarnings := FTotalWarnings - FTotalHints;
end;

{ --------------------------------------------------------------------------- }

type
  TCountPair = TPair<string, Integer>;

function ComparePairsDesc(const A, B: TCountPair): Integer;
begin
  Result := B.Value - A.Value;
end;

function TBuildStats.FormatReport: string;
const
  LINE  = '---------------------------------------------';
  TOP_N = 10;

  function PadRight(const S: string; W: Integer): string;
  begin
    Result := S + StringOfChar(' ', Max(0, W - Length(S)));
  end;

  procedure SortedPairs(Dict: TDictionary<string, Integer>;
    out Pairs: TArray<TCountPair>);
  begin
    Pairs := Dict.ToArray;
    TArray.Sort<TCountPair>(Pairs,
      TComparer<TCountPair>.Construct(ComparePairsDesc));
  end;

  procedure AppendTop(SL: TStringList; Dict: TDictionary<string, Integer>;
    DescDict: TDictionary<string, string>; FileW: Integer);
  var
    Pairs: TArray<TCountPair>;
    I:     Integer;
    Desc:  string;
  begin
    SortedPairs(Dict, Pairs);
    for I := 0 to Min(TOP_N - 1, High(Pairs)) do
    begin
      Desc := '';
      if Assigned(DescDict) then
      begin
        if not DescDict.TryGetValue(Pairs[I].Key, Desc) then Desc := '';
        if Length(Desc) > 38 then Desc := Copy(Desc, 1, 38) + '...';
      end;
      if FileW > 0 then
        SL.Add(Format('  %-40s %4dx', [PadRight(Pairs[I].Key, 40), Pairs[I].Value]))
      else
        SL.Add(Format('  %s  %4dx   %s', [PadRight(Pairs[I].Key, 6), Pairs[I].Value, Desc]));
    end;
  end;

var
  SL:        TStringList;
  CodeCount: TDictionary<string, Integer>;
  CodeDesc:  TDictionary<string, string>;
  FileWarn:  TDictionary<string, Integer>;
  FileHint:  TDictionary<string, Integer>;
  SymCount:  TDictionary<string, Integer>;
  I:         Integer;
  Msg:       TBuildMessage;
  TimeStr:   string;
  Parts:     TArray<string>;
  SP:        TArray<string>;
  H, Min_, S_, Ms: Integer;
  Secs:      Double;
  P1, P2:   Integer;
  Sym:       string;
begin
  SL        := TStringList.Create;
  CodeCount := TDictionary<string, Integer>.Create;
  CodeDesc  := TDictionary<string, string>.Create;
  FileWarn  := TDictionary<string, Integer>.Create;
  FileHint  := TDictionary<string, Integer>.Create;
  SymCount  := TDictionary<string, Integer>.Create;
  try
    for I := 0 to FMessages.Count - 1 do
    begin
      Msg := FMessages[I];

      { Code-Zaehler }
      if CodeCount.ContainsKey(Msg.Code) then
        CodeCount[Msg.Code] := CodeCount[Msg.Code] + 1
      else
      begin
        CodeCount.Add(Msg.Code, 1);
        CodeDesc.Add(Msg.Code, Msg.Text);
      end;

      { Datei-Zaehler }
      if Msg.Kind = mkWarnung then
      begin
        if FileWarn.ContainsKey(Msg.FileName) then
          FileWarn[Msg.FileName] := FileWarn[Msg.FileName] + 1
        else
          FileWarn.Add(Msg.FileName, 1);
      end
      else if Msg.Kind = mkHinweis then
      begin
        if FileHint.ContainsKey(Msg.FileName) then
          FileHint[Msg.FileName] := FileHint[Msg.FileName] + 1
        else
          FileHint.Add(Msg.FileName, 1);
      end;

      { Veraltete Symbole aus W1000-Zeilen extrahieren }
      if Msg.Code = 'W1000' then
      begin
        P1 := Pos('''', Msg.Text);
        if P1 > 0 then
        begin
          Inc(P1);
          P2 := Pos('''', Msg.Text, P1);
          if P2 > P1 then
          begin
            Sym := Copy(Msg.Text, P1, P2 - P1);
            if SymCount.ContainsKey(Sym) then
              SymCount[Sym] := SymCount[Sym] + 1
            else
              SymCount.Add(Sym, 1);
          end;
        end;
      end;
    end;

    { --- Kopfzeile --- }
    SL.Add('BUILD LOG STATISTIK');
    SL.Add('===========================================');
    SL.Add('');
    SL.Add('Projekt:        ' + IfThen(FProjectName <> '', FProjectName, '(unbekannt)'));
    SL.Add('Konfiguration:  ' + IfThen(FConfig    <> '', FConfig,    '-'));
    SL.Add('Plattform:      ' + IfThen(FPlatform  <> '', FPlatform,  '-'));

    TimeStr := FBuildTime;
    if TimeStr <> '' then
    begin
      Parts := TimeStr.Split([':']);
      if Length(Parts) = 3 then
      begin
        H    := StrToIntDef(Parts[0], 0);
        Min_ := StrToIntDef(Parts[1], 0);
        SP   := Parts[2].Split(['.']);
        if Length(SP) >= 2 then
        begin
          S_   := StrToIntDef(SP[0], 0);
          Ms   := StrToIntDef(SP[1], 0);
          Secs := H * 3600 + Min_ * 60 + S_ + Ms / 100.0;
          TimeStr := Format('%.2f s  (%s)', [Secs, FBuildTime]);
        end;
      end;
    end;
    SL.Add('Bauzeit:        ' + IfThen(TimeStr <> '', TimeStr, '-'));
    SL.Add('Ergebnis:       ' + IfThen(FSuccess, 'ERFOLG', 'FEHLER'));

    { --- Meldungszahlen --- }
    SL.Add('');
    SL.Add('MELDUNGEN');
    SL.Add(LINE);
    SL.Add(Format('  Fehler:      %d', [FTotalErrors]));
    SL.Add(Format('  Warnungen:   %d', [FTotalWarnings]));
    SL.Add(Format('  Hinweise:    %d', [FTotalHints]));
    SL.Add(Format('  Gesamt:      %d', [FTotalErrors + FTotalWarnings + FTotalHints]));

    { --- Top Codes --- }
    SL.Add('');
    SL.Add('HAEUFIGSTE CODES');
    SL.Add(LINE);
    AppendTop(SL, CodeCount, CodeDesc, 0);

    { --- Veraltete Symbole --- }
    if SymCount.Count > 0 then
    begin
      SL.Add('');
      SL.Add('VERALTETE SYMBOLE (W1000)');
      SL.Add(LINE);
      AppendTop(SL, SymCount, nil, 0);
    end;

    { --- Top Dateien Warnungen --- }
    if FileWarn.Count > 0 then
    begin
      SL.Add('');
      SL.Add('DATEIEN MIT MEISTEN WARNUNGEN');
      SL.Add(LINE);
      AppendTop(SL, FileWarn, nil, 1);
    end;

    { --- Top Dateien Hinweise --- }
    if FileHint.Count > 0 then
    begin
      SL.Add('');
      SL.Add('DATEIEN MIT MEISTEN HINWEISEN');
      SL.Add(LINE);
      AppendTop(SL, FileHint, nil, 1);
    end;

    SL.Add('');
    SL.Add('===========================================');

    Result := SL.Text;
  finally
    SL.Free;
    CodeCount.Free;
    CodeDesc.Free;
    FileWarn.Free;
    FileHint.Free;
    SymCount.Free;
  end;
end;

end.
