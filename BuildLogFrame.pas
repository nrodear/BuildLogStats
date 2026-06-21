unit BuildLogFrame;

interface

uses
  Winapi.Windows,
  System.SysUtils, System.Classes, System.IniFiles, System.Types,
  System.Generics.Collections, System.Generics.Defaults,
  Vcl.Controls, Vcl.Forms, Vcl.StdCtrls, Vcl.ExtCtrls,
  Vcl.ComCtrls, Vcl.Dialogs, Vcl.Menus,
  ToolsAPI,
  BuildLogParser, BuildLogHints, BuildLogCapture;

type
  TCodeRow = record
    Code:  string;
    Kind:  TMessageKind;
    Count: Integer;
    Desc:  string;
  end;

  TBuildLogFrame = class(TFrame)
    pnlTop:         TPanel;
    btnOpen:        TButton;
    btnClear:       TButton;
    lblInfo:        TLabel;
    lblErrorSummary: TLabel;
    pgcMain:        TPageControl;
    tsStatistik:    TTabSheet;
    memoStats:      TMemo;
    tsFehlercodes:  TTabSheet;
    lvCodes:        TListView;
    tsCode:         TTabSheet;
    pnlCodeFilter:  TPanel;
    lblCodeFilter:  TLabel;
    cmbCode:        TComboBox;
    btnFilter:      TButton;
    lblCodeCount:   TLabel;
    pnlHint:        TPanel;
    lblHintTitle:   TLabel;
    memoHint:       TMemo;
    lvCodeResult:   TListView;
    pnlRawLine:     TPanel;
    memoRawLine:    TMemo;
    pnlStatus:      TPanel;
    lblStatus:      TLabel;
    tsRohlog:       TTabSheet;
    memoLog:        TMemo;
    dlgOpen:        TOpenDialog;
    mnuRecent:      TPopupMenu;
    btnRecent:      TButton;
    cmbScope:       TComboBox;
    btnBuild:       TButton;
    pbBuild:        TProgressBar;
    lblBuildScope:  TLabel;
    lblBuildStatus: TLabel;
    procedure btnOpenClick(Sender: TObject);
    procedure btnClearClick(Sender: TObject);
    procedure btnRecentClick(Sender: TObject);
    procedure lvCodesColumnClick(Sender: TObject; Column: TListColumn);
    procedure btnFilterClick(Sender: TObject);
    procedure cmbCodeChange(Sender: TObject);
    procedure lvCodeResultColumnClick(Sender: TObject; Column: TListColumn);
    procedure lvCodeResultDblClick(Sender: TObject);
    procedure lvCodeResultSelectItem(Sender: TObject; Item: TListItem; Selected: Boolean);
    procedure btnFromIDEClick(Sender: TObject);
    procedure btnBuildClick(Sender: TObject);
  private
    FStats:       TBuildStats;
    FCodeRows:    TArray<TCodeRow>;
    FSortCol:     Integer;
    FSortAsc:     Boolean;
    FCodeSortCol: Integer;
    FCodeSortAsc: Boolean;
    FCodeMsgs:    TArray<TBuildMessage>;
    FRecentFiles: TStringList;
    function  RunMSBuild(const ATarget, AConfig, APlatform, ALogFile: string): Boolean;
    procedure LoadCapturedLog;
    procedure LoadRecentFiles;
    procedure SaveRecentFiles;
    procedure AddRecentFile(const AFileName: string);
    procedure BuildRecentMenu;
    procedure RecentMenuClick(Sender: TObject);
    procedure ShowStats;
    procedure BuildCodeRows;
    procedure ApplySortAndFill;
    procedure PopulateCodeCombo;
    procedure FilterByCode(const ACode: string);
    procedure ApplyCodeSort;
    function  FindFileInProjectGroup(const AFileName: string): string;
    procedure OpenAndNavigate(const AFullPath: string; ALine: Integer);
  public
    constructor Create(AOwner: TComponent); override;
    destructor Destroy; override;
    procedure LoadFromFile(const AFileName: string; AddToRecent: Boolean = True);
    procedure LoadFromCapture;
    procedure Clear;
  end;

implementation

{$R *.dfm}

const
  KindLabel: array[TMessageKind] of string = ('Fehler', 'Warnung', 'Hinweis');

{ --------------------------------------------------------------------------- }

