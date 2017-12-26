unit gLightRenderer;

{$IfDef FPC}
  {$ModeSwitch advancedrecords}
{$EndIf}

interface

uses
  Windows,
  avRes, avTypes, avTess, avContnrs, mutils,
  gTypes;

type
  TLightViewProjMatrix = packed record
    m: TMat3;
    class function Layout: IDataLayout; static;
  end;

  IMat3Arr = {$IfDef FPC}specialize{$EndIf}IArray<TLightViewProjMatrix>;
  TMat3Arr = {$IfDef FPC}specialize{$EndIf}TVerticesRec<TLightViewProjMatrix>;

  { TavLightMap }

  TavLightMap = class(TavMainRenderChild)
  private const
    cCLUSTER_RES_X = 64;
    cCLUSTER_RES_Y = 64;
  private
    FHeadTex : TavTexture;
    FLights  : TavUAV;

    FLightsInput: ILightInfoArr;

    FLightsVB   : TavVB;
    FLightsData : TavSB;
    FLightsProj : TavSB;

    FShadowMapFrontFaces : TavTexture;
    FShadowMap : TavTexture;
    FShadowCastersVB: TavVB;
    FShadowProgram: TavProgram;

    FNoiseTex: TavTexture;
    FGodRaysProgram: TavProgram;

    FDrawClustersProgram: TavProgram;

    FFBO       : TavFrameBuffer;
    FShadowFBOFrontFaces : TavFrameBuffer;
    FShadowFBO : TavFrameBuffer;

    FLightMap   : TavTexture;
    FLightMapFBO: TavFrameBuffer;
    FLightMapProgram: TavProgram;

    FAmbient: TVec4;

    procedure DropOutsideLights(const ALights: ILightInfoArr);
    procedure PrepareLightMatrices(const ALights: ILightInfoArr);

    procedure BuildShadows(const AShadowCasters: IShadowVertices);
    procedure SetNoiseTex(const AValue: TavTexture);
  public
    property NoiseTex: TavTexture read FNoiseTex write SetNoiseTex;
    property Ambient: TVec4 read FAmbient write FAmbient;

    procedure InvalidateShaders;

    function LightClusters   : TavTexture;
    function LightLinkedList : TavUAV;
    function LightData       : TavSB;
    function LightProj       : TavSB;
    function ShadowMaps      : TavTexture;

    function LightMap : TavTexture;

    procedure BuildClusters(const ALights: ILightInfoArr; const AShadowCasters: IShadowVertices);
    procedure DrawGodRays();

    procedure AfterConstruction; override;
  end;

implementation

uses
  SysUtils, Math, avTexLoader;

type
  TLightMeshVertex = packed record
    vsCoord: TVec2;
    class function Layout: IDataLayout; static;
  end;
  ILightMeshVertices = {$IfDef FPC}specialize{$EndIf}IArray<TLightMeshVertex>;
  TLightMeshVertices = {$IfDef FPC}specialize{$EndIf}TVerticesRec<TLightMeshVertex>;

{ TavLightMap }

procedure TavLightMap.AfterConstruction;

  function GenLightMesh: ILightMeshVertices;
  const TESS_COUNT = 16;
  var i: Integer;
      v: TLightMeshVertex;
      s: Single;
  begin
    Result := TLightMeshVertices.Create;

    s := 1.0/cos(2.0*PI*(0.5/TESS_COUNT));

    for i := 0 to TESS_COUNT-1 do
    begin
      v.vsCoord := Vec(0,0);
      Result.Add(v);
      v.vsCoord := VecSinCos(i/TESS_COUNT * 2*PI) * s;
      Result.Add(v);
      v.vsCoord := VecSinCos((i+1)/TESS_COUNT * 2*PI) * s;
      Result.Add(v);
    end;
  end;

