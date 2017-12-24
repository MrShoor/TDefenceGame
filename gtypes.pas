unit gTypes;

{$IfDef FPC}
  {$mode objfpc}{$H+}
  {$ModeSwitch advancedrecords}
{$EndIf}

interface

uses
  mutils,
  avContnrs, avTypes, avTess, avRes,
  Classes, SysUtils;

const
  SHADERS_FROMRES = False;
  SHADERS_DIR = 'D:\Projects\Adria\Adria_shaders\!Out';

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
    atlas: string;
    skel : string;
  end;

  TGameResource = packed record
    images  : array of ISpriteIndex;
    tris    : ISpineExVertices;

    fixtures_poly: array of TVec2Arr;
    fixtures_cir : TVec3Arr;

    shadowcasters: array of TVec2Arr;

    spine   : array of TGameSpineRes;
  end;

  TRenderBatchKind = (rbkUnknown, rbkSpine, rbkSpineLighted, rbkParticles, rbgParticlesLighted);

  TRenderBatch = packed record
    Kind : TRenderBatchKind;

    SpineVerts: ISpineExVertices;

    Particles : Pointer;
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

implementation

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

end.