constructor TBuildLogFrame.Create(AOwner: TComponent);
begin
  inherited;
  FStats       := TBuildStats.Create;
  FSortCol     := 2;
  FSortAsc     := False;
  FRecentFiles := TStringList.Create;
  LoadRecentFiles;
  BuildRecentMenu;
end;

destructor TBuildLogFrame.Destroy;
begin
  SaveRecentFiles;
  FRecentFiles.Free;
  FStats.Free;
  inherited;
end;

{ --------------------------------------------------------------------------- }
{  Recent Files                                                                }
{ --------------------------------------------------------------------------- }

const
  MAX_RECENT   = 10;
  RECENT_SECTION = 'RecentFiles';

function RecentIniPath: string;
begin
  Result := IncludeTrailingPathDelimiter(GetEnvironmentVariable('APPDATA'))
            + 'BuildLogStats\recent.ini';
end;

procedure TBuildLogFrame.LoadRecentFiles;
var
  Ini: TIniFile;
  I:   Integer;
  FN:  string;
begin
  FRecentFiles.Clear;
  if not FileExists(RecentIniPath) then Exit;
  Ini := TIniFile.Create(RecentIniPath);
  try
    for I := 0 to MAX_RECENT - 1 do
    begin
      FN := Ini.ReadString(RECENT_SECTION, 'File' + IntToStr(I), '');
      if (FN <> '') and FileExists(FN) then
        FRecentFiles.Add(FN);
    end;
  finally
    Ini.Free;
  end;
end;

procedure TBuildLogFrame.SaveRecentFiles;
var
  Ini: TIniFile;
  Dir: string;
  I:   Integer;
begin
  Dir := ExtractFilePath(RecentIniPath);
  if not DirectoryExists(Dir) then
    ForceDirectories(Dir);
  Ini := TIniFile.Create(RecentIniPath);
  try
    Ini.EraseSection(RECENT_SECTION);
    for I := 0 to FRecentFiles.Count - 1 do
      Ini.WriteString(RECENT_SECTION, 'File' + IntToStr(I), FRecentFiles[I]);
  finally
    Ini.Free;
  end;
end;

procedure TBuildLogFrame.AddRecentFile(const AFileName: string);
var
  Idx: Integer;
begin
  Idx := FRecentFiles.IndexOf(AFileName);
  if Idx >= 0 then
    FRecentFiles.Delete(Idx);
  FRecentFiles.Insert(0, AFileName);
  while FRecentFiles.Count > MAX_RECENT do
    FRecentFiles.Delete(FRecentFiles.Count - 1);
  SaveRecentFiles;
  BuildRecentMenu;
end;

procedure TBuildLogFrame.BuildRecentMenu;
var
  I:    Integer;
  Item: TMenuItem;
begin
  mnuRecent.Items.Clear;
  if FRecentFiles.Count = 0 then
  begin
    Item         := TMenuItem.Create(mnuRecent);
    Item.Caption := '(keine)';
    Item.Enabled := False;
    mnuRecent.Items.Add(Item);
    Exit;
  end;
  for I := 0 to FRecentFiles.Count - 1 do
  begin
    Item        := TMenuItem.Create(mnuRecent);
    Item.Caption := Format('&%d  %s', [I + 1, FRecentFiles[I]]);
    Item.Tag    := I;
    Item.OnClick := RecentMenuClick;
    mnuRecent.Items.Add(Item);
  end;
end;

procedure TBuildLogFrame.RecentMenuClick(Sender: TObject);
var
  Idx: Integer;
begin
  Idx := (Sender as TMenuItem).Tag;
  if (Idx >= 0) and (Idx < FRecentFiles.Count) then
    LoadFromFile(FRecentFiles[Idx]);
end;

procedure TBuildLogFrame.btnRecentClick(Sender: TObject);
var
  Pt: TPoint;
begin
  BuildRecentMenu;
  Pt := btnRecent.ClientToScreen(Point(0, btnRecent.Height));
  mnuRecent.Popup(Pt.X, Pt.Y);
end;

{ --------------------------------------------------------------------------- }

procedure TBuildLogFrame.btnOpenClick(Sender: TObject);
begin
  if dlgOpen.Execute then
    LoadFromFile(dlgOpen.FileName);
end;

procedure TBuildLogFrame.btnClearClick(Sender: TObject);
begin
  Clear;
end;