begin
  inherited;
  FAmbient := Vec(0.05,0.05,0.05,0.05);

  FHeadTex := TavTexture.Create(Self);
  FHeadTex.TargetFormat := TTextureFormat.R32;
  FHeadTex.TexData := EmptyTexData(cCLUSTER_RES_X, cCLUSTER_RES_Y, FHeadTex.TargetFormat, False);

  FLights := TavUAV.Create(Self);
  FLights.SetSize(120000, 2*SizeOf(Integer), False);

  FLightsData := TavSB.Create(Self);
  FLightsProj := TavSB.Create(Self);

  FLightsVB := TavVB.Create(Self);
  FLightsVB.CullMode := cmNone;
  FLightsVB.PrimType := ptTriangles;
  FLightsVB.Vertices := GenLightMesh() as IVerticesData;

  FDrawClustersProgram := TavProgram.Create(Self);
  FDrawClustersProgram.Load('DrawLightClusters', SHADERS_FROMRES, SHADERS_DIR);

  FShadowProgram := TavProgram.Create(Self);
  FShadowProgram.Load('Shadow', SHADERS_FROMRES, SHADERS_DIR);

  FGodRaysProgram := TavProgram.Create(Self);
  FGodRaysProgram.Load('Godrays', SHADERS_FROMRES, SHADERS_DIR);

  FFBO := TavFrameBuffer.Create(Self);
  FFBO.SetUAV(0, FHeadTex);
  FFBO.SetUAV(1, FLights);
  FFBO.FrameRect := RectI(0, 0, cCLUSTER_RES_X, cCLUSTER_RES_Y);

  FShadowMapFrontFaces := TavTexture.Create(Self);
  FShadowMapFrontFaces.TargetFormat := TTextureFormat.RGBA32f;
  FShadowFBOFrontFaces := TavFrameBuffer.Create(Self);
  FShadowFBOFrontFaces.SetColor(0, FShadowMapFrontFaces);
  FShadowFBOFrontFaces.FrameRect := RectI(0, 0, 512, 64);

  FShadowMap := TavTexture.Create(Self);
  FShadowMap.TargetFormat := TTextureFormat.RGBA32f;
  FShadowFBO := TavFrameBuffer.Create(Self);
  FShadowFBO.SetColor(0, FShadowMap);
  FShadowFBO.FrameRect := RectI(0, 0, 512, 64);

  FShadowCastersVB := TavVB.Create(Self);
  FShadowCastersVB.PrimType := ptLines;

  FLightMap    := TavTexture.Create(Self);
  FLightMap.TargetFormat := TTextureFormat.RGBA16f;
  FLightMapFBO := TavFrameBuffer.Create(Self);
  FLightMapFBO.SetColor(0, FLightMap);
  FLightMapProgram := TavProgram.Create(Self);
  FLightMapProgram.Load('build_lightmap', SHADERS_FROMRES, SHADERS_DIR);
end;

procedure TavLightMap.BuildClusters(const ALights: ILightInfoArr; const AShadowCasters: IShadowVertices);
var oldFBO: TavFrameBuffer;
begin
  FLightsInput := ALights;

  oldFBO := FFBO.Select(False);
  FFBO.ClearUAV(0, Vec(Integer($FFFFFFFF), Integer($FFFFFFFF), Integer($FFFFFFFF), Integer($FFFFFFFF)));

  if ALights <> nil then
  begin
    DropOutsideLights(ALights);
    PrepareLightMatrices(ALights);
    if ALights.Count > 0 then
    begin
      FLightsData.Vertices := ALights as IVerticesData;
      FLightsData.Invalidate;
      FDrawClustersProgram.Select();
      FDrawClustersProgram.SetAttributes(FLightsVB, nil, nil);
      FDrawClustersProgram.SetUniform('LightData', FLightsData);
      FDrawClustersProgram.Draw(ALights.Count);

      BuildShadows(AShadowCasters);
    end;
  end;

  FLightMapFBO.FrameRect := RectI(0, 0, Main.WindowSize.x, Main.WindowSize.y);
  FLightMapFBO.Select(False);
  FLightMapFBO.Clear(0, FAmbient);
  Main.States.SetBlendFunctions(bfOne, bfOne, 0);
  FLightMapProgram.Select();
  FLightMapProgram.SetUniform('ScreenSize', Main.WindowSize*1.0);
  FLightMapProgram.SetUniform('LightHead', LightClusters, Sampler_NoFilter);
  FLightMapProgram.SetUniform('LightList', LightLinkedList);
  FLightMapProgram.SetUniform('LightData', LightData);
  FLightMapProgram.SetUniform('LightProj', LightProj);
  FLightMapProgram.SetUniform('ShadowMap', ShadowMaps, Sampler_Linear);
  FLightMapProgram.SetUniform('LightZ', -Main.Camera.Eye.z);
  FLightMapProgram.Draw(ptTriangleStrip, cmNone, False, 0, 0, 4);
  Main.States.SetBlendFunctions(bfSrcAlpha, bfInvSrcAlpha, 0);

  if oldFBO <> nil then oldFBO.Select();
