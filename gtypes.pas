unit gTypes;

{$IfDef FPC}
  {$mode objfpc}{$H+}
  {$ModeSwitch advancedrecords}
{$EndIf}

interface

uses
  mutils,
  avBase,
  Classes, SysUtils,
  avContnrs, avTypes, avTess, avRes,
  SpineIntf;

const
  SHADERS_FROMRES = False;
  SHADERS_DIR = 'D:\Projects\TDefenceGame\TDefenceGame_Shaders\!Out';

type
  TZIndex = Integer;
  TGameLayer = (glNone, glBack3, glBack2, glBack1, glGameBack, glGame, glGameFore, glFore1, glFore2, glFore3);

  { TSpineVertexEx }

  TSpineVertexEx = packed record
    vsCoord    : TVec3;
    vsTexCrd   : TVec2;
    vsColor    : TVec4;
    vsAtlasRef : Single;
    vsWrapMode : TVec2;
    class function Layout: IDataLayout; static;
  end;
  ISpineExVertices = {$IfDef FPC}specialize{$EndIf} IArray<TSpineVertexEx>;
  TSpineExVertices = {$IfDef FPC}specialize{$EndIf} TVerticesRec<TSpineVertexEx>;

  TGameSpineRes = packed record
    SpineSkel : IspSkeleton;
    SpineAnim : IspAnimationState;
    procedure LoadFromDir(const ADir: string; const AAtlas: TavAtlasArrayReferenced);
  end;
  PGameSpineRes = ^TGameSpineRes;

  TGameResource = packed record
    images  : array of ISpriteIndex;
    tris    : ISpineExVertices;

    fixtures_poly: array of TVec2Arr;
    fixtures_cir : TVec3Arr;

    shadowcasters: array of TVec2Arr;

    spine : array of TGameSpineRes;
  end;

  TRenderBatchKind = (rbkUnknown, rbkSpine, rbkSpineLighted, rbkParticles, rbkParticlesLighted);

  IParticleGroupArr = {$IfDef FPC}specialize{$EndIf} IArray<TavObject>;
  TParticleGroupArr = {$IfDef FPC}specialize{$EndIf} TArray<TavObject>;

  { TRenderBatch }

  TRenderBatch = packed record
    Kind : TRenderBatchKind;
    SpineVerts: ISpineExVertices;
    Particles : IParticleGroupArr;
    procedure Clear;
  end;
  PRenderBatch = ^TRenderBatch;
  IRenderBatchArr = {$IfDef FPC}specialize{$EndIf} IArray<TRenderBatch>;
  TRenderBatchArr = {$IfDef FPC}specialize{$EndIf} TArray<TRenderBatch>;

//light types
  TPointLightProjection = (plpRight, plpBottom, plpLeft, plpTop);

  { TLightInfo }

  TLightInfo = packed record
    LightKind : Single; //0 - point light
    LightDist : Single;
    LightPos  : TVec2;
    LightColor: TVec4;

    function GetBBOX: TAABB;
    class function Layout: IDataLayout; static;
  end;
  PLightInfo = ^TLightInfo;
  ILightInfoArr = {$IfDef FPC}specialize{$EndIf}IArray<TLightInfo>;
  TLightInfoArr = {$IfDef FPC}specialize{$EndIf}TVerticesRec<TLightInfo>;

  { TShadowVertex }

  TShadowVertex = packed record
    vsCoord: TVec2;
    class function Layout: IDataLayout; static;
  end;
  IShadowVertices = {$IfDef FPC}specialize{$EndIf}IArray<TShadowVertex>;
  TShadowVertices = {$IfDef FPC}specialize{$EndIf}TVerticesRec<TShadowVertex>;
//end of light types

function GetSpineVertexCallBack(const ASpineVert: ISpineExVertices; const ATransform: TMat3): ISpineAddVertexCallback;

implementation