procedure TBuildLogFrame.LoadFromCapture;
begin
  if (GBuildCapture = nil) or (GBuildCapture.FoundFile = '') then Exit;
  LoadFromFile(GBuildCapture.FoundFile);
  lblErrorSummary.Caption := Format('%d Fehler  |  %d Warnungen  |  %d Hinweise',
    [FStats.TotalErrors, FStats.TotalWarnings, FStats.TotalHints]);
end;

procedure TBuildLogFrame.btnFromIDEClick(Sender: TObject);
begin
  LoadCapturedLog;
end;

procedure TBuildLogFrame.LoadCapturedLog;
begin
  if GBuildCapture = nil then Exit;

  if GBuildCapture.Lines.Count = 0 then
    GBuildCapture.ScanForLogFile;

  if GBuildCapture.Lines.Count = 0 then
  begin
    if GBuildCapture.FoundFile = '' then
      lblStatus.Caption := 'Keine Log-Datei gefunden. Bitte zuerst einen Build starten.'
    else
      lblStatus.Caption := Format('Datei leer: %s', [GBuildCapture.FoundFile]);
    Exit;
  end;

  Screen.Cursor := crHourGlass;
  try
    memoLog.Lines.BeginUpdate;
    try
      memoLog.Lines.Assign(GBuildCapture.Lines);
    finally
      memoLog.Lines.EndUpdate;
    end;

    FStats.Clear;
    FStats.ParseLines(GBuildCapture.Lines);
    ShowStats;
    BuildCodeRows;
    ApplySortAndFill;
    PopulateCodeCombo;
    if cmbCode.Items.Count > 0 then
      FilterByCode(cmbCode.Items[0]);

    lblInfo.Caption := Format('%s', [ExtractFileName(GBuildCapture.FoundFile)]);
    lblErrorSummary.Caption := Format('%d Fehler  |  %d Warnungen  |  %d Hinweise',
      [FStats.TotalErrors, FStats.TotalWarnings, FStats.TotalHints]);
    lblStatus.Caption := '';
    pgcMain.ActivePage := tsCode;
  finally
    Screen.Cursor := crDefault;
  end;
end;

function TBuildLogFrame.RunMSBuild(const ATarget, AConfig, APlatform,
  ALogFile: string): Boolean;
var
  BDS, RsVars, BatFile, CmdLine: string;
  SL:       TStringList;
  SI:       TStartupInfo;
  PI:       TProcessInformation;
  ExitCode: Cardinal;
begin
  Result := False;

  BDS := GetEnvironmentVariable('BDS');
  if BDS = '' then
  begin
    lblStatus.Caption := 'Umgebungsvariable BDS nicht gesetzt - kein RAD-Studio-Kontext.';
    Exit;
  end;
  RsVars := IncludeTrailingPathDelimiter(BDS) + 'bin\rsvars.bat';
  if not FileExists(RsVars) then
  begin
    lblStatus.Caption := 'rsvars.bat nicht gefunden: ' + RsVars;
    Exit;
  end;

  { rsvars.bat setzt die MSBuild-Umgebung; /flp schreibt das vollstaendige Log
    in eine Datei, die anschliessend geparst wird. Aufruf ueber eine temporaere
    Batch-Datei, um das fragile cmd-Quoting zu vermeiden. }
  BatFile := IncludeTrailingPathDelimiter(GetEnvironmentVariable('TEMP'))
             + 'BuildLogStats_run.bat';
  SL := TStringList.Create;
  try
    SL.Add('@echo off');
    SL.Add(Format('call "%s"', [RsVars]));
    SL.Add(Format('msbuild "%s" /t:Build /p:Config=%s /p:Platform=%s ' +
      '/nologo /clp:NoSummary /flp:logfile="%s";Verbosity=normal;Encoding=UTF-8',
      [ATarget, AConfig, APlatform, ALogFile]));
    SL.SaveToFile(BatFile, TEncoding.ASCII);
  finally
    SL.Free;
  end;

  CmdLine := Format('cmd.exe /C "%s"', [BatFile]);
  UniqueString(CmdLine);   { CreateProcessW darf den Puffer beschreiben }

  FillChar(SI, SizeOf(SI), 0);
  SI.cb          := SizeOf(SI);
  SI.dwFlags     := STARTF_USESHOWWINDOW;
  SI.wShowWindow := SW_HIDE;
  FillChar(PI, SizeOf(PI), 0);

  if not CreateProcess(nil, PChar(CmdLine), nil, nil, False, CREATE_NO_WINDOW,
       nil, PChar(ExtractFilePath(ATarget)), SI, PI) then
  begin
    lblStatus.Caption := 'msbuild-Prozess konnte nicht gestartet werden.';
    Exit;
  end;
  try
    { Warten und dabei die Nachrichtenschleife bedienen, damit die UI
      (inkl. Marquee-Progressbar) waehrend des Builds reagiert. }
    while MsgWaitForMultipleObjects(1, PI.hProcess, False, INFINITE,
            QS_ALLINPUT) = WAIT_OBJECT_0 + 1 do
      Application.ProcessMessages;
    if GetExitCodeProcess(PI.hProcess, ExitCode) then
      Result := ExitCode = 0;
  finally
    CloseHandle(PI.hThread);
    CloseHandle(PI.hProcess);
    System.SysUtils.DeleteFile(BatFile);
  end;
