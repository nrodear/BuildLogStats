unit BuildLogReg;

{
  Delphi-Package-Registrierung.

  Fuegt unter "Ansicht" (View) den Menuepunkt "Build Log" ein.
  Ein Klick darauf oeffnet das dockbare IDE-Toolfenster.
}

interface

procedure Register;

implementation

uses
  System.SysUtils,
  Vcl.Menus,
  ToolsAPI,
  BuildLogIDEWin;

{ --------------------------------------------------------------------------- }

type
  TBuildLogMenuAction = class
    procedure OnMenuClick(Sender: TObject);
  end;

procedure TBuildLogMenuAction.OnMenuClick(Sender: TObject);
begin
  ShowBuildLogWindow;
end;

var
  GMenuAction: TBuildLogMenuAction = nil;
  GMenuItem:   TMenuItem = nil;

{ --------------------------------------------------------------------------- }

procedure Register;
var
  NTASvc:   INTAServices;
  MainMenu: TMainMenu;
  ViewMenu: TMenuItem;
  Item:     TMenuItem;
  I:        Integer;
  Caption:  string;
begin
  RegisterBuildLogWindow;

  if not Supports(BorlandIDEServices, INTAServices, NTASvc) then Exit;

  MainMenu := NTASvc.MainMenu;
  ViewMenu := nil;

  { "Ansicht"- bzw. "View"-Menue suchen (unabhaengig von Sprachversion) }
  for I := 0 to MainMenu.Items.Count - 1 do
  begin
    Caption := StringReplace(MainMenu.Items[I].Caption, '&', '', [rfReplaceAll]);
    if SameText(Caption, 'View') or SameText(Caption, 'Ansicht') then
    begin
      ViewMenu := MainMenu.Items[I];
      Break;
    end;
  end;

  if ViewMenu = nil then Exit;

  if GMenuAction = nil then
    GMenuAction := TBuildLogMenuAction.Create;

  Item         := TMenuItem.Create(nil);
  Item.Caption := '&Build Log';
  Item.Name    := 'miBuildLog';
  Item.OnClick := GMenuAction.OnMenuClick;
  ViewMenu.Add(Item);
  GMenuItem := Item;
end;

initialization
finalization
  UnregisterBuildLogWindow;

  if Assigned(GMenuItem) then
  begin
    try
      if Assigned(GMenuItem.Parent) then
        GMenuItem.Parent.Remove(GMenuItem);
    except
      { IDE kann beim Shutdown bereits teilweise freigegeben sein }
    end;
    FreeAndNil(GMenuItem);
  end;

  FreeAndNil(GMenuAction);

end.