//  AllocConsole;
//  WriteLn(ALights.Count);
end;

procedure TavLightMap.DrawGodRays;
begin
  if FLightsData = nil then Exit;
  if FLightsInput = nil then Exit;
  if FLightsInput.Count = 0 then Exit;

  Main.States.SetBlendFunctions(bfSrcAlpha, bfOne);

  FGodRaysProgram.Select();
  FGodRaysProgram.SetAttributes(nil, nil, nil);
  FGodRaysProgram.SetUniform('Ambient', FAmbient);
  FGodRaysProgram.SetUniform('LightMap', LightMap, Sampler_NoFilter);
  FGodRaysProgram.SetUniform('LightData', LightData);
  FGodRaysProgram.SetUniform('WorldTime', Main.Time);
  FGodRaysProgram.SetUniform('Noise', FNoiseTex, Sampler_Linear);
//  FGodRaysProgram.Draw(FLightsData.Vertices.VerticesCount);
  FGodRaysProgram.Draw(ptTriangleStrip, cmNone, False, 0, 0, 4);

  Main.States.SetBlendFunctions(bfSrcAlpha, bfInvSrcAlpha);
end;

procedure TavLightMap.BuildShadows(const AShadowCasters: IShadowVertices);
begin
  if (AShadowCasters = nil) or (AShadowCasters.Count < 2) then
  begin
    FShadowFBO.Select(false);
    FShadowFBO.Clear(0,Vec(0,0,0,0));
    Exit;
  end;

  FShadowFBOFrontFaces.Select(false);
  FShadowFBOFrontFaces.Clear(0,Vec(0,0,0,0));

  FShadowCastersVB.Vertices := AShadowCasters as IVerticesData;
  FShadowCastersVB.Invalidate;

  Main.States.SetBlendFunctions(bfOne, bfOne);
  Main.States.SetBlendOperation(boMax, 0);

  FShadowProgram.Select();
  FShadowProgram.SetAttributes(FShadowCastersVB, nil, nil);
  FShadowProgram.SetUniform('LightsCount', FLightsData.Vertices.VerticesCount*1.0);
  FShadowProgram.SetUniform('LightProj', FLightsProj);
  FShadowProgram.SetUniform('DrawFrontFaces', 1.0);
  FShadowProgram.Draw();

  FShadowFBO.Select(false);
  FShadowFBO.Clear(0,Vec(0,0,0,0));
  FShadowProgram.SetUniform('DrawFrontFaces', 0.0);
  FShadowProgram.SetUniform('FrontFaceTex', FShadowMapFrontFaces, Sampler_NoFilter);
  FShadowProgram.Draw();

  Main.States.SetBlendFunctions(bfSrcAlpha, bfInvSrcAlpha);
  Main.States.SetBlendOperation(boAdd, 0);
end;

procedure TavLightMap.SetNoiseTex(const AValue: TavTexture);
begin
  if FNoiseTex = AValue then Exit;
  FNoiseTex := AValue;
end;

procedure TavLightMap.DropOutsideLights(const ALights: ILightInfoArr);
var m: TMat4;
    r: TVec2;
    i: Integer;
begin
  m := Main.Camera.Matrix * Main.Projection.Matrix;
  r := Main.Projection.DepthRange;
  for i := ALights.Count - 1 downto 0 do
  begin
    if not PLightInfo(ALights.PItem[i])^.GetBBOX.InFrustum(m, r) then
      ALights.DeleteWithSwap(i);
  end;
end;