end;

procedure TBuildLogFrame.btnBuildClick(Sender: TObject);
var
  ModSvc:  IOTAModuleServices;
  Group:   IOTAProjectGroup;
  Proj:    IOTAProject;
  Target:  string;
  Cfg:     string;
  Plat:    string;
  LogFile: string;
  OK:      Boolean;
  I:       Integer;
begin
  if not Supports(BorlandIDEServices, IOTAModuleServices, ModSvc) then
  begin
    lblBuildStatus.Caption := 'ToolsAPI nicht verfuegbar.';
    Exit;
  end;

  { Projektgruppe ermitteln (gleiche Methode wie in FindFileInProjectGroup) }
  Group := nil;
  for I := 0 to ModSvc.ModuleCount - 1 do
    if Supports(ModSvc.Modules[I], IOTAProjectGroup, Group) then Break;
  if Group = nil then
  begin
    lblBuildStatus.Caption := 'Kein Projekt / keine Projektgruppe geladen.';
    Exit;
  end;

  Proj := Group.ActiveProject;
  if Proj = nil then
  begin
    lblBuildStatus.Caption := 'Kein aktives Projekt.';
    Exit;
  end;

  { Ziel je nach Scope: Einzelprojekt (.dproj) oder ganze Gruppe (.groupproj);
    Config/Plattform aus dem aktiven Projekt = "eingestellte Variante". }
  if cmbScope.ItemIndex = 1 then
    Target := Group.FileName
  else
    Target := Proj.FileName;

  Cfg  := Proj.CurrentConfiguration;
  Plat := Proj.CurrentPlatform;
  if Cfg  = '' then Cfg  := 'Debug';
  if Plat = '' then Plat := 'Win32';

  LogFile := IncludeTrailingPathDelimiter(GetEnvironmentVariable('TEMP'))
             + 'BuildLogStats_build.log';
  System.SysUtils.DeleteFile(LogFile);

  OK                := False;
  btnBuild.Enabled  := False;
  Screen.Cursor     := crHourGlass;
  lblStatus.Caption := '';
  lblBuildStatus.Caption := Format('Baue %s (%s/%s) ...',
    [ExtractFileName(Target), Cfg, Plat]);
  try
    try
      pbBuild.Style := pbstMarquee;
      OK := RunMSBuild(Target, Cfg, Plat, LogFile);
    except
      on E: Exception do
      begin
        OK := False;
        lblStatus.Caption := 'Build-Fehler: ' + E.Message;
      end;
    end;
  finally
    pbBuild.Style    := pbstNormal;
    pbBuild.Position := pbBuild.Max;
    Screen.Cursor    := crDefault;
    btnBuild.Enabled := True;
  end;

  if OK then
    lblBuildStatus.Caption := 'Build erfolgreich - lade Log ...'
  else
    lblBuildStatus.Caption := 'Build fehlgeschlagen - lade Log (falls vorhanden) ...';

  { Das von /flp geschriebene Log laden und auswerten - auch bei Fehlern,
    damit Fehlermeldungen in der Statistik erscheinen.
    Abgesichert, damit ein defektes Log nie die IDE crasht. }
  try
    if FileExists(LogFile) then
    begin
      { Build-Log auch in die "Zuletzt geoeffnet"-Liste aufnehmen. }
      LoadFromFile(LogFile, True);
      { Edition-Sperre erkennen: msbuild/dcc verweigert Kommandozeilen-Build.
        Als klaren Fehler in der (roten) Statuszeile ganz links melden. }
      if Pos('does not support command line compiling', memoLog.Lines.Text) > 0 then
      begin
        lblStatus.Caption      := 'Fehler: kein Kommandozeilen-Compiler';
        lblBuildStatus.Caption := 'Build nicht ausgefuehrt';
      end;
    end
    else if lblStatus.Caption = '' then
      lblStatus.Caption := 'Keine Log-Datei erzeugt: ' + LogFile;
  except
    on E: Exception do
      lblStatus.Caption := 'Log-Auswertung fehlgeschlagen: ' + E.Message;
  end;
