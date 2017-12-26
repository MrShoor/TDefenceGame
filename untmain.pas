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
  gTypes, gWorld, gLightRenderer, gLevelLoader, gUnits, gLevelResults,
  avRes, avTypes,
  intfUtils,
  mutils;

type
  TGameInput = class
  public
    function Right: Boolean;
    function Left : Boolean;
    function Up   : Boolean;
    function Down : Boolean;

    function Shoot: Boolean;
    function Special: Boolean;

    function SetWeapon(out ANewWeapon: TPlayerWeapon): Boolean;

    function RestartLevel: Boolean;
  end;

  { TfrmMain }

  TfrmMain = class(TForm)
    {$IfDef FPC}
    ApplicationProperties1: TApplicationProperties;
    {$EndIf}
    {$IfDef DCC}
    ApplicationEvents1: TApplicationEvents;
    {$EndIf}
    FPSTimer: TTimer;
    RestartTimer: TTimer;
    procedure ApplicationProperties1Idle(Sender: TObject; var Done: Boolean);
    procedure FormCreate(Sender: TObject);
    procedure FormDestroy(Sender: TObject);
    procedure FormPaint(Sender: TObject);
    procedure FPSTimerTimer(Sender: TObject);
    procedure FormMouseDown(Sender: TObject; Button: TMouseButton;
      Shift: TShiftState; X, Y: Integer);
    procedure FormMouseMove(Sender: TObject; Shift: TShiftState; X,
      Y: Integer);
    procedure RestartTimerTimer(Sender: TObject);
  private
    FGameInput: TGameInput;
    FMain     : TavMainRender;

    FFBO_HDR : TavFrameBuffer;
    FFBOMain : TavFrameBuffer;
    FProgramResolveHDR: TavProgram;

    FSpineProgram : TavProgram;
    FSpineVB    : TavVB;
    FSpineVB_UI : TavVB;

    FSpineVB_UI_Data: ISpineExVertices;

    FRenderBatches : IRenderBatchArr;
    FLights        : ILightInfoArr;
    FShadowCasters : IShadowVertices;

    FNoise    : TavTexture;
    FLightMaps: TavLightMap;
    FAtlas    : TavAtlasArrayReferenced;

    FWorld     : TWorld;
    FFPSCounter: Integer;
    FFPSLast   : Integer;

    FLastTime : Int64;

    FPlayerTank: IWeakRef;

    FLevelResults: TLevelResults;

    function GetPlayerTank: TTowerTank;
    procedure SetPlayerTank(const Value: TTowerTank);
  {$IfDef FPC}
  public
    procedure EraseBackground(DC: HDC); override;
  {$EndIf}
  public
    procedure InvalidateShaders;
    procedure UpdateCaption;
    property PlayerTank: TTowerTank read GetPlayerTank write SetPlayerTank;
  public
    procedure Init;
    procedure BuildLevel;
    procedure ProcessInput;
    procedure RenderScene;
    procedure UpdateSteps;
  end;

var
  frmMain: TfrmMain;

implementation

uses Math, avTexLoader;

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
  Init;
end;

procedure TfrmMain.ApplicationProperties1Idle(Sender: TObject; var Done: Boolean);
begin
  Done := False;
  UpdateSteps;
end;

procedure TfrmMain.FormDestroy(Sender: TObject);
begin
  FreeAndNil(FWorld);
  FreeAndNil(FMain);
  FreeAndNil(FGameInput);
end;

procedure TfrmMain.FormMouseDown(Sender: TObject; Button: TMouseButton;
  Shift: TShiftState; X, Y: Integer);
begin
  InvalidateShaders;
end;

procedure TfrmMain.FormMouseMove(Sender: TObject; Shift: TShiftState; X,
  Y: Integer);
begin
  UpdateCaption;
end;

procedure TfrmMain.FormPaint(Sender: TObject);
begin
  RenderScene;
end;

procedure TfrmMain.FPSTimerTimer(Sender: TObject);
begin
  FFPSLast := FFPSCounter;
  FFPSCounter := 0;
  UpdateCaption;
end;

