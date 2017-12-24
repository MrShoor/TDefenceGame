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
  gTypes, gWorld, gLightRenderer, gLevelLoader,
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
    FPSTimer: TTimer;
    procedure ApplicationProperties1Idle(Sender: TObject; var Done: Boolean);
    procedure FormCreate(Sender: TObject);
    procedure FormDestroy(Sender: TObject);
    procedure FormPaint(Sender: TObject);
    procedure FPSTimerTimer(Sender: TObject);
  private
    FMain    : TavMainRender;

    FFBO_HDR : TavFrameBuffer;
    FFBOMain : TavFrameBuffer;
    FProgramResolveHDR: TavProgram;

    FSpineProgram : TavProgram;
    FSpineVB  : TavVB;

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
  {$IfDef FPC}
  public
    procedure EraseBackground(DC: HDC); override;
  {$EndIf}
  public
    procedure UpdateCaption;
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
  FreeAndNil(FMain);
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

{$IfDef FPC}
procedure TfrmMain.EraseBackground(DC: HDC);
begin
  //inherited EraseBackground(DC);
end;
{$EndIf}

procedure TfrmMain.UpdateCaption;
begin
  Caption := 'FPS: ' + IntToStr(FFPSLast);
end;

procedure TfrmMain.Init;
var
  pCol: PByte;
  i: Integer;
begin
  FMain := TavMainRender.Create(nil);

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

  FLights := TLightInfoArr.Create();
  FShadowCasters := TShadowVertices.Create();

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

procedure TfrmMain.BuildLevel;
begin
  SetCurrentDir(ExtractFilePath(ParamStr(0)));
  FreeAndNil(FWorld);
  FWorld := TWorld.Create(FAtlas);
  TLevelLoader.LoadLevel(ExpandFileName('Levels\Level0.flat'), FWorld);
end;

procedure TfrmMain.ProcessInput;
begin

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
    FWorld.GetAllDrawData(FRenderBatches, FLights, FShadowCasters);

    //FParticles.Simulate(FWorld.Time);

    FFBO_HDR.FrameRect := RectI(0, 0, ClientWidth, ClientHeight);
    FFBO_HDR.Select();
    FFBO_HDR.Clear(0, Vec(0,0,0,0));

    FMain.States.Blending[0] := True;
    FMain.States.SetBlendFunctions(TBlendFunc.bfSrcAlpha, TBlendFunc.bfInvSrcAlpha, 0);

    FLightMaps.BuildClusters(
      FLights,
      FShadowCasters
    );

    if FRenderBatches.Count > 0 then pb := FRenderBatches.PItem[0];
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


end.

