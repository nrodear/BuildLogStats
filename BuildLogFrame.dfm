object BuildLogFrame: TBuildLogFrame
  Left = 0
  Top = 0
  Width = 800
  Height = 520
  TabOrder = 0
  object pnlTop: TPanel
    Left = 0
    Top = 0
    Width = 800
    Height = 60
    Align = alTop
    BevelOuter = bvNone
    TabOrder = 0
    object lblInfo: TLabel
      Left = 510
      Top = 9
      Width = 3
      Height = 15
      Font.Charset = DEFAULT_CHARSET
      Font.Color = clWindowText
      Font.Height = -12
      Font.Name = 'Segoe UI'
      Font.Style = [fsBold]
      ParentFont = False
    end
    object btnOpen: TButton
      Left = 8
      Top = 5
      Width = 110
      Height = 23
      Caption = 'Log '#246'ffnen...'
      TabOrder = 0
      OnClick = btnOpenClick
    end
    object btnRecent: TButton
      Left = 126
      Top = 5
      Width = 140
      Height = 23
      Caption = 'Zuletzt ge'#246'ffnet '#9660
      TabOrder = 1
      OnClick = btnRecentClick
    end
    object btnClear: TButton
      Left = 274
      Top = 5
      Width = 80
      Height = 23
      Caption = 'Leeren'
      TabOrder = 2
      OnClick = btnClearClick
    end
    object btnFromIDE: TButton
      Left = 362
      Top = 5
      Width = 140
      Height = 23
      Caption = 'Aus IDE-Meldungen'
      TabOrder = 3
      OnClick = btnFromIDEClick
    end
    object lblBuildScope: TLabel
      Left = 8
      Top = 37
      Width = 24
      Height = 15
      Caption = 'Ziel:'
    end
    object lblBuildStatus: TLabel
      Left = 514
      Top = 37
      Width = 3
      Height = 15
    end
    object cmbScope: TComboBox
      Left = 44
      Top = 33
      Width = 100
      Height = 23
      Style = csDropDownList
      TabOrder = 4
      Items.Strings = (
        'Projekt'
        'Gruppe')
      ItemIndex = 0
    end
    object btnBuild: TButton
      Left = 150
      Top = 33
      Width = 90
      Height = 23
      Caption = 'Bauen'
      TabOrder = 5
      OnClick = btnBuildClick
    end
    object pbBuild: TProgressBar
      Left = 248
      Top = 35
      Width = 258
      Height = 18
      TabOrder = 6
    end
  end
  object pgcMain: TPageControl
    Left = 0
    Top = 60
    Width = 800
    Height = 438
    ActivePage = tsFehlercodes
    Align = alClient
    TabOrder = 1
    ExplicitTop = 60
    object tsCode: TTabSheet
      Caption = 'Code'
      object pnlCodeFilter: TPanel
        Left = 0
        Top = 0
        Width = 792
        Height = 33
        Align = alTop
        BevelOuter = bvNone
        TabOrder = 0
        object lblCodeFilter: TLabel
          Left = 8
          Top = 9
          Width = 31
          Height = 15
          Caption = 'Code:'
        end
        object lblCodeCount: TLabel
          Left = 244
          Top = 9
          Width = 3
          Height = 15
        end
        object cmbCode: TComboBox
          Left = 44
          Top = 5
          Width = 100
          Height = 23
          TabOrder = 0
          OnChange = cmbCodeChange
        end
        object btnFilter: TButton
          Left = 152
          Top = 5
          Width = 80
          Height = 23
          Caption = 'Filtern'
          TabOrder = 1
          OnClick = btnFilterClick
        end
      end
      object pnlHint: TPanel
        Left = 0
        Top = 33
        Width = 792
        Height = 110
        Align = alTop
        BevelOuter = bvNone
        TabOrder = 3
        object lblHintTitle: TLabel
          Left = 4
          Top = 4
          Width = 118
          Height = 15
          Caption = 'Behebungsvorschlag:'
          Font.Charset = DEFAULT_CHARSET
          Font.Color = clWindowText
          Font.Height = -12
          Font.Name = 'Segoe UI'
          Font.Style = [fsBold]
          ParentFont = False
        end
        object memoHint: TMemo
          Left = 0
          Top = 22
          Width = 792
          Height = 88
          Align = alBottom
          BorderStyle = bsNone
          Color = clInfoBk
          Font.Charset = DEFAULT_CHARSET
          Font.Color = clWindowText
          Font.Height = -11
          Font.Name = 'Segoe UI'
          Font.Style = []
          ParentFont = False
          ReadOnly = True
          ScrollBars = ssVertical
          TabOrder = 0
        end
      end
      object pnlRawLine: TPanel
        Left = 0
        Top = 395
        Width = 792
        Height = 40
        Align = alBottom
        BevelOuter = bvNone
        Color = clInfoBk
        TabOrder = 2
        object memoRawLine: TMemo
          Left = 0
          Top = 0
          Width = 792
          Height = 40
          Align = alClient
          BorderStyle = bsNone
          Color = clInfoBk
          Font.Charset = DEFAULT_CHARSET
          Font.Color = clWindowText
          Font.Height = -11
          Font.Name = 'Courier New'
          Font.Style = []
          ParentFont = False
          ReadOnly = True
          TabOrder = 0
        end
      end
      object lvCodeResult: TListView
        Left = 0
        Top = 143
        Width = 792
        Height = 252
        Align = alClient
        Columns = <
          item
            Caption = 'Kategorie'
            Width = 70
          end
          item
            Caption = 'Dateiname'
            Width = 180
          end
          item
            Alignment = taRightJustify
            Caption = 'Zeile'
          end
          item
            Caption = 'Meldung'
            Width = 340
          end>
        GridLines = True
        ReadOnly = True
        RowSelect = True
        TabOrder = 1
        ViewStyle = vsReport
        OnColumnClick = lvCodeResultColumnClick
        OnDblClick = lvCodeResultDblClick
        OnSelectItem = lvCodeResultSelectItem
      end
    end
    object tsStatistik: TTabSheet
      Caption = 'Statistik'
      ImageIndex = 1
      object memoStats: TMemo
        Left = 0
        Top = 0
        Width = 792
        Height = 435
        Align = alClient
        Font.Charset = DEFAULT_CHARSET
        Font.Color = clWindowText
        Font.Height = -12
        Font.Name = 'Courier New'
        Font.Style = []
        ParentFont = False
        ReadOnly = True
        ScrollBars = ssVertical
        TabOrder = 0
        WordWrap = False
      end
    end
    object tsFehlercodes: TTabSheet
      Caption = 'Fehlercodes'
      ImageIndex = 2
      object lvCodes: TListView
        Left = 0
        Top = 0
        Width = 792
        Height = 435
        Align = alClient
        Columns = <
          item
            Caption = 'Code'
            Width = 65
          end
          item
            Caption = 'Typ'
            Width = 70
          end
          item
            Alignment = taRightJustify
            Caption = 'Anzahl'
            Width = 60
          end
          item
            Caption = 'Beschreibung'
            Width = 570
          end>
        GridLines = True
        ReadOnly = True
        RowSelect = True
        TabOrder = 0
        ViewStyle = vsReport
        OnColumnClick = lvCodesColumnClick
      end
    end
    object tsRohlog: TTabSheet
      Caption = 'Rohlog'
      ImageIndex = 3
      object memoLog: TMemo
        Left = 0
        Top = 0
        Width = 792
        Height = 435
        Align = alClient
        Font.Charset = DEFAULT_CHARSET
        Font.Color = clWindowText
        Font.Height = -12
        Font.Name = 'Courier New'
        Font.Style = []
        ParentFont = False
        ReadOnly = True
        ScrollBars = ssBoth
        TabOrder = 0
        WordWrap = False
      end
    end
  end
  object pnlStatus: TPanel
    Left = 0
    Top = 498
    Width = 800
    Height = 22
    Align = alBottom
    BevelOuter = bvNone
    TabOrder = 2
    object lblStatus: TLabel
      Left = 4
      Top = 4
      Width = 3
      Height = 15
      Font.Charset = DEFAULT_CHARSET
      Font.Color = clRed
      Font.Height = -12
      Font.Name = 'Segoe UI'
      Font.Style = []
      ParentFont = False
    end
    object lblErrorSummary: TLabel
      Left = 520
      Top = 4
      Width = 3
      Height = 15
      Anchors = [akTop, akRight]
      Font.Charset = DEFAULT_CHARSET
      Font.Color = clWindowText
      Font.Height = -12
      Font.Name = 'Segoe UI'
      Font.Style = []
      ParentFont = False
    end
  end
  object dlgOpen: TOpenDialog
    Filter = 
      'Log-Dateien (*.log;*.all;*.txt)|*.log;*.all;*.txt|Alle Dateien (' +
      '*.*)|*.*'
    Left = 728
    Top = 4
  end
  object mnuRecent: TPopupMenu
    Left = 756
    Top = 4
  end
end
