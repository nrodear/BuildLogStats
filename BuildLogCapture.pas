unit BuildLogCapture;

{
  Koppelt den BuildLog-Plugin an den IDE-Kompilierungsvorgang.

  Mechanismus A – IOTAToolsFilterNotifier (deprecated seit MSBuild):
    Empfaengt rohen Compiler-Stdout. In Delphi 12 in der Regel nicht aktiv.

  Mechanismus B – IOTACompileNotifier + ScanForLogFile:
    Merkt sich beim Build-Start alle Projektverzeichnisse.
    Nach dem Build wird die juengste *.log-/  *.all-Datei gesucht und geladen.
    Durchsucht: Projektgruppenverzeichnis, uebergeordnetes Verzeichnis sowie
    die Verzeichnisse jedes einzelnen Projekts in der Gruppe.
}

interface

uses
  System.SysUtils, System.Classes, System.IOUtils,
  ToolsAPI;

type
  TBuildCapture = class(TInterfacedObject, IOTAToolsFilterNotifier, IOTACompileNotifier)
  private
    FLines:        TStringList;
    FProjectDirs:  TStringList;
    FFoundFile:    string;
    FFilterIdx:    Integer;
    FCompileIdx:   Integer;
    FInGroupBuild: Boolean;

    procedure CollectProjectDirs;
    procedure FindNewestLogFile(out AFile: string);
    procedure WriteBridgeResult(AResult: TOTACompileResult);
  public
    constructor Create;
    destructor Destroy; override;

    procedure RegisterNotifiers;
    procedure UnregisterNotifiers;
    procedure ScanForLogFile;

    { IOTANotifier }
    procedure AfterSave;
    procedure BeforeSave;
    procedure Destroyed;

    procedure Modified;

    { IOTAToolsFilterNotifier }
    procedure Filter(FileName: string; ErrorCode: Integer;
      StdOut, StdError: TStrings);
    function GetFilterName: string;

    { IOTACompileNotifier }
    procedure ProjectCompileStarted(const Project: IOTAProject;
      Mode: TOTACompileMode);
    procedure ProjectCompileFinished(const Project: IOTAProject;
      Result: TOTACompileResult);
    procedure ProjectGroupCompileStarted(Mode: TOTACompileMode);
    procedure ProjectGroupCompileFinished(Result: TOTACompileResult);

    property Lines:     TStringList read FLines;
    property FoundFile: string      read FFoundFile;
  end;

var
  GBuildCapture: TBuildCapture = nil;

implementation

{ --------------------------------------------------------------------------- }

constructor TBuildCapture.Create;
begin
  inherited;
  FLines       := TStringList.Create;
  FProjectDirs := TStringList.Create;
  FProjectDirs.CaseSensitive := False;
  FProjectDirs.Duplicates    := dupIgnore;
  FProjectDirs.Sorted        := True;
  FFilterIdx   := -1;
  FCompileIdx  := -1;
end;

destructor TBuildCapture.Destroy;
begin
  FProjectDirs.Free;
  FLines.Free;
  inherited;
end;

{ --------------------------------------------------------------------------- }
{  Registrierung                                                               }
{ --------------------------------------------------------------------------- }

procedure TBuildCapture.RegisterNotifiers;
var
  Filter:  IOTAToolsFilter;
  Compile: IOTACompileServices;
begin
  {$WARN SYMBOL_DEPRECATED OFF}
  if Supports(BorlandIDEServices, IOTAToolsFilter, Filter) then
    FFilterIdx := Filter.AddNotifier(Self as IOTANotifier);
  {$WARN SYMBOL_DEPRECATED ON}

  if Supports(BorlandIDEServices, IOTACompileServices, Compile) then
    FCompileIdx := Compile.AddNotifier(Self as IOTACompileNotifier);
end;

procedure TBuildCapture.UnregisterNotifiers;
var
  Filter:  IOTAToolsFilter;
  Compile: IOTACompileServices;
begin
  {$WARN SYMBOL_DEPRECATED OFF}
  if (FFilterIdx >= 0) and Supports(BorlandIDEServices, IOTAToolsFilter, Filter) then
  begin
    Filter.RemoveNotifier(FFilterIdx);
    FFilterIdx := -1;
  end;
  {$WARN SYMBOL_DEPRECATED ON}

  if (FCompileIdx >= 0) and Supports(BorlandIDEServices, IOTACompileServices, Compile) then
  begin
    Compile.RemoveNotifier(FCompileIdx);
    FCompileIdx := -1;
  end;
end;

{ --------------------------------------------------------------------------- }
{  Verzeichnisse sammeln + Datei suchen                                       }
{ --------------------------------------------------------------------------- }

procedure TBuildCapture.CollectProjectDirs;
var
  ModSvc:    IOTAModuleServices;
  ProjGroup: IOTAProjectGroup;
  Project:   IOTAProject;
  Dir:       string;
  I, J:      Integer;
begin
  FProjectDirs.Clear;
  if not Supports(BorlandIDEServices, IOTAModuleServices, ModSvc) then Exit;

  for I := 0 to ModSvc.ModuleCount - 1 do
    if Supports(ModSvc.Modules[I], IOTAProjectGroup, ProjGroup) then
    begin
      Dir := IncludeTrailingPathDelimiter(ExtractFilePath(ProjGroup.FileName));
      FProjectDirs.Add(Dir);
      Dir := IncludeTrailingPathDelimiter(
               ExtractFilePath(ExcludeTrailingPathDelimiter(
                 ExtractFilePath(ProjGroup.FileName))));
      FProjectDirs.Add(Dir);
      for J := 0 to ProjGroup.ProjectCount - 1 do
      begin
        Project := ProjGroup.Projects[J];
        if Project.FileName <> '' then
          FProjectDirs.Add(IncludeTrailingPathDelimiter(
            ExtractFilePath(Project.FileName)));
      end;
      Break;
    end;