end;

procedure TBuildLogFrame.LoadFromFile(const AFileName: string; AddToRecent: Boolean);
begin
  Screen.Cursor := crHourGlass;
  try
    memoLog.Lines.BeginUpdate;
    try
      memoLog.Lines.LoadFromFile(AFileName);
    finally
      memoLog.Lines.EndUpdate;
    end;

    FStats.ParseFile(AFileName);
    if AddToRecent then
      AddRecentFile(AFileName);
    ShowStats;
    BuildCodeRows;
    ApplySortAndFill;
    PopulateCodeCombo;
    if cmbCode.Items.Count > 0 then
      FilterByCode(cmbCode.Items[0]);

    lblInfo.Caption := Format('%s', [ExtractFileName(AFileName)]);
    lblErrorSummary.Caption := Format('%d Fehler  |  %d Warnungen  |  %d Hinweise',
      [FStats.TotalErrors, FStats.TotalWarnings, FStats.TotalHints]);

    pgcMain.ActivePage := tsCode;
  finally
    Screen.Cursor := crDefault;
  end;
end;

procedure TBuildLogFrame.ShowStats;
begin
  memoStats.Lines.BeginUpdate;
  try
    memoStats.Text := FStats.FormatReport;
  finally
    memoStats.Lines.EndUpdate;
  end;
  memoStats.SelStart := 0;
end;

{ --------------------------------------------------------------------------- }

procedure TBuildLogFrame.BuildCodeRows;
var
  CodeMap: TDictionary<string, Integer>;   { Code -> Index in FCodeRows }
  I:       Integer;
  Msg:     TBuildMessage;
  Idx:     Integer;
  Row:     TCodeRow;
begin
  CodeMap := TDictionary<string, Integer>.Create;
  SetLength(FCodeRows, 0);
  try
    for I := 0 to FStats.Messages.Count - 1 do
    begin
      Msg := FStats.Messages[I];
      if CodeMap.TryGetValue(Msg.Code, Idx) then
      begin
        Inc(FCodeRows[Idx].Count);
      end
      else
      begin
        Row.Code  := Msg.Code;
        Row.Kind  := Msg.Kind;
        Row.Count := 1;
        Row.Desc  := Msg.Text;
        Idx := Length(FCodeRows);
        SetLength(FCodeRows, Idx + 1);
        FCodeRows[Idx] := Row;
        CodeMap.Add(Msg.Code, Idx);
      end;
    end;
  finally
    CodeMap.Free;
  end;
end;

procedure TBuildLogFrame.ApplySortAndFill;
var
  SortCol: Integer;
  SortAsc: Boolean;
  LI:  TListItem;
  I:   Integer;
  Row: TCodeRow;
begin
  SortCol := FSortCol;
  SortAsc := FSortAsc;

  TArray.Sort<TCodeRow>(FCodeRows,
    TComparer<TCodeRow>.Construct(
      function(const A, B: TCodeRow): Integer
      begin
        case SortCol of
          0: Result := CompareText(A.Code, B.Code);
          1: Result := CompareText(KindLabel[A.Kind], KindLabel[B.Kind]);
          2: Result := A.Count - B.Count;
        else Result := CompareText(A.Desc, B.Desc);
        end;
        if not SortAsc then Result := -Result;
      end));

  lvCodes.Items.BeginUpdate;
  try
    lvCodes.Items.Clear;
    for I := 0 to High(FCodeRows) do
    begin
      Row := FCodeRows[I];
      LI  := lvCodes.Items.Add;
      LI.Caption    := Row.Code;
      LI.SubItems.Add(KindLabel[Row.Kind]);
      LI.SubItems.Add(IntToStr(Row.Count));
      LI.SubItems.Add(Row.Desc);
    end;
  finally
    lvCodes.Items.EndUpdate;
  end;
end;