function TfrmMain.GetPlayerTank: TTowerTank;
begin
  Result := nil;
  if FPlayerTank = nil then Exit;
  Result := TTowerTank(FPlayerTank.Obj);
  if Result = nil then FPlayerTank := nil;
end;

{$IfDef FPC}
procedure TfrmMain.EraseBackground(DC: HDC);
begin
  //inherited EraseBackground(DC);
end;
{$EndIf}

procedure TfrmMain.UpdateCaption;
var intPt: TVec3;
    s: String;
begin
  s := '';
  if Intersect(Plane(0,0,1,0), FMain.Cursor.Ray, intPt) then
  begin
    s := s + Format('(%f.4, %f.4)', [intPt.x, intPt.y]);
  end;
  s := s + ' FPS: ' + IntToStr(FFPSLast);
  Caption := s;
end;

procedure TfrmMain.Init;
var
  pCol: PByte;
  i: Integer;
begin
  FGameInput := TGameInput.Create;

  FMain := TavMainRender.Create(nil);
  FMain.Camera.Eye := Vec(0,0,-18);

  FFBOMain := Create_FrameBuffer(FMain, [TTextureFormat.RGBA], [True]);
  FFBO_HDR := Create_FrameBuffer(FMain, [TTextureFormat.RGBA16f], [True]);

  FSpineProgram := TavProgram.Create(FMain);
  FSpineProgram.Load('base_spine', SHADERS_FROMRES, SHADERS_DIR);

  FProgramResolveHDR := TavProgram.Create(FMain);
  FProgramResolveHDR.Load('ResolveHDR', SHADERS_FROMRES, SHADERS_DIR);

  FLightMaps := TavLightMap.Create(FMain);

  FSpineVB   := TavVB.Create(FMain);
  FSpineVB.CullMode := cmNone;
  FSpineVB.PrimType := ptTriangles;

  FSpineVB_UI_Data := TSpineExVertices.Create;

  FSpineVB_UI := TavVB.Create(FMain);
  FSpineVB_UI.CullMode := cmNone;
  FSpineVB_UI.PrimType := ptTriangles;
  FSpineVB_UI.Vertices := FSpineVB_UI_Data As IVerticesData;

  FLights := TLightInfoArr.Create();
  FShadowCasters := TShadowVertices.Create();
  FRenderBatches := TRenderBatchArr.Create();

  FAtlas := TavAtlasArrayReferenced.Create(FMain);
  FAtlas.TargetFormat := TTextureFormat.RGBA;
  FAtlas.TargetSize := Vec(1026, 1026);
  FAtlas.sRGB := True;

  FNoise := TavTexture.Create(FMain);
  FNoise.TargetFormat := TTextureFormat.R;
  FNoise.TexData := EmptyTexData(128,128,TImageFormat.Gray8,False,True);
  pCol := FNoise.TexData.MipData(0,0).Data;
  for i := 0 to 128*128 - 1 do
  begin
    pCol^ := Random(256);
    Inc(pCol);
  end;
  FLightMaps.NoiseTex := FNoise;

  BuildLevel;
  //FParticles.SetTime(FWorld.Time);
end;

procedure TfrmMain.InvalidateShaders;
begin
  FSpineProgram.Invalidate;
  FProgramResolveHDR.Invalidate;
  FLightMaps.InvalidateShaders;
end;

procedure TfrmMain.BuildLevel;
begin
  SetCurrentDir(ExtractFilePath(ParamStr(0)));
  FreeAndNil(FWorld);
  FWorld := TWorld.Create(FAtlas);
  TLevelLoader.LoadLevel(ExpandFileName('Levels\Level0.flat'), FWorld);
  PlayerTank := FWorld.FindPlayerObject as TTowerTank;

  FLevelResults := TLevelResults.Create(FWorld);
end;

procedure TfrmMain.ProcessInput;
var rot, acc: Single;
    tank: TTowerTank;
    intpt: TVec3;
    newWeapon: TPlayerWeapon;