end;

procedure TBuildCapture.FindNewestLogFile(out AFile: string);
var
  SR:   TSearchRec;
  Age:  TDateTime;
  Best: TDateTime;
  Dir:  string;
  Ext:  string;
  I:    Integer;
begin
  AFile := '';
  Best  := 0;
  for I := 0 to FProjectDirs.Count - 1 do
  begin
    Dir := FProjectDirs[I];
    if not DirectoryExists(Dir) then Continue;
    for Ext in ['.log', '.all'] do
    begin
      if FindFirst(Dir + '*' + Ext, faAnyFile, SR) = 0 then
      try
        repeat
          if FileAge(Dir + SR.Name, Age) and (Age > Best) then
          begin
            Best  := Age;
            AFile := Dir + SR.Name;
          end;
        until FindNext(SR) <> 0;
      finally
        System.SysUtils.FindClose(SR);
      end;
    end;
  end;
end;

procedure TBuildCapture.ScanForLogFile;
var
  Found: string;
begin
  if FProjectDirs.Count = 0 then
    CollectProjectDirs;
  if FProjectDirs.Count = 0 then Exit;
  FindNewestLogFile(Found);
  FFoundFile := Found;
  if Found <> '' then
    FLines.LoadFromFile(Found, TEncoding.UTF8);
end;

{ --------------------------------------------------------------------------- }
{  VS-Code-Bridge: Ergebnis + Log in %TEMP%\DelphiBuildBridge ablegen          }
{                                                                              }
{  Der VS-Code-Task loescht build.status/build.log, triggert den Build per     }
{  Tastendruck und wartet auf das Wiederauftauchen von build.status.           }
{  build.status wird ZULETZT geschrieben -> dessen Existenz heisst "fertig".   }
{ --------------------------------------------------------------------------- }

procedure TBuildCapture.WriteBridgeResult(AResult: TOTACompileResult);
var
  Dir:    string;
  Status: string;
begin
  Dir := TPath.Combine(TPath.GetTempPath, 'DelphiBuildBridge');
  try
    if not TDirectory.Exists(Dir) then
      TDirectory.CreateDirectory(Dir);

    // 1) Compiler-/Messages-Log zuerst schreiben
    FLines.SaveToFile(TPath.Combine(Dir, 'build.log'), TEncoding.UTF8);

    // 2) Status zuletzt -> Existenz signalisiert dem Task "Build fertig"
    case AResult of
      crOTASucceeded:  Status := 'SUCCEEDED';
      crOTAFailed:     Status := 'FAILED';
      crOTABackground: Status := 'BACKGROUND';
    else
      Status := 'UNKNOWN';
    end;
    TFile.WriteAllText(
      TPath.Combine(Dir, 'build.status'),
      Status + sLineBreak + FormatDateTime('yyyy-mm-dd hh:nn:ss', Now) + sLineBreak,
      TEncoding.UTF8);
  except
    // Die Bridge darf den Build niemals stoeren
  end;
end;

{ --------------------------------------------------------------------------- }
{  IOTANotifier (No-ops)                                                       }
{ --------------------------------------------------------------------------- }

procedure TBuildCapture.AfterSave;  begin end;
procedure TBuildCapture.BeforeSave; begin end;
procedure TBuildCapture.Modified;   begin end;

procedure TBuildCapture.Destroyed;
begin
  FFilterIdx  := -1;
  FCompileIdx := -1;
end;

{ --------------------------------------------------------------------------- }
{  IOTAToolsFilterNotifier                                                     }
{ --------------------------------------------------------------------------- }

procedure TBuildCapture.Filter(FileName: string; ErrorCode: Integer;
  StdOut, StdError: TStrings);
begin
  if Assigned(StdOut) then FLines.AddStrings(StdOut);
  if Assigned(StdError) and (StdError.Count > 0) then
    FLines.AddStrings(StdError);
end;

function TBuildCapture.GetFilterName: string;
begin
  Result := 'BuildLog_Plugin';
end;

{ --------------------------------------------------------------------------- }
{  IOTACompileNotifier                                                         }
{ --------------------------------------------------------------------------- }

procedure TBuildCapture.ProjectGroupCompileStarted(Mode: TOTACompileMode);
begin
  FInGroupBuild := True;
  FLines.Clear;
  FFoundFile := '';
  CollectProjectDirs;
end;

procedure TBuildCapture.ProjectGroupCompileFinished(Result: TOTACompileResult);
begin
  if FLines.Count = 0 then
    ScanForLogFile;
  WriteBridgeResult(Result);
  FInGroupBuild := False;
end;

procedure TBuildCapture.ProjectCompileStarted(const Project: IOTAProject;
  Mode: TOTACompileMode);
begin
  // Einzelprojekt-Build (Umschalt+F9 auf aktivem Projekt) ist nicht Teil eines
  // Gruppen-Builds -> hier selbst initialisieren.
  if not FInGroupBuild then
  begin
    FLines.Clear;
    FFoundFile := '';
    CollectProjectDirs;
  end;
end;

procedure TBuildCapture.ProjectCompileFinished(const Project: IOTAProject;
  Result: TOTACompileResult);
begin
  if not FInGroupBuild then
  begin
    if FLines.Count = 0 then
      ScanForLogFile;
    WriteBridgeResult(Result);
  end;
end;

end.
