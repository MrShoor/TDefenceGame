object frmMain: TfrmMain
  Left = 499
  Top = 214
  Caption = 'frmMain'
  ClientHeight = 741
  ClientWidth = 1246
  Color = clBtnFace
  Font.Charset = DEFAULT_CHARSET
  Font.Color = clWindowText
  Font.Height = -11
  Font.Name = 'Tahoma'
  Font.Style = []
  OldCreateOrder = True
  WindowState = wsMaximized
  OnCreate = FormCreate
  OnDestroy = FormDestroy
  OnMouseDown = FormMouseDown
  OnMouseMove = FormMouseMove
  OnPaint = FormPaint
  PixelsPerInch = 96
  TextHeight = 13
  object ApplicationEvents1: TApplicationEvents
    OnIdle = ApplicationProperties1Idle
    Left = 112
    Top = 40
  end
  object FPSTimer: TTimer
    OnTimer = FPSTimerTimer
    Left = 232
    Top = 40
  end
  object RestartTimer: TTimer
    Enabled = False
    Interval = 1
    OnTimer = RestartTimerTimer
    Left = 328
    Top = 40
  end
end