procedure TavLightMap.InvalidateShaders;
begin
  FDrawClustersProgram.Invalidate;
  FShadowProgram.Invalidate;
  FGodRaysProgram.Invalidate;
  FLightMapProgram.Invalidate;
end;

function TavLightMap.LightClusters: TavTexture;
begin
  Result := FHeadTex;
end;

function TavLightMap.LightData: TavSB;
begin
  Result := FLightsData;
end;

function TavLightMap.LightLinkedList: TavUAV;
begin
  Result := FLights;
end;

function TavLightMap.LightMap: TavTexture;
begin
  Result := FLightMap;
end;

function TavLightMap.LightProj: TavSB;
begin
  Result := FLightsProj;
end;

procedure TavLightMap.PrepareLightMatrices(const ALights: ILightInfoArr);

{
  function CalcPerspectiveMatrix: TMat4;
  var w, h, Q: Single;
      DepthSize: Single;
  begin
    h := (cos(fFOV/2)/sin(fFOV/2));
    w := fAspect * h;
    Q := 1.0/(NearPlane - FarPlane);
    DepthSize := DepthRange.y - DepthRange.x;

    ZeroClear(Result, SizeOf(Result));
    Result.f[0, 0] := w;
    Result.f[1, 1] := h;
    Result.f[2, 2] := DepthRange.x - DepthSize * FarPlane * Q;
    Result.f[2, 3] := 1.0;
    Result.f[3, 2] := DepthSize * NearPlane * FarPlane * Q;
  end;
}

  function GetPointLightProjection(const ARadius: Single) : TMat3;
  var n, f, Q: Single;
      DepthRange: TVec2;
      DepthSize : Single;
      fov : Single;
  begin
    fov := Pi*0.501;
    n := 0.001;
    f := ARadius;
    DepthRange := Vec(1, 0);

    Q := 1.0/(n - f);
    DepthSize := DepthRange.y - DepthRange.x;

    Result := ZeroMat3;
    Result.f[0, 0] := (cos(fov/2)/sin(fov/2));
    Result.f[1, 1] := DepthRange.x - DepthSize * f * Q;
    Result.f[1, 2] := 1.0;
    Result.f[2, 1] := DepthSize * n * f * Q;
  end;
var
  i: Integer;
  j: TPointLightProjection;
  pl: PLightInfo;
  lProj: TMat3;

  matdata: IMat3Arr;
  m : array [TPointLightProjection] of TLightViewProjMatrix;

  v : TVec3;
begin
  matdata := TMat3Arr.Create;

  for i := 0 to ALights.Count - 1 do
  begin
    pl := ALights.PItem[i];

    lProj := GetPointLightProjection(pl^.LightDist);

    m[plpRight].m  := Mat3Translate(-pl^.LightPos) * Mat3(Pi*0.5);
    m[plpRight].m :=  m[plpRight].m * lProj;
    v := Vec(27, 10, 1) * m[plpRight].m;
    v.xy := v.xy / v.z;

    m[plpBottom].m := Mat3Translate(-pl^.LightPos) * Mat3(Pi)     * lProj;
    m[plpLeft].m   := Mat3Translate(-pl^.LightPos) * Mat3(Pi*1.5) * lProj;
    m[plpTop].m    := Mat3Translate(-pl^.LightPos) * lProj;

    for j := Low(TPointLightProjection) to High(TPointLightProjection) do
      matdata.Add(m[j]);
    for j := Low(TPointLightProjection) to High(TPointLightProjection) do
    begin
      m[j].m := Inv(m[j].m);
      matdata.Add(m[j]);
    end;
  end;

  FLightsProj.Vertices := matdata as IVerticesData;
end;

function TavLightMap.ShadowMaps: TavTexture;
begin
  Result := FShadowMap;
end;

{ TLightMeshVertex }

class function TLightMeshVertex.Layout: IDataLayout;
begin
  Result := LB.Add('vsCoord', ctFloat, 2).Finish();
end;

{ TLightViewProjMatrix }

class function TLightViewProjMatrix.Layout: IDataLayout;
begin
  Result := LB.Add('r0', ctFloat, 3)
              .Add('r1', ctFloat, 3)
              .Add('r2', ctFloat, 3).Finish();
end;

end.