begin
  if GetForegroundWindow <> Handle then Exit;

  tank := PlayerTank;
  if tank = nil then Exit;
  if tank.IsDead then
  begin
    FLevelResults.LevelResult := lrsFail;
    Exit;
  end;
  if (FWorld.EnemiesCount = 0) and (FWorld.SpawnManager.Count = 0) then
    FLevelResults.LevelResult := lrsDone;

  rot := 0;
  acc := 0;
  if FGameInput.Left  then rot := rot + 1;
  if FGameInput.Right then rot := rot - 1;
  if FGameInput.Up    then acc := acc + 1;
  if FGameInput.Down  then acc := acc - 1;
  tank.RotateBy(rot);
  tank.Move(acc);

  if FGameInput.SetWeapon(newWeapon) then
    TPlayer(tank).SetWeapon(newWeapon);

  if Intersect(Plane(0,0,1,0), FMain.Cursor.Ray, intpt) then
    tank.TowerTargetAt(intpt.xy);

  if FGameInput.Shoot then tank.Fire();

  if FGameInput.RestartLevel then
    RestartTimer.Enabled := True;
end;

procedure TfrmMain.RenderScene;
var
    pb: PRenderBatch;
    i: Integer;
    lastKind: TRenderBatchKind;
begin
  if not FMain.Inited3D then
  begin
    FMain.Window := Handle;
    FMain.Init3D(apiDX11);
  end;
  if FMain.Bind then
  try
    FLights.Clear();
    FShadowCasters.Clear();
    FRenderBatches.Clear();
    FSpineVB_UI_Data.Clear();
    FWorld.GetAllDrawData(FRenderBatches, FLights, FShadowCasters, FSpineVB_UI_Data);

    //FParticles.Simulate(FWorld.Time);

    FFBO_HDR.FrameRect := RectI(0, 0, ClientWidth, ClientHeight);
    FFBO_HDR.Select();
    FFBO_HDR.Clear(0, Vec(0,0,0,0));

    FMain.States.Blending[0] := True;
    FMain.States.SetBlendFunctions(TBlendFunc.bfSrcAlpha, TBlendFunc.bfInvSrcAlpha, 0);

    //FLightMaps.Ambient := Vec(0,0,0,0);
    FLightMaps.BuildClusters(
      FLights,
      FShadowCasters
    );

    if FRenderBatches.Count > 0 then pb := FRenderBatches.PItem[0] else pb := nil;
    lastKind := rbkUnknown;
    for i := 0 to FRenderBatches.Count - 1 do
    begin
      case pb^.Kind of
        rbkSpine, rbkSpineLighted:
          begin
            if pb^.SpineVerts.Count > 0 then
            begin
              //FMain.States.Wireframe := True;
              FSpineVB.Vertices := pb^.SpineVerts as IVerticesData;
              if lastKind <> pb^.kind then
              begin
                FSpineProgram.Select();
                FSpineProgram.SetAttributes(FSpineVB, nil, nil);
                FSpineProgram.SetUniform('AtlasRegionRefs', FAtlas.RegionsVB);
                FSpineProgram.SetUniform('Atlas', FAtlas, Sampler_Linear_NoAnisotropy);
                FSpineProgram.SetUniform('AtlasSize', FAtlas.Size);
                FSpineProgram.SetUniform('Noise', FNoise, Sampler_Linear_NoAnisotropy);
                FSpineProgram.SetUniform('ScreenSize', FMain.WindowSize*1.0);
                FSpineProgram.SetUniform('LightMap', FLightMaps.LightMap, Sampler_NoFilter);
                if pb^.kind = rbkSpineLighted then
                  FSpineProgram.SetUniform('UseDynamicLighting', 1.0)
                else
                  FSpineProgram.SetUniform('UseDynamicLighting', 0.0);
                FSpineProgram.SetUniform('UIRender', 0.0);
              end;
              FSpineProgram.Draw(ptTriangles, cmNone, False);