procedure TBuildLogFrame.lvCodesColumnClick(Sender: TObject; Column: TListColumn);
begin
  if FSortCol = Column.Index then
    FSortAsc := not FSortAsc
  else
  begin
    FSortCol := Column.Index;
    FSortAsc := Column.Index <> 2;  { Anzahl: Standard absteigend }
  end;
  ApplySortAndFill;
end;

{ --------------------------------------------------------------------------- }

procedure TBuildLogFrame.PopulateCodeCombo;
var
  Codes: TList<string>;
  I:     Integer;
  Code:  string;
  Seen:  TDictionary<string, Boolean>;
begin
  Codes := TList<string>.Create;
  Seen  := TDictionary<string, Boolean>.Create;
  try
    for I := 0 to FStats.Messages.Count - 1 do
    begin
      Code := FStats.Messages[I].Code;
      if not Seen.ContainsKey(Code) then
      begin
        Seen.Add(Code, True);
        Codes.Add(Code);
      end;
    end;
    Codes.Sort;
    cmbCode.Items.BeginUpdate;
    try
      cmbCode.Items.Clear;
      for Code in Codes do
        cmbCode.Items.Add(Code);
    finally
      cmbCode.Items.EndUpdate;
    end;
    if cmbCode.Items.Count > 0 then
      cmbCode.ItemIndex := 0;
  finally
    Codes.Free;
    Seen.Free;
  end;
end;

procedure TBuildLogFrame.FilterByCode(const ACode: string);
var
  I:     Integer;
  Count: Integer;
begin
  Count := 0;
  for I := 0 to FStats.Messages.Count - 1 do
    if SameText(FStats.Messages[I].Code, ACode) then
      Inc(Count);

  SetLength(FCodeMsgs, Count);
  Count := 0;
  for I := 0 to FStats.Messages.Count - 1 do
    if SameText(FStats.Messages[I].Code, ACode) then
    begin
      FCodeMsgs[Count] := FStats.Messages[I];
      Inc(Count);
    end;

  FCodeSortCol := -1;
  ApplyCodeSort;
  lblCodeCount.Caption := Format('%d Treffer', [Length(FCodeMsgs)]);

  var Hint := GetHintForCode(ACode);
  memoHint.Text      := Hint;
  pnlHint.Visible    := Hint <> '';
  lblHintTitle.Visible := Hint <> '';
end;

procedure TBuildLogFrame.ApplyCodeSort;
var
  SortCol: Integer;
  SortAsc: Boolean;
  LI:      TListItem;
  I:       Integer;
  Msg:     TBuildMessage;
begin
  SortCol := FCodeSortCol;
  SortAsc := FCodeSortAsc;

  if SortCol >= 0 then
    TArray.Sort<TBuildMessage>(FCodeMsgs,
      TComparer<TBuildMessage>.Construct(
        function(const A, B: TBuildMessage): Integer
        begin
          case SortCol of
            0: Result := CompareText(KindLabel[A.Kind], KindLabel[B.Kind]);
            1: Result := CompareText(A.FileName, B.FileName);
            2: Result := A.Line - B.Line;
          else Result := CompareText(A.Text, B.Text);
          end;
          if not SortAsc then Result := -Result;
        end));

  lvCodeResult.Items.BeginUpdate;
  try
    lvCodeResult.Items.Clear;
    for I := 0 to High(FCodeMsgs) do
    begin
      Msg := FCodeMsgs[I];
      LI  := lvCodeResult.Items.Add;
      LI.Caption := KindLabel[Msg.Kind];
      LI.SubItems.Add(Msg.FileName);
      LI.SubItems.Add(IntToStr(Msg.Line));
      LI.SubItems.Add(Msg.Text);
    end;
  finally
    lvCodeResult.Items.EndUpdate;
  end;
end;

procedure TBuildLogFrame.lvCodeResultColumnClick(Sender: TObject; Column: TListColumn);
begin
  if FCodeSortCol = Column.Index then
    FCodeSortAsc := not FCodeSortAsc
  else
  begin
    FCodeSortCol := Column.Index;
    FCodeSortAsc := Column.Index <> 2;
  end;
  ApplyCodeSort;
end;

procedure TBuildLogFrame.btnFilterClick(Sender: TObject);
var
  Code: string;
begin
  Code := Trim(cmbCode.Text);
  if Code = '' then Exit;
  FilterByCode(Code);
  pgcMain.ActivePage := tsCode;
end;