type
  ISpineAddVertexCallback_Internal = interface (ISpineAddVertexCallback)
    procedure SetArray(const AVert: ISpineExVertices; const ATransform: TMat3);
  end;

  { TSpineAddVertexCallback_Internal }

  TSpineAddVertexCallback_Internal = class(TInterfacedObject, ISpineAddVertexCallback_Internal)
  private
    FVert: Pointer;//ISpineExVertices
    FTransform: TMat3;
  public
    procedure AddVertex(const Coord: TVec3; const TexCoord: TVec2; const Color: TVec4; const AtlasRef: Single);
    procedure SetArray(const AVert: ISpineExVertices; const ATransform: TMat3);
  end;

threadvar gvCB: ISpineAddVertexCallback_Internal;

function GetSpineVertexCallBack(const ASpineVert: ISpineExVertices; const ATransform: TMat3): ISpineAddVertexCallback;
begin
  if gvCB = nil then gvCB := TSpineAddVertexCallback_Internal.Create;
  gvCB.SetArray(ASpineVert, ATransform);
  Result := gvCB;
end;

{ TSpineAddVertexCallback_Internal }

procedure TSpineAddVertexCallback_Internal.AddVertex(const Coord: TVec3; const TexCoord: TVec2; const Color: TVec4; const AtlasRef: Single);
var v: TSpineVertexEx;
begin
  v.vsCoord.xy := Coord.xy * FTransform;
  v.vsCoord.z := Coord.z;
  v.vsTexCrd := TexCoord;
  v.vsColor := Color;
  v.vsAtlasRef := AtlasRef;
  v.vsWrapMode := Vec(0, 0);
  ISpineExVertices(FVert).Add(v);
end;

procedure TSpineAddVertexCallback_Internal.SetArray(const AVert: ISpineExVertices; const ATransform: TMat3);
begin
  FVert := Pointer(AVert);
  FTransform := ATransform;
end;

{ TRenderBatch }

procedure TRenderBatch.Clear;
begin
  SpineVerts := nil;
  Particles := nil;
end;

{ TShadowVertex }

class function TShadowVertex.Layout: IDataLayout;
begin
  Result := LB.Add('vsCoord', ctFloat, 2).Finish();
end;

{ TLightInfo }

function TLightInfo.GetBBOX: TAABB;
begin
  Result.min := Vec(LightPos, 0);
  Result.max := Result.min;
  Result.min.xy := Result.min.xy - Vec(LightDist, LightDist);
  Result.max.xy := Result.max.xy + Vec(LightDist, LightDist);
end;

class function TLightInfo.Layout: IDataLayout;
begin
  Result := LB.Add('Kind', ctFloat, 1)
              .Add('Dist', ctFloat, 1)
              .Add('Pos', ctFloat, 2)
              .Add('Color', ctFloat, 4)
              .Finish();
end;

{ TSpineVertexEx }

class function TSpineVertexEx.Layout: IDataLayout;
begin
  Result := LB.Add('vsCoord', ctFloat, 3)
              .Add('vsTexCrd', ctFloat, 2)
              .Add('vsColor', ctFloat, 4)
              .Add('vsAtlasRef', ctFloat, 1)
              .Add('vsWrapMode', ctFloat, 2)
              .Finish();
end;

{ TGameSpineRes }

procedure TGameSpineRes.LoadFromDir(const ADir: string; const AAtlas: TavAtlasArrayReferenced);
var Dir: string;
    skel, atlas: string;
begin
  SpineSkel := nil;
  SpineAnim := nil;
  Dir := ExtractFilePath(ParamStr(0)) + 'SpineRes\' + ADir;
  if not DirectoryExists(Dir) then Exit;
  skel := Dir + '\skeleton.skel';
  if not FileExists(skel) then Exit;
  atlas := Dir + '\skeleton.atlas';
  if not FileExists(atlas) then Exit;
  SpineSkel := Create_IspSkeleton(atlas, skel, AAtlas, 3.0/333);
  SpineAnim := Create_IspAnimationState(SpineSkel, 0.1);
  SpineAnim.SetAnimationByName(0, 'idle', true);
end;

end.