//                FMain.States.Wireframe := False;
            end;
          end;
        rbkParticles, rbkParticlesLighted:
          begin

          end;
      end;
      Inc(pb);
    end;

    if FSpineVB_UI_Data.Count > 0 then
    begin
      FSpineVB_UI.Invalidate;
      FSpineProgram.Select();
      FSpineProgram.SetAttributes(FSpineVB_UI, nil, nil);
      FSpineProgram.SetUniform('AtlasRegionRefs', FAtlas.RegionsVB);
      FSpineProgram.SetUniform('Atlas', FAtlas, Sampler_Linear_NoAnisotropy);
      FSpineProgram.SetUniform('AtlasSize', FAtlas.Size);
      FSpineProgram.SetUniform('Noise', FNoise, Sampler_Linear_NoAnisotropy);
      FSpineProgram.SetUniform('ScreenSize', FMain.WindowSize*1.0);
      FSpineProgram.SetUniform('LightMap', FLightMaps.LightMap, Sampler_NoFilter);
      FSpineProgram.SetUniform('UseDynamicLighting', 0.0);
      FSpineProgram.SetUniform('UIRender', 1.0);
      FSpineProgram.Draw(ptTriangles, cmNone, False);
    end;

    FFBOMain.FrameRect := FFBO_HDR.FrameRect;
    FFBOMain.Select();
    FMain.States.Blending[0] := False;
    FProgramResolveHDR.Select();
    FProgramResolveHDR.SetAttributes(nil, nil, nil);
    FProgramResolveHDR.SetUniform('Color', FFBO_HDR.GetColor(0), Sampler_NoFilter);
    FProgramResolveHDR.Draw(ptTriangleStrip, cmNone, False, 0, 0, 4);

    FFBOMain.BlitToWindow();
    FMain.Present;
  finally
    FMain.Unbind;
    Inc(FFPSCounter);
  end;
end;

procedure TfrmMain.RestartTimerTimer(Sender: TObject);
begin
  RestartTimer.Enabled := False;
  BuildLevel;
end;

procedure TfrmMain.SetPlayerTank(const Value: TTowerTank);
begin
  FPlayerTank := nil;
  if Value <> nil then
    FPlayerTank := Value.WeakRef;
end;

procedure TfrmMain.UpdateSteps;
var
  i: Integer;
  StepsCount: Int64;
begin
  if FLastTime = 0 then FLastTime := FMain.Time64;

  StepsCount := (FMain.Time64 - FLastTime) div PHYS_STEP;
  for i := 0 to StepsCount - 1 do
  begin
    ProcessInput;
    FWorld.UpdateStep(Vec(0,0));
  end;

  FLastTime := FLastTime + PHYS_STEP * StepsCount;
  if StepsCount > 0 then
    FMain.InvalidateWindow;
end;


{ TGameInput }

function TGameInput.Down: Boolean;
begin
  Result := GetKeyState(Ord('S')) < 0;
end;

function TGameInput.Left: Boolean;
begin
  Result := GetKeyState(Ord('A')) < 0;
end;

function TGameInput.RestartLevel: Boolean;
begin
  Result := GetKeyState(Ord('R')) < 0;
end;

function TGameInput.Right: Boolean;
begin
  Result := GetKeyState(Ord('D')) < 0;
end;

function TGameInput.SetWeapon(out ANewWeapon: TPlayerWeapon): Boolean;
begin
  Result := False;
  if GetKeyState(Ord('1')) < 0 then
  begin
    ANewWeapon := pwMachineGun;
    Result := True;
  end;
  if GetKeyState(Ord('2')) < 0 then
  begin
    ANewWeapon := pwMiniRocket;
    Result := True;
  end;
  if GetKeyState(Ord('3')) < 0 then
  begin
    ANewWeapon := pwRocket;
    Result := True;
  end;
  if GetKeyState(Ord('4')) < 0 then
  begin
    ANewWeapon := pwTesla;
    Result := True;
  end;
  if GetKeyState(Ord('5')) < 0 then
  begin
    ANewWeapon := pwGrenade;
    Result := True;
  end;
end;

function TGameInput.Shoot: Boolean;
begin
  Result := GetKeyState(VK_LBUTTON) < 0;
end;

function TGameInput.Special: Boolean;
begin
  Result := GetKeyState(VK_RBUTTON) < 0;
end;

function TGameInput.Up: Boolean;
begin
  Result := GetKeyState(Ord('W')) < 0;
end;

end.

