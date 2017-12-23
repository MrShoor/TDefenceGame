unit untMain;

{$IfDef FPC}
  {$Macro On}
  {$mode objfpc}{$H+}
  {$ModeSwitch advancedrecords}
  {$IfDef CPU86}
    {$FPUType sse2}
  {$EndIf}
  {$IfDef CPU64}
    {$FPUType sse64}
  {$EndIf}
  {$Define notDCC}
{$Else}
  {$Define DCC}
  {$IfDef WIN32}
    {$Define Windows}
  {$EndIf}
  {$IfDef WIN64}
    {$Define Windows}
  {$EndIf}
{$EndIf}

interface

uses
  {$IfDef FPC}
  LCLType,
  {$EndIf}
  Windows, Messages, SysUtils, Variants, Classes, Graphics,
  Controls, Forms, Dialogs, Menus, ExtCtrls,
  {$IfDef DCC}
  AppEvnts,
  {$EndIf}
  avRes, avTypes,
  mutils;

type

  { TfrmMain }

  TfrmMain = class(TForm)
    {$IfDef FPC}
    ApplicationProperties1: TApplicationProperties;
    {$EndIf}
    {$IfDef DCC}
    ApplicationEvents1: TApplicationEvents;
    {$EndIf}
    procedure ApplicationProperties1Idle(Sender: TObject; var Done: Boolean);
    procedure FormCreate(Sender: TObject);
    procedure FormDestroy(Sender: TObject);
    procedure FormPaint(Sender: TObject);
  private
    FMain    : TavMainRender;
    FFBOMain : TavFrameBuffer;
  {$IfDef FPC}
  public
    procedure EraseBackground(DC: HDC); override;
  {$EndIf}
  public
    procedure RenderScene;
  end;

var
  frmMain: TfrmMain;

implementation

uses Math;

{$IfnDef notDCC}
  {$R *.dfm}
{$EndIf}

{$IfDef FPC}
  {$R *.lfm}
//  {$R 'Texturing_shaders\shaders.rc'}
{$EndIf}

{ TfrmMain }

procedure TfrmMain.FormCreate(Sender: TObject);
begin
  FMain := TavMainRender.Create(nil);
  FFBOMain := Create_FrameBuffer(FMain, [TTextureFormat.RGBA], [True]);
end;

procedure TfrmMain.ApplicationProperties1Idle(Sender: TObject; var Done: Boolean);
begin
  Done := False;
  if FMain <> nil then
    FMain.InvalidateWindow;
end;

procedure TfrmMain.FormDestroy(Sender: TObject);
begin
  FreeAndNil(FMain);
end;

procedure TfrmMain.FormPaint(Sender: TObject);
begin
  RenderScene;
end;

{$IfDef FPC}
procedure TfrmMain.EraseBackground(DC: HDC);
begin
  //inherited EraseBackground(DC);
end;
{$EndIf}

procedure TfrmMain.RenderScene;
begin
  if not FMain.Inited3D then
  begin
    FMain.Window := Handle;
    FMain.Init3D(apiDX11);
  end;
  if FMain.Bind then
  try
    FFBOMain.FrameRect := RectI(0, 0, ClientWidth, ClientHeight);
    FFBOMain.Select();
    FFBOMain.Clear(0, Vec(0,0,0,0));

    FFBOMain.BlitToWindow();
    FMain.Present;
  finally
    FMain.Unbind;
  end;
end;


end.

