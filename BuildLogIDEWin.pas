unit BuildLogIDEWin;

{
  INTACustomDockableForm-Implementierung.
  Kapselt das TBuildLogFrame in ein dockbares IDE-Toolfenster.
}

interface

uses
  System.SysUtils, System.Classes,
  System.IniFiles,
  Vcl.Controls, Vcl.Forms, Vcl.ActnList, Vcl.ImgList,
  Vcl.Menus, Vcl.ComCtrls,
  DesignIntf,
  ToolsAPI,
  BuildLogFrame, BuildLogCapture;

type
  TBuildLogDockHelper = class(TInterfacedObject, INTACustomDockableForm)
  private
    FFrame: TBuildLogFrame;
  public
    { INTACustomDockableForm }
    function  GetCaption: string;
    function  GetFrameClass: TCustomFrameClass;
    procedure FrameCreated(AFrame: TCustomFrame);
    function  GetIdentifier: string;
    function  GetMenuActionList: TCustomActionList;
    function  GetMenuImageList: TCustomImageList;
    procedure CustomizePopupMenu(PopupMenu: TPopupMenu);
    function  GetToolBarActionList: TCustomActionList;
    function  GetToolBarImageList: TCustomImageList;
    procedure CustomizeToolBar(ToolBar: TToolBar);
    procedure LoadWindowState(Desktop: TCustomIniFile; const Section: string);
    procedure SaveWindowState(Desktop: TCustomIniFile; const Section: string;
      IsProject: Boolean);
    function  GetEditState: TEditState;
    function  EditAction(Action: TEditAction): Boolean;

    property Frame: TBuildLogFrame read FFrame;
  end;

var
  GDockHelper:    INTACustomDockableForm = nil;
  GDockHelperObj: TBuildLogDockHelper    = nil;

procedure ShowBuildLogWindow;
procedure RegisterBuildLogWindow;
procedure UnregisterBuildLogWindow;
procedure OnCaptureLoaded;

implementation

{ --------------------------------------------------------------------------- }

procedure RegisterBuildLogWindow;
var
  NTASvc270: INTAServices270;
begin
  if not Supports(BorlandIDEServices, INTAServices270, NTASvc270) then Exit;
  if GDockHelper = nil then
  begin
    GDockHelperObj := TBuildLogDockHelper.Create;
    GDockHelper    := GDockHelperObj;
  end;
  NTASvc270.RegisterDockableForm(GDockHelper);

  if GBuildCapture = nil then
  begin
    GBuildCapture := TBuildCapture.Create;
    GBuildCapture.RegisterNotifiers;
  end;
end;

procedure UnregisterBuildLogWindow;
var
  NTASvc270: INTAServices270;
begin
  if GDockHelper = nil then Exit;
  if Supports(BorlandIDEServices, INTAServices270, NTASvc270) then
    NTASvc270.UnregisterDockableForm(GDockHelper);
  GDockHelper    := nil;
  GDockHelperObj := nil;

  if GBuildCapture <> nil then
  begin
    GBuildCapture.UnregisterNotifiers;
    GBuildCapture := nil;
  end;
end;

procedure ShowBuildLogWindow;
var
  NTASvc270: INTAServices270;
  DockForm:  TCustomForm;
begin
  if not Supports(BorlandIDEServices, INTAServices270, NTASvc270) then Exit;

  if GDockHelper = nil then
  begin
    GDockHelperObj := TBuildLogDockHelper.Create;
    GDockHelper    := GDockHelperObj;
    NTASvc270.RegisterDockableForm(GDockHelper);
  end;

  DockForm := NTASvc270.CreateDockableForm(GDockHelper);
  if Assigned(DockForm) then
    DockForm.Show;
end;

{ --------------------------------------------------------------------------- }
{  TBuildLogDockHelper                                                         }
{ --------------------------------------------------------------------------- }

procedure OnCaptureLoaded;
begin
  if (GDockHelperObj = nil) or (GDockHelperObj.Frame = nil) then Exit;
  GDockHelperObj.Frame.LoadFromCapture;
end;

{ --------------------------------------------------------------------------- }

function TBuildLogDockHelper.GetCaption: string;
begin
  Result := 'Build Log';
end;

function TBuildLogDockHelper.GetFrameClass: TCustomFrameClass;
begin
  Result := TBuildLogFrame;
end;

procedure TBuildLogDockHelper.FrameCreated(AFrame: TCustomFrame);
begin
  FFrame := AFrame as TBuildLogFrame;
end;

function TBuildLogDockHelper.GetIdentifier: string;
begin
  Result := 'BuildLog.IDEFenster';
end;

function TBuildLogDockHelper.GetMenuActionList: TCustomActionList;
begin
  Result := nil;
end;

function TBuildLogDockHelper.GetMenuImageList: TCustomImageList;
begin
  Result := nil;
end;

procedure TBuildLogDockHelper.CustomizePopupMenu(PopupMenu: TPopupMenu);
begin
end;

function TBuildLogDockHelper.GetToolBarActionList: TCustomActionList;
begin
  Result := nil;
end;

function TBuildLogDockHelper.GetToolBarImageList: TCustomImageList;
begin
  Result := nil;
end;

procedure TBuildLogDockHelper.CustomizeToolBar(ToolBar: TToolBar);
begin
end;

const
  CSection = 'BuildLog.IDEFenster';

procedure TBuildLogDockHelper.LoadWindowState(Desktop: TCustomIniFile;
  const Section: string);
var
  F: TCustomForm;
begin
  if FFrame = nil then Exit;
  F := GetParentForm(FFrame);
  if F = nil then Exit;
  F.Left   := Desktop.ReadInteger(Section, CSection + '.Left',   F.Left);
  F.Top    := Desktop.ReadInteger(Section, CSection + '.Top',    F.Top);
  F.Width  := Desktop.ReadInteger(Section, CSection + '.Width',  F.Width);
  F.Height := Desktop.ReadInteger(Section, CSection + '.Height', F.Height);
end;

procedure TBuildLogDockHelper.SaveWindowState(Desktop: TCustomIniFile;
  const Section: string; IsProject: Boolean);
var
  F: TCustomForm;
begin
  if FFrame = nil then Exit;
  F := GetParentForm(FFrame);
  if F = nil then Exit;
  Desktop.WriteInteger(Section, CSection + '.Left',   F.Left);
  Desktop.WriteInteger(Section, CSection + '.Top',    F.Top);
  Desktop.WriteInteger(Section, CSection + '.Width',  F.Width);
  Desktop.WriteInteger(Section, CSection + '.Height', F.Height);
end;

function TBuildLogDockHelper.GetEditState: TEditState;
begin
  Result := [];
end;

function TBuildLogDockHelper.EditAction(Action: TEditAction): Boolean;
begin
  Result := False;
end;

end.