procedure TBuildLogFrame.cmbCodeChange(Sender: TObject);
begin
  if cmbCode.ItemIndex >= 0 then
    FilterByCode(cmbCode.Items[cmbCode.ItemIndex]);
end;

{ --------------------------------------------------------------------------- }
{  IDE-Navigation                                                              }
{ --------------------------------------------------------------------------- }

function TBuildLogFrame.FindFileInProjectGroup(const AFileName: string): string;
var
  ModSvc:    IOTAModuleServices;
  ProjGroup: IOTAProjectGroup;
  Project:   IOTAProject;
  ModInfo:   IOTAModuleInfo;
  I, J:      Integer;
begin
  Result := '';
  if not Supports(BorlandIDEServices, IOTAModuleServices, ModSvc) then Exit;

  ProjGroup := nil;
  for I := 0 to ModSvc.ModuleCount - 1 do
    if Supports(ModSvc.Modules[I], IOTAProjectGroup, ProjGroup) then Break;
  if ProjGroup = nil then Exit;

  for I := 0 to ProjGroup.ProjectCount - 1 do
  begin
    Project := ProjGroup.Projects[I];
    for J := 0 to Project.GetModuleCount - 1 do
    begin
      ModInfo := Project.GetModule(J);
      if SameText(ExtractFileName(ModInfo.FileName), AFileName) then
      begin
        Result := ModInfo.FileName;
        Exit;
      end;
    end;
  end;
end;

procedure TBuildLogFrame.OpenAndNavigate(const AFullPath: string; ALine: Integer);
var
  ActionSvc: IOTAActionServices;
  ModSvc:    IOTAModuleServices;
  Module:    IOTAModule;
  SrcEdit:   IOTASourceEditor;
  View:      IOTAEditView;
  Pos:       TOTAEditPos;
  I:         Integer;
begin
  if not Supports(BorlandIDEServices, IOTAActionServices, ActionSvc) then Exit;
  ActionSvc.OpenFile(AFullPath);

  if not Supports(BorlandIDEServices, IOTAModuleServices, ModSvc) then Exit;
  Module := ModSvc.FindModule(AFullPath);
  if Module = nil then Exit;

  for I := 0 to Module.GetModuleFileCount - 1 do
    if Supports(Module.GetModuleFileEditor(I), IOTASourceEditor, SrcEdit) then
    begin
      if SrcEdit.GetEditViewCount > 0 then
      begin
        View     := SrcEdit.GetEditView(0);
        Pos.Line    := ALine;
        Pos.Col     := 1;
        View.CursorPos := Pos;
        View.MoveViewToCursor;
        SrcEdit.Show;
      end;
      Break;
    end;
end;

procedure TBuildLogFrame.lvCodeResultSelectItem(Sender: TObject;
  Item: TListItem; Selected: Boolean);
begin
  if Selected and Assigned(Item) and (Item.Index < Length(FCodeMsgs)) then
    memoRawLine.Text := FCodeMsgs[Item.Index].RawLine
  else if not Selected then
    memoRawLine.Clear;
end;

procedure TBuildLogFrame.lvCodeResultDblClick(Sender: TObject);
var
  Item:     TListItem;
  FileName: string;
  Line:     Integer;
  FullPath: string;
begin
  Item := lvCodeResult.Selected;
  if Item = nil then Exit;

  FileName := Item.SubItems[0];                  { Spalte "Dateiname" }
  Line     := StrToIntDef(Item.SubItems[1], 1);  { Spalte "Zeile"     }

  FullPath := FindFileInProjectGroup(FileName);
  if FullPath = '' then
  begin
    lblStatus.Caption := Format('"%s" wurde in der Projektgruppe nicht gefunden.', [FileName]);
    Exit;
  end;

  lblStatus.Caption := '';
  OpenAndNavigate(FullPath, Line);
end;

procedure TBuildLogFrame.Clear;
begin
  memoLog.Clear;
  memoStats.Clear;
  lvCodes.Items.Clear;
  lvCodeResult.Items.Clear;
  SetLength(FCodeMsgs, 0);
  cmbCode.Items.Clear;
  cmbCode.Text := '';
  lblCodeCount.Caption := '';
  memoHint.Clear;
  pnlHint.Visible    := False;
  lblHintTitle.Visible := False;
  SetLength(FCodeRows, 0);
  FStats.Clear;
  lblInfo.Caption    := '';
  lblStatus.Caption  := '';
  memoRawLine.Clear;
end;

end.
