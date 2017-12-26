unit gWorld;

{$IfDef FPC}
  {$mode objfpc}{$H+}
  {$ModeSwitch advancedrecords}
{$EndIf}

interface

uses
  Classes, SysUtils,
  gTypes,
  mutils,
  avContnrs, avContnrsDefaults,
  avTypes,
  avRes,
  UPhysics2D, UPhysics2DTypes, B2Utils,
  intfUtils,
  BLight;

const
  cNO_BOX2DEBUG = False;
  PHYS_STEP = 4;

type
  TWorld = class;

  { TGameObject }

  TGameObject = class (TWeakedObject)
  private
    FName  : string;
    FWorld : TWorld;
    FZIndex: TZIndex;
    FLayer : TGameLayer;
  protected
    FRes  : TGameResource;
    function GetAngle: Single; virtual; abstract;
    function GetDir: TVec2; virtual; abstract;
    function GetPos: TVec2; virtual; abstract;
    function GetSize: TVec2; virtual; abstract;

    procedure SetAngle(const Value: Single); virtual; abstract;
    procedure SetDir(const Value: TVec2); virtual; abstract;
    procedure SetPos(const Value: TVec2); virtual; abstract;
    procedure SetSize(const Value: TVec2); virtual; abstract;

    procedure SubscribeForUpdateStep;
    procedure UpdateStep; virtual;
    procedure DoSetResource(const ARes: TGameResource); virtual;

    property World: TWorld read FWorld;
  public
    procedure LoadingComplete(); virtual;

    property Name  : string read FName write FName;
    property Layer : TGameLayer read FLayer write FLayer;
    property ZIndex: Integer read FZIndex write FZIndex;

    property Pos  : TVec2  read GetPos   write SetPos;
    property Angle: Single read GetAngle write SetAngle;
    property Dir  : TVec2  read GetDir   write SetDir;
    property Size : TVec2  read GetSize  write SetSize;

    function GetTransform: TMat3; virtual;
    function GetTransformInv: TMat3;

    procedure SetResource(const ARes: TGameResource);

    function  HasSpineTris: Boolean; virtual;
    procedure Draw(const ASpineVertices: ISpineExVertices); virtual;
    procedure DrawLightSources(const ALights: ILightInfoArr); virtual;
    procedure DrawShadowCasters(const AShadowCasters: IShadowVertices); virtual;
    procedure DrawUI(const ASpineVertices: ISpineExVertices); virtual;

    function  HasParticles: Boolean; virtual;
    procedure DrawParticles(const AParticlesArr: IParticleGroupArr); virtual;

    constructor Create(const AWorld: TWorld);
    destructor Destroy; override;
  end;
  TGameObjSet = {$IfDef FPC}specialize{$EndIf}THashSet<TGameObject>;
  IGameObjSet = {$IfDef FPC}specialize{$EndIf}IHashSet<TGameObject>;
  TGameObjArr = {$IfDef FPC}specialize{$EndIf}TArray<TGameObject>;
  IGameObjArr = {$IfDef FPC}specialize{$EndIf}IArray<TGameObject>;
  TGameObjectClass = class of TGameObject;

  { TGameSprite }

  TGameSprite = class (TGameObject)
  protected
    FAngle: Single;
    FPos  : TVec2;
    FSize : TVec2;

    function GetAngle: Single; override;
    function GetDir: TVec2; override;
    function GetPos: TVec2; override;
    function GetSize: TVec2; override;

    procedure SetAngle(const Value: Single); override;
    procedure SetDir(const Value: TVec2); override;
    procedure SetPos(const Value: TVec2); override;
    procedure SetSize(const Value: TVec2); override;
  public
    procedure AfterConstruction; override;
  end;

  TGameBody = class;

  TQueryFilter = function (const AObj: TGameBody): Boolean of object;

  { TGameBody }

  TGameBody = class(TGameObject)
  protected
    function Filter_ExcludeSelf(const AObj: TGameBody): Boolean;
    function QueryObjects(const ARad: Single; const AFilter: TQueryFilter): IGameObjArr;
  protected
    FSize: TVec2;
    function GetAngle: Single; override;
    function GetDir: TVec2; override;
    function GetPos: TVec2; override;
    function GetSize: TVec2; override;

    procedure SetAngle(const Value: Single); override;
    procedure SetDir(const Value: TVec2); override;
    procedure SetPos(const Value: TVec2); override;
    procedure SetSize(const Value: TVec2); override;
  public
    procedure b2DebugDraw(const AVert: ISpineExVertices);

    procedure Draw(const ASpineVertices: ISpineExVertices); override;

    function BodiesCount: Integer; virtual; abstract;
    function GetBody(const AIndex: Integer): Tb2Body; virtual; abstract;
    function MainBody: Tb2Body; virtual; abstract;

    procedure AfterConstruction; override;
    destructor Destroy; override;
  end;

  { TGameSingleBody }

  TGameSingleBody = class(TGameBody)
  private
  protected
    FMainBody: Tb2Body;

    function  CreateFixutreDefForShape(const AShape: Tb2Shape): Tb2FixtureDef; virtual;
    procedure AddFixturesToBody;
    function  CreateBodyDef(const APos: TVector2; const AAngle: Double): Tb2BodyDef; virtual; abstract;
    procedure BuildBody;
    procedure DoSetResource(const ARes: TGameResource); override;
  public
    function BodiesCount: Integer; override;
    function GetBody(const AIndex: Integer): Tb2Body; override;
    function MainBody: Tb2Body; override;
  end;

  { TGameStaticBody }

  TGameStaticBody = class(TGameSingleBody)
  protected
    function CreateBodyDef(const APos: TVector2; const AAngle: Double): Tb2BodyDef; override;
  end;

  { TGameDynamicBody }

  TGameDynamicBody = class(TGameSingleBody)
  private
    function GetVelocity: TVec2;
    procedure SetVelocity(const Value: TVec2);
  protected
    function CreateBodyDef(const APos: TVector2; const AAngle: Double): Tb2BodyDef; override;
  protected
    FOnHitLeave : IWeakedInterface;
    procedure OnHit(const AFixture: Tb2Fixture; const ThisFixture: Tb2Fixture; const AManifold: Tb2WorldManifold); virtual;
    procedure OnLeave(const AFixture: Tb2Fixture; const ThisFixture: Tb2Fixture); virtual;

    procedure DoSetResource(const ARes: TGameResource); override;
  public
    property Velocity: TVec2 read GetVelocity write SetVelocity;
  end;

  TSpawnObject = class;

  TSpawnManager = class(TObject)
  private type
    TPriorityComparer = class(TInterfacedObject, IComparer)
    private
      function Compare(const Left, Right): Integer;
    end;

    ISpawnHeap = {$IfDef FPC}specialize{$EndIf} IHeap<TSpawnObject>;
    TSpawnHeap = {$IfDef FPC}specialize{$EndIf} THeap<TSpawnObject>;
  private
    FWorld : TWorld;
    FSpawners: ISpawnHeap;

    FNextSpawnTime: Int64;

    function IsReadyForSpawnNext: Boolean;
  public
    function  Count: Integer;

    procedure UpdateState;
    procedure Add(const AObj: TSpawnObject);

    constructor Create(const AWorld: TWorld);
  end;

  TSpawnObject = class(TGameObject)
  private
  public
    procedure LoadingComplete(); override;
    procedure Spawn(); virtual; abstract;
  end;

  TSpawnObjectSprite = class(TSpawnObject)
  protected
    FAngle: Single;
    FPos  : TVec2;
    FSize : TVec2;

    function GetAngle: Single; override;
    function GetDir: TVec2; override;
    function GetPos: TVec2; override;
    function GetSize: TVec2; override;

    procedure SetAngle(const Value: Single); override;
    procedure SetDir(const Value: TVec2); override;
    procedure SetPos(const Value: TVec2); override;
    procedure SetSize(const Value: TVec2); override;
  public
    procedure AfterConstruction; override;
  end;

  { TWorldCommonTextures }

  TWorldCommonTextures = packed record
    WhitePix   : ISpriteIndex;
    BulletTrace: ISpriteIndex;
    Grenade    : ISpriteIndex;

    hp       : ISpriteIndex;
    speed    : ISpriteIndex;
    firerate : ISpriteIndex;

    canon_machinegun : ISpriteIndex;
    canon_rocket_mini : ISpriteIndex;
    canon_rocket   : ISpriteIndex;
    canon_tesla    : ISpriteIndex;
    canon_grenades : ISpriteIndex;
    procedure Load(const AAtlas: TavAtlasArrayReferenced);
  end;
  PWorldCommonTextures = ^TWorldCommonTextures;

  TGlypsCache = class (TInterfacedObjectEx)
  private type
    TGlyphKey = packed record
      ch  : WideChar;
      font: string;
      size: Integer;
    end;

    TKeyEqualityComparer = class(TInterfacedObject, IEqualityComparer)
    private
      function Hash(const Value): Cardinal;
      function IsEqual(const Left, Right): Boolean;
    end;

    IGlyphsMap = {$IfDef FPC}specialize{$EndIf} IHashMap<TGlyphKey, ISpriteIndex>;
    TGlyphsMap = {$IfDef FPC}specialize{$EndIf} THashMap<TGlyphKey, ISpriteIndex>;
  private
    FAtlas : TavAtlasArrayReferenced;
    FGlyphs: IGlyphsMap;

    function RenderGlyph(const AGlyph: WideChar; const AFont: string; const ASize: Integer): ITextureMip;
  public
    function  ObtainGlyph(const AGlyph: WideChar; const AFont: string; const ASize: Integer): ISpriteIndex;
    procedure ObtainGlyphs(const AGlyphs: string; const AFont: string; const ASize: Integer; const AOut: ISpriteIndexArr);
    constructor Create(const AAtlas: TavAtlasArrayReferenced);
  end;

  { TWorld }

  TWorld = class
  private type
    TQueryCallback = class (Tb2QueryCallback)
    private
      FQResult : IGameObjArr;
      FFilter  : TQueryFilter;
      function AcceptAll(const AObj: TGameBody): Boolean;
    public
      procedure ClearResult;
      procedure SetFilter(const AFilter: TQueryFilter);
      function GetResult: IGameObjArr;
      function ReportFixture(fixture: Tb2Fixture): Boolean; override;
      constructor Create;
    end;

    { TRaycastCallback }

    TRaycastCallback = class (Tb2RayCastCallback)
    private
      FBody   : TGameBody;
      FPoint  : TVec2;
      FFilter : TQueryFilter;
      function AcceptAll(const AObj: TGameBody): Boolean;
    public
      procedure ClearResult;
      procedure SetFilter(const AFilter: TQueryFilter);

      function ResultBody : TGameBody;
      function ResultPoint: TVec2;

      function ReportFixture(fixture:	Tb2Fixture; const point, normal: TVector2; fraction: PhysicsFloat): PhysicsFloat; override;
      constructor Create;
    end;
  private
    FTreeQuery: TQueryCallback;
    FRayCaster: TRaycastCallback;
  private
    FObjects   : IGameObjSet;
    FToDestroy : IGameObjSet;
    FUpdateSubs: IGameObjSet;
    FTempObjs  : IGameObjArr;

    Fb2World : Tb2World;
    Fb2ContactListener : TContactListener;
    Fb2ContactFilter : TContactFilter;

    FTimeTick: Int64;
    FLastCameraPos: TVec2;

    FSndPlayer: ILightPlayer;

    FAtlas: TavAtlasArrayReferenced;
    FCommonTextures: TWorldCommonTextures;
    FGlyphsCache: TGlypsCache;
    FSpawnManager: TSpawnManager;

    FInDestroy: Boolean;
  public
    property InDestroy: Boolean read FInDestroy;

    function Time: Int64;
    function FindPlayerObject: TGameObject;
    function GetCommonTextures: PWorldCommonTextures;
    property SpawnManager: TSpawnManager read FSpawnManager;

    function EnemiesCount: Integer;

    property Atlas: TavAtlasArrayReferenced read FAtlas;

    property b2World: Tb2World read Fb2World;
    property b2ContactListener: TContactListener read Fb2ContactListener;

    procedure UpdateStep(const ANewCameraPos: TVec2);
    procedure SafeDestroy(const AObj: TGameObject);
    procedure ProcessToDestroy;

    function QueryObjects(const APt: TVec2; ARad: Single; const AFilter: TQueryFilter): IGameObjArr;
    function RayCast(const AStart, AStop: TVec2; out HitPt: TVec2; const AFilter: TQueryFilter): TGameBody; overload;

    procedure GetAllDrawData(const ARenderBatches: IRenderBatchArr; const ALights: ILightInfoArr; const AShadowCasters: IShadowVertices; const AUI: ISpineExVertices);

    function ObtainGlyphs(const AGlyphs: string; const AFont: string; const ASize: Integer): ISpriteIndexArr;

    constructor Create(const AAtlas: TavAtlasArrayReferenced);
    destructor Destroy; override;
  end;

procedure Draw_Sprite(const AVert: ISpineExVertices; const pos, dir, size: TVec2; const ASprite: ISpriteIndex; const Color: PVec4 = nil); overload;
procedure Draw_Line  (const AVert: ISpineExVertices; const APattern: ISpriteIndex; const pt1, pt2: TVec2; width: Single; const color: TVec4); overload;
procedure Draw_Rect  (const AVert: ISpineExVertices; const APattern: ISpriteIndex; const pt1, pt2, pt3, pt4: TVec2; width: Single; const color: TVec4); overload;
procedure Draw_Rect  (const AVert: ISpineExVertices; const APattern: ISpriteIndex; const pos, dir, size: TVec2; width: Single; const color: TVec4); overload;

procedure Draw_UI_Symbol(const AVert: ISpineExVertices; const ASymbol: ISpriteIndex; const APos: TVec2; const AScale: TVec2; const color: TVec4);
procedure Draw_UI_Str(const AVert: ISpineExVertices; const ASymbols: ISpriteIndexArr; const APos: TVec2; const AScale: TVec2; const color: TVec4);

implementation

uses
  Math, avTexLoader, gUnits, avGlyphGenerator;

const
  QuadCrd: array[0..3] of TVec2 = (
    (x:-0.5; y:-0.5),
    (x:-0.5; y: 0.5),
    (x: 0.5; y:-0.5),
    (x: 0.5; y: 0.5)
  );
  QuadTex: array[0..3] of TVec2 = (
    (x: 0; y:1),
    (x: 0; y:0),
    (x: 1; y:1),
    (x: 1; y:0)
  );
  QuadTexOffsetSign: array[0..3] of TVec2 = (
    (x:  1; y:-1),
    (x:  1; y: 1),
    (x: -1; y:-1),
    (x: -1; y: 1)
  );

type

  { TDrawObjectZSort }

  TDrawObjectZSort = class(TInterfacedObject, IComparer)
  private
    function Compare(const Left, Right): Integer;
  end;

procedure Draw_Sprite(const AVert: ISpineExVertices; const pos, dir, size: TVec2; const ASprite: ISpriteIndex; const Color: PVec4);
var v : TSpineVertexEx;
    m: TMat3;
    i, n: Integer;
    halfPixOffset: TVec2;
begin
  v.vsWrapMode := Vec(0, 0);

  m := Mat3(size, normalize(dir), pos);

  n := AVert.Count;
  v.vsCoord.z := 0;
  v.vsAtlasRef := ASprite.Index;
  if Color <> nil then
    v.vsColor := Color^
  else
    v.vsColor := Vec(1,1,1,1);

  halfPixOffset.x := 0.5/ASprite.Data.Width;
  halfPixOffset.y := 0.5/ASprite.Data.Height;
  for i := 0 to 3 do
  begin
    v.vsCoord.xy := QuadCrd[i] * m;
    v.vsTexCrd := QuadTex[i] + QuadTexOffsetSign[i]*halfPixOffset;
    AVert.Add(v);
  end;
  AVert.Add(AVert[n+1]);
  AVert.Add(AVert[n+2]);
end;

procedure Draw_Line(const AVert: ISpineExVertices; const APattern: ISpriteIndex; const pt1, pt2: TVec2; width: Single; const color: TVec4);
var dir: TVec2;
    dirLen: Single;
begin
  dir := pt1 - pt2;
  dirLen := Len(dir);
  if dirLen = 0 then Exit;
  Draw_Sprite(AVert, (pt1+pt2)*0.5, dir, Vec(dirLen, width), APattern, @color);
end;

procedure Draw_Rect(const AVert: ISpineExVertices; const APattern: ISpriteIndex; const pt1, pt2, pt3, pt4: TVec2; width: Single; const color: TVec4);
begin
  Draw_Line(AVert, APattern, pt1, pt2, width, color);
  Draw_Line(AVert, APattern, pt2, pt3, width, color);
  Draw_Line(AVert, APattern, pt3, pt4, width, color);
  Draw_Line(AVert, APattern, pt4, pt1, width, color);
end;

procedure Draw_Rect(const AVert: ISpineExVertices; const APattern: ISpriteIndex; const pos, dir, size: TVec2; width: Single; const color: TVec4);
var m: TMat2;
    hsize: TVec2;
    pts: array[0..3] of TVec2;
begin
  m.Row[0] := dir;
  m.Row[1] := Rotate90(dir, False);
  hsize := size*0.5;
  pts[0] := Vec(-hsize.x, -hsize.y) * m + pos;
  pts[1] := Vec(-hsize.x,  hsize.y) * m + pos;
  pts[2] := hsize * m + pos;
  pts[3] := Vec( hsize.x, -hsize.y) * m + pos;
  Draw_Rect(AVert, APattern, pts[0], pts[1], pts[2], pts[3], width, color);
end;

procedure Draw_UI_Symbol(const AVert: ISpineExVertices; const ASymbol: ISpriteIndex; const APos: TVec2; const AScale: TVec2; const color: TVec4);
var i: Integer;
    s, p: TVec2;
begin
  if ASymbol = nil then Exit;
  p := APos;
  s.x := ASymbol.Data.Width;
  s.y := ASymbol.Data.Height;
  s := s * AScale;
  p.x := p.x + s.x * 0.5;
  Draw_Sprite(AVert, p, Vec(1,0), s, ASymbol, @color);
end;

procedure Draw_UI_Str(const AVert: ISpineExVertices; const ASymbols: ISpriteIndexArr; const APos: TVec2; const AScale: TVec2; const color: TVec4);
var i: Integer;
    s, p: TVec2;
begin
  if ASymbols = nil then Exit;
  p := APos;
  for i := 0 to ASymbols.Count - 1 do
  begin
    s.x := ASymbols[i].Data.Width;
    s.y := ASymbols[i].Data.Height;
    s := s * AScale;
    p.x := p.x + s.x * 0.5;
    Draw_Sprite(AVert, p, Vec(1,0), s, ASymbols[i], @color);
    p.x := p.x + s.x * 0.5;
  end;
end;

{ TDrawObjectZSort }

function TDrawObjectZSort.Compare(const Left, Right): Integer;
var L : TGameObject absolute Left;
    R : TGameObject absolute Right;
begin
  Result := Ord(L.Layer) - Ord(R.Layer);
  if Result <> 0 then Exit;
  Result := L.ZIndex - R.ZIndex;
end;

{ TGameDynamicBody }
function TGameDynamicBody.CreateBodyDef(const APos: TVector2; const AAngle: Double): Tb2BodyDef;
begin
  Result := Tb2BodyDef.Create;
  Result.bodyType := b2_dynamicBody;
  Result.userData := Self;
  Result.position := APos;
  Result.angle := AAngle;
  Result.linearDamping := 10.5;
  Result.angularDamping := 10.5;
  Result.allowSleep := True;
end;

procedure TGameDynamicBody.DoSetResource(const ARes: TGameResource);
begin
  inherited;
  FOnHitLeave := TOnHitSubscriber.Create(MainBody, {$IfDef FPC}@{$EndIf}OnHit, {$IfDef FPC}@{$EndIf}OnLeave);
  World.b2ContactListener.Subscribe(FOnHitLeave);
end;

function TGameDynamicBody.GetVelocity: TVec2;
var mb: Tb2Body;
    v: TVector2;
begin
  mb := MainBody;
  if mb = nil then Exit(Vec(0,0));
  v := mb.GetLinearVelocity;
  Result := Vec(v.x, v.y);
end;

procedure TGameDynamicBody.OnHit(const AFixture, ThisFixture: Tb2Fixture;
  const AManifold: Tb2WorldManifold);
begin

end;

procedure TGameDynamicBody.OnLeave(const AFixture,
  ThisFixture: Tb2Fixture);
begin

end;

procedure TGameDynamicBody.SetVelocity(const Value: TVec2);
var mb: Tb2Body;
begin
  mb := MainBody;
  if mb = nil then Exit;
  mb.SetLinearVelocity(TVector2.From(Value.x, Value.y));
end;

{ TGameStaticBody }

function TGameStaticBody.CreateBodyDef(const APos: TVector2; const AAngle: Double): Tb2BodyDef;
begin
  Result := Tb2BodyDef.Create;
  Result.bodyType := b2_staticBody;
  Result.userData := Self;
  Result.position := APos;
  Result.angle := AAngle;
end;

{ TGameBody }

procedure TGameBody.AfterConstruction;
begin
  inherited;
  FSize := Vec(1,1);
end;

procedure TGameBody.b2DebugDraw(const AVert: ISpineExVertices);
const TESS_COUNT = 128;
var fixture: Tb2Fixture;
    shape: Tb2Shape;
    shapeCircle: Tb2CircleShape;
    shapePoly  : Tb2PolygonShape;
    shapeEdge  : Tb2EdgeShape;
    v, pt1, pt2: TVec2;
    i, inext: Integer;
    m: TMat3;
    fi1, fi2: Single;

    body: Tb2Body;
    bodyIndex: Integer;
begin
  if cNO_BOX2DEBUG then Exit;

  if BodiesCount = 0 then Exit;

  for bodyIndex := 0 to BodiesCount - 1 do
  begin
    body := GetBody(bodyIndex);
    if body = nil then Continue;
    fixture := body.GetFixtureList;
    m := Mat3(body.GetAngle, Vec(body.GetPosition.x, body.GetPosition.y));
    while fixture <> nil do
    begin
      shape := fixture.GetShape;
      case shape.GetType of
        e_circleShape:
        begin
          shapeCircle := shape as Tb2CircleShape;
          for i := 0 to TESS_COUNT - 1 do
          begin
            fi1 := i / TESS_COUNT * 2 * Pi;
            fi2 := (i+1) / TESS_COUNT * 2 * Pi;

            v := Vec(shapeCircle.m_p.x, shapeCircle.m_p.y);
            pt1 := VecSinCos(fi1)*shapeCircle.m_radius + v;
            pt2 := VecSinCos(fi2)*shapeCircle.m_radius + v;
            pt1 := pt1 * m;
            pt2 := pt2 * m;
            Draw_Line(AVert, World.GetCommonTextures.WhitePix, pt1, pt2, 0.02, Vec(1,0,0,1));
          end;
        end;
        e_edgeShape:
        begin
          shapeEdge := shape as Tb2EdgeShape;
          pt1 := Vec(shapeEdge.m_vertex1.x, shapeEdge.m_vertex1.y) * m;
          pt2 := Vec(shapeEdge.m_vertex2.x, shapeEdge.m_vertex2.y) * m;
          Draw_Line(AVert, World.GetCommonTextures.WhitePix, pt1, pt2, 0.02, Vec(1,0,0,1));
        end;
        e_polygonShape:
        begin
          shapePoly := shape as Tb2PolygonShape;
          for i := 0 to shapePoly.m_count-1 do
          begin
            inext := (i + 1) mod shapePoly.m_count;
            pt1 := Vec(shapePoly.m_vertices[i].x, shapePoly.m_vertices[i].y) * m;
            pt2 := Vec(shapePoly.m_vertices[inext].x, shapePoly.m_vertices[inext].y) * m;
            Draw_Line(AVert, World.GetCommonTextures.WhitePix, pt1, pt2, 0.02, Vec(1,0,0,1));
          end;
        end;
        e_chainShape: ;
      end;
      fixture := fixture.GetNext;
    end;
  end;
end;

destructor TGameBody.Destroy;
var i: Integer;
begin
  for i := 0 to BodiesCount - 1 do
  begin
    World.Fb2World.DestroyBody(GetBody(i));
  end;
  inherited;
end;

procedure TGameBody.Draw(const ASpineVertices: ISpineExVertices);
begin
  inherited;
  b2DebugDraw(ASpineVertices);
end;

function TGameBody.Filter_ExcludeSelf(const AObj: TGameBody): Boolean;
begin
  Result := AObj <> Self;
end;

function TGameBody.GetAngle: Single;
begin
  Result := MainBody.GetAngle;
end;

function TGameBody.GetDir: TVec2;
begin
  SinCos(MainBody.GetAngle, Result.y, Result.x);
end;

function TGameBody.GetPos: TVec2;
var
    v2: TVector2;
begin
  v2 := MainBody.GetPosition;
  Result := Vec(v2.x, v2.y);
end;

function TGameBody.GetSize: TVec2;
begin
  Result := FSize;
end;

function TGameBody.QueryObjects(const ARad: Single; const AFilter: TQueryFilter): IGameObjArr;
begin
  Result := World.QueryObjects(Pos, ARad, AFilter)
end;

procedure TGameBody.SetAngle(const Value: Single);
begin
  MainBody.SetTransform(MainBody.GetPosition, Value);
end;

procedure TGameBody.SetDir(const Value: TVec2);
begin
  MainBody.SetTransform(MainBody.GetPosition, ArcTan2(Value.y, Value.x));
end;

procedure TGameBody.SetPos(const Value: TVec2);
begin
  MainBody.SetTransform(TVector2.From(Value.x, Value.y), MainBody.GetAngle);
end;

procedure TGameBody.SetSize(const Value: TVec2);
begin
  FSize := Value;
end;

{ TGameSingleBody }

procedure TGameSingleBody.AddFixturesToBody;
type
  TVector2Arr = array of TVector2;
  procedure DeleteVectors(var v: TVector2Arr; from: Integer; count: Integer);
  var i: Integer;
  begin
    for i := from to from + count - 1 do
      v[i] := v[i+count];
    SetLength(v, Length(v)-count);
  end;
var
  i, j: Integer;

  ShapeVecs: TVector2Arr;
  stepSize: Integer;
  polyShapeDef : Tb2PolygonShape;
  cirShapeDef  : Tb2CircleShape;
begin
  if FRes.fixtures_poly <> nil then
  begin
    for i := 0 to Length(FRes.fixtures_poly)-1 do
    begin
      if Length(FRes.fixtures_poly[i]) < 3 then Continue;

      SetLength(ShapeVecs, Length(FRes.fixtures_poly[i]));
      for j := 0 to Length(FRes.fixtures_poly[i])-1 do
        ShapeVecs[j] := TVector2.From(FRes.fixtures_poly[i][j].x*FSize.x, FRes.fixtures_poly[i][j].y*FSize.y);

      while Length(ShapeVecs) > 2 do
      begin
        stepSize := min(b2_maxPolygonVertices, Length(ShapeVecs));

        polyShapeDef := Tb2PolygonShape.Create;
        polyShapeDef.SetVertices(@ShapeVecs[0], stepSize);

        FMainBody.CreateFixture(CreateFixutreDefForShape(polyShapeDef));

        if stepSize < Length(ShapeVecs) then
          DeleteVectors(ShapeVecs, 1, stepSize - 2)
          //Delete(ShapeVecs, 1, stepSize - 2)
        else
          ShapeVecs := nil;
      end;
    end;
  end;

  if FRes.fixtures_cir <> nil then
    for i := 0 to Length(FRes.fixtures_cir)-1 do
    begin
        cirShapeDef := Tb2CircleShape.Create;
        cirShapeDef.m_p := TVector2.From(FRes.fixtures_cir[i].x, FRes.fixtures_cir[i].y);
        cirShapeDef.m_radius := FRes.fixtures_cir[i].z;
        FMainBody.CreateFixture(CreateFixutreDefForShape(cirShapeDef));
    end;
end;

procedure TGameSingleBody.BuildBody;
var currPos  : TVector2;
    currAngle: Double;
    bdef: Tb2BodyDef;
begin
  if FMainBody <> nil then
  begin
    currPos := FMainBody.GetPosition;
    currAngle := FMainBody.GetAngle;

    FWorld.Fb2World.DestroyBody(FMainBody);
    FMainBody := nil;
  end
  else
  begin
    currPos := TVector2.From(0,0);
    currAngle := 0;
  end;

  bdef := CreateBodyDef(currPos, currAngle);
  FMainBody := FWorld.Fb2World.CreateBody(bdef, True);
  AddFixturesToBody;
end;

function TGameSingleBody.CreateFixutreDefForShape(const AShape: Tb2Shape): Tb2FixtureDef;
begin
  Result := Tb2FixtureDef.Create;
  Result.shape := AShape;
end;

procedure TGameSingleBody.DoSetResource(const ARes: TGameResource);
begin
  inherited DoSetResource(ARes);
  BuildBody;
end;

function TGameSingleBody.BodiesCount: Integer;
begin
  Result := 1;
end;

function TGameSingleBody.GetBody(const AIndex: Integer): Tb2Body;
begin
  Result := FMainBody;
end;

function TGameSingleBody.MainBody: Tb2Body;
begin
  Result := FMainBody;
end;

{ TGameSprite }

procedure TGameSprite.AfterConstruction;
begin
  inherited;
  FSize := Vec(1,1);
end;

function TGameSprite.GetAngle: Single;
begin
  Result := FAngle;
end;

function TGameSprite.GetDir: TVec2;
begin
  Result := VecSinCos(FAngle);
end;

function TGameSprite.GetPos: TVec2;
begin
  Result := FPos;
end;

function TGameSprite.GetSize: TVec2;
begin
  Result := FSize;
end;

procedure TGameSprite.SetAngle(const Value: Single);
begin
  FAngle := Value;
end;

procedure TGameSprite.SetDir(const Value: TVec2);
begin
  FAngle := ArcTan2(Value.y, Value.x);
end;

procedure TGameSprite.SetPos(const Value: TVec2);
begin
  FPos := Value;
end;

procedure TGameSprite.SetSize(const Value: TVec2);
begin
  FSize := Value;
end;

{ TWorldCommonTextures }

procedure TWorldCommonTextures.Load(const AAtlas: TavAtlasArrayReferenced);
begin
  WhitePix := AAtlas.ObtainSprite(Default_ITextureManager.LoadTexture('HG\whitepix.png').MipData(0,0));
  BulletTrace := AAtlas.ObtainSprite(Default_ITextureManager.LoadTexture('HG\guntrace.png').MipData(0,0));
  Grenade := AAtlas.ObtainSprite(Default_ITextureManager.LoadTexture('HG\grenade.png').MipData(0,0));

  hp := AAtlas.ObtainSprite(Default_ITextureManager.LoadTexture('HG\hp.png').MipData(0,0));
  speed := AAtlas.ObtainSprite(Default_ITextureManager.LoadTexture('HG\speed.png').MipData(0,0));
  firerate := AAtlas.ObtainSprite(Default_ITextureManager.LoadTexture('HG\firerate.png').MipData(0,0));

  canon_machinegun := AAtlas.ObtainSprite(Default_ITextureManager.LoadTexture('HG\machinegun.png').MipData(0,0));
  canon_rocket_mini := AAtlas.ObtainSprite(Default_ITextureManager.LoadTexture('HG\canon_rocket_mini.png').MipData(0,0));
  canon_rocket := AAtlas.ObtainSprite(Default_ITextureManager.LoadTexture('HG\canon_rocket.png').MipData(0,0));
  canon_tesla := AAtlas.ObtainSprite(Default_ITextureManager.LoadTexture('HG\canon_tesla.png').MipData(0,0));
  canon_grenades := AAtlas.ObtainSprite(Default_ITextureManager.LoadTexture('HG\canon_grenades.png').MipData(0,0));
end;

{ TWorld.TRaycastCallback }

function TWorld.TRaycastCallback.AcceptAll(const AObj: TGameBody): Boolean;
begin
  Result := True;
end;

procedure TWorld.TRaycastCallback.ClearResult;
begin
  FBody := nil;
  FFilter := {$IfDef FPC}@{$EndIf}AcceptAll;
end;

constructor TWorld.TRaycastCallback.Create;
begin
  ClearResult;
end;

function TWorld.TRaycastCallback.ReportFixture(fixture: Tb2Fixture; const point, normal: TVector2; fraction: PhysicsFloat): PhysicsFloat;
var hitBody: Tb2Body;
begin
  hitBody := fixture.GetBody;
  if hitBody.UserData = nil then Exit(-1);
  if not (TGameObject(hitBody.UserData) is TGameBody) then Exit(-1);
  if not FFilter(TGameBody(hitBody.UserData)) then Exit(-1);
  FBody := TGameBody(hitBody.UserData);
  FPoint := Vec(point.x, point.y);
  Result := fraction;
end;

function TWorld.TRaycastCallback.ResultBody: TGameBody;
begin
  Result := FBody;
end;

function TWorld.TRaycastCallback.ResultPoint: TVec2;
begin
  Result := FPoint;
end;

procedure TWorld.TRaycastCallback.SetFilter(const AFilter: TQueryFilter);
begin
  if Assigned(AFilter) then
    FFilter := AFilter;
end;

{ TWorld.TQueryCallback }

function TWorld.TQueryCallback.AcceptAll(const AObj: TGameBody): Boolean;
begin
  Result := True;
end;

procedure TWorld.TQueryCallback.ClearResult;
begin
  FQResult := TGameObjArr.Create();
  FFilter := {$IfDef FPC}@{$EndIf}AcceptAll;
end;

constructor TWorld.TQueryCallback.Create;
begin
  ClearResult;
end;

function TWorld.TQueryCallback.GetResult: IGameObjArr;
begin
  Result := FQResult;
end;

function TWorld.TQueryCallback.ReportFixture(fixture: Tb2Fixture): Boolean;
var b: Tb2Body;
begin
  Result := True;
  b := fixture.GetBody;
  if b = nil then Exit;
  if b.UserData = nil then Exit;
  if FFilter(TGameBody(b.UserData)) then
    FQResult.Add(TGameBody(b.UserData));
end;

procedure TWorld.TQueryCallback.SetFilter(const AFilter: TQueryFilter);
begin
  if Assigned(AFilter) then
    FFilter := AFilter;
end;

{ TWorld }

function TWorld.GetCommonTextures: PWorldCommonTextures;
begin
  Result := @FCommonTextures;
end;

function TWorld.ObtainGlyphs(const AGlyphs, AFont: string; const ASize: Integer): ISpriteIndexArr;
begin
  Result := TSpriteIndexArr.Create();
  FGlyphsCache.ObtainGlyphs(AGlyphs, AFont, ASize, Result);
end;

procedure TWorld.UpdateStep(const ANewCameraPos: TVec2);
var obj: TGameObject;
    lPos: TListenerPos;
    cameraVel: TVec2;
//    qtime1, qtime2, qfreq: Int64;
begin
  Inc(FTimeTick);
//  QueryPerformanceCounter(qtime1);
  Fb2World.Step(PHYS_STEP/1000, 20, 20);
//  QueryPerformanceCounter(qtime2);
//  QueryPerformanceFrequency(qfreq);
//  AllocConsole;
//  Writeln((qtime2-qtime1)/qfreq*1000:6:3);

  Fb2World.ClearForces;
  FObjects.Reset;
  ProcessToDestroy;

  FUpdateSubs.Reset;
  while FUpdateSubs.Next(obj) do
    obj.UpdateStep;

  cameraVel := (ANewCameraPos - FLastCameraPos)/PHYS_STEP;
  FLastCameraPos := ANewCameraPos;
  lPos.Pos := Vec(FLastCameraPos, 0);
  lPos.Vel := Vec(cameraVel, 0);
  lPos.Front := Vec(0, 0, 1);
  lPos.Top := Vec(0, 1, 0);
  FSndPlayer.Listener3DPos := lPos;

  FSpawnManager.UpdateState;
end;

procedure TWorld.ProcessToDestroy;
var obj : TGameObject;
    i: Integer;
begin
  FTempObjs.Clear;
  FToDestroy.Reset;
  while FToDestroy.Next(obj) do
    FTempObjs.Add(obj);
  for i := 0 to FTempObjs.Count-1 do
    FTempObjs[i].Free;
  FToDestroy.Clear;
end;

function TWorld.QueryObjects(const APt: TVec2; ARad: Single; const AFilter: TQueryFilter): IGameObjArr;
var box: Tb2AABB;
begin
  box.lowerBound := TVector2.From(APt.x, APt.y) - TVector2.From(ARad, ARad);
  box.upperBound := TVector2.From(APt.x, APt.y) + TVector2.From(ARad, ARad);
  FTreeQuery.ClearResult;
  FTreeQuery.SetFilter(AFilter);
  Fb2World.QueryAABB(FTreeQuery, box);
  Result := FTreeQuery.GetResult;
end;

function TWorld.RayCast(const AStart, AStop: TVec2; out HitPt: TVec2; const AFilter: TQueryFilter): TGameBody;
begin
  FRayCaster.ClearResult;
  FRayCaster.SetFilter(AFilter);
  Fb2World.RayCast(FRayCaster, TVector2.From(AStart.x, AStart.y), TVector2.From(AStop.x, AStop.y));
  Result := FRayCaster.ResultBody;
  if Result <> nil then
    HitPt := FRayCaster.ResultPoint
  else
    HitPt := AStop;
end;

procedure TWorld.SafeDestroy(const AObj: TGameObject);
begin
  FToDestroy.AddOrSet(AObj);
end;

function TWorld.Time: Int64;
begin
  Result := FTimeTick * PHYS_STEP;
end;

function TWorld.FindPlayerObject: TGameObject;
begin
  FObjects.Reset;
  while FObjects.Next(Result) do
    if Result is TPlayer then Exit;
  Result := nil;
end;

procedure TWorld.GetAllDrawData(const ARenderBatches: IRenderBatchArr; const ALights: ILightInfoArr; const AShadowCasters: IShadowVertices; const AUI: ISpineExVertices);
var gobj : TGameObject;
    objList: IGameObjArr;
    zSort : IComparer;
    I: Integer;

    newBatch: TRenderBatch;
    newKind : TRenderBatchKind;
begin
  newBatch.kind := rbkUnknown;

  objList := TGameObjArr.Create();

  FObjects.Reset;
  while FObjects.Next(gobj) do
    objList.Add(gobj);

  zSort := TDrawObjectZSort.Create;
  objList.Sort(zSort);

  for I := 0 to objList.Count-1 do
  begin
    gobj := objList[i];

    if gobj.HasSpineTris then
    begin
      if gobj.Layer in [glGameBack, glGame, glGameFore] then
        newKind := rbkSpineLighted
      else
        newKind := rbkSpine;
      if newBatch.kind <> newKind then
      begin
        newBatch.Clear;
        newBatch.kind := newKind;
        newBatch.SpineVerts := TSpineExVertices.Create;
        ARenderBatches.Add(newBatch);
      end;
      gobj.Draw(newBatch.SpineVerts);
    end;

    if gobj.HasParticles then
    begin
      if gobj.Layer in [glGameBack, glGame, glGameFore] then
        newKind := rbkParticlesLighted
      else
        newKind := rbkParticles;
      if newBatch.kind <> newKind then
      begin
        newBatch.Clear;
        newBatch.kind := newKind;
        newBatch.Particles := TParticleGroupArr.Create;
        ARenderBatches.Add(newBatch);
      end;
      gobj.DrawParticles(newBatch.Particles);
    end;

    gobj.DrawLightSources(ALights);
    gobj.DrawShadowCasters(AShadowCasters);
    gobj.DrawUI(AUI);
  end;
end;

constructor TWorld.Create(const AAtlas: TavAtlasArrayReferenced);
begin
  FAtlas := AAtlas;

  FObjects   := TGameObjSet.Create;
  FToDestroy := TGameObjSet.Create;
  FUpdateSubs:= TGameObjSet.Create;
  FTempObjs  := TGameObjArr.Create;

  Fb2World := Tb2World.Create(TVector2.From(0,0));
  Fb2ContactListener := TContactListener.Create(Fb2World);
//  Fb2ContactFilter := TContactFilter.Create(Fb2World);

  FTreeQuery := TQueryCallback.Create;
  FRayCaster := TRaycastCallback.Create;

  FSndPlayer := GetLightPlayer;

  FCommonTextures.Load(FAtlas);

  FGlyphsCache := TGlypsCache.Create(FAtlas);

  FSpawnManager := TSpawnManager.Create(Self);
end;

destructor TWorld.Destroy;
var obj: TGameObject;
    i: Integer;
begin
  FInDestroy := True;
  FSndPlayer := nil;

  FreeAndNil(FSpawnManager);
  FreeAndNil(FGlyphsCache);
  FreeAndNil(FRayCaster);
  FreeAndNil(FTreeQuery);
  FreeAndNil(Fb2ContactListener);
  FreeAndNil(Fb2ContactFilter);

  FTempObjs.Clear;
  FObjects.Reset;
  while FObjects.Next(obj) do
    FTempObjs.Add(obj);
  for i := 0 to FTempObjs.Count - 1 do
    FTempObjs[i].Free;

  Fb2World.Free;
  inherited Destroy;
end;

function TWorld.EnemiesCount: Integer;
var go: TGameObject;
begin
  Result := 0;
  FObjects.Reset;
  while FObjects.Next(go) do
    if (go is TTowerTank) and not(go is TPlayer) then
      Inc(Result);
end;

{ TGameObject }

procedure TGameObject.SubscribeForUpdateStep;
begin
  FWorld.FUpdateSubs.Add(Self);
end;

procedure TGameObject.UpdateStep;
var i: Integer;
begin
  for i := 0 to Length(FRes.spine) - 1 do
    if (FRes.spine[i].SpineAnim <> nil) then
      FRes.spine[i].SpineAnim.Update(PHYS_STEP/1000);
end;

procedure TGameObject.DoSetResource(const ARes: TGameResource);
begin
  FRes := ARes;
  if Length(FRes.spine) > 0 then
    SubscribeForUpdateStep;
end;

function TGameObject.GetTransform: TMat3;
begin
  Result := IdentityMat3;
  Result.OX := Dir;
  Result.OY := Rotate90(Dir, False);
  Result.Pos := Pos;
end;

function TGameObject.GetTransformInv: TMat3;
begin
  Result := Inv(GetTransform());
end;

procedure TGameObject.SetResource(const ARes: TGameResource);
begin
  DoSetResource(ARes);
end;

function TGameObject.HasSpineTris: Boolean;
begin
  Result := ((FRes.tris <> nil) and (FRes.tris.Count > 0)) or (FRes.spine <> nil);
end;

procedure TGameObject.LoadingComplete;
begin

end;

procedure TGameObject.Draw(const ASpineVertices: ISpineExVertices);
var
  v: TSpineVertexEx;
  m: TMat3;
  i: Integer;
begin
  if FRes.tris <> nil then
  begin
    m := GetTransform();
    for i := 0 to FRes.tris.Count - 1 do
    begin
      v := FRes.tris[i];
      v.vsCoord.xy := v.vsCoord.xy * m;
      ASpineVertices.Add(v);
    end;
  end;

  for i := 0 to Length(FRes.spine) - 1 do
  begin
    FRes.spine[i].SpineAnim.Apply(FRes.spine[i].SpineSkel);
    FRes.spine[i].SpineSkel.WriteVertices(GetSpineVertexCallBack(ASpineVertices, GetTransform()), 0);
  end;
end;

procedure TGameObject.DrawLightSources(const ALights: ILightInfoArr);
begin

end;

procedure TGameObject.DrawShadowCasters(const AShadowCasters: IShadowVertices);
var m : TMat3;
    v : TShadowVertex;
    i, j: Integer;
begin
  if FRes.shadowcasters = nil then Exit;

  m := Mat3(size, normalize(dir), pos);
  for i := 0 to Length(FRes.shadowcasters) - 1 do
  begin
    if Length(FRes.shadowcasters[i]) < 2 then Continue;
    v.vsCoord := FRes.shadowcasters[i][0] * m;
    for j := 1 to Length(FRes.shadowcasters[i]) - 1 do
    begin
      AShadowCasters.Add(v);
      v.vsCoord := FRes.shadowcasters[i][j] * m;
      AShadowCasters.Add(v);
    end;
    AShadowCasters.Add(v);
    v.vsCoord := FRes.shadowcasters[i][0] * m;
    AShadowCasters.Add(v);
  end;
end;

procedure TGameObject.DrawUI(const ASpineVertices: ISpineExVertices);
begin

end;

function TGameObject.HasParticles: Boolean;
begin
  Result := False;
end;

procedure TGameObject.DrawParticles(const AParticlesArr: IParticleGroupArr);
begin

end;

constructor TGameObject.Create(const AWorld: TWorld);
begin
  FWorld := AWorld;
  if FWorld <> nil then
    FWorld.FObjects.Add(Self);
end;

destructor TGameObject.Destroy;
begin
  if FWorld <> nil then
  begin
    FWorld.FObjects.Delete(Self);
    FWorld.FToDestroy.Delete(Self);
    FWorld.FUpdateSubs.Delete(Self);
  end;
  inherited Destroy;
end;

{ TGlypsCache.TKeyEqualityComparer }

function TGlypsCache.TKeyEqualityComparer.Hash(const Value): Cardinal;
var V: TGlyphKey absolute Value;
    fl: string;
begin
  Result := Murmur2DefSeed(V.ch, SizeOf(WideChar));
  if Length(V.font) > 0 then
    Result := Result xor Murmur2DefSeed(V.font[1], Length(V.font)*SizeOf(Char));
  Result := Result xor Murmur2DefSeed(V.size, SizeOf(v.size));
end;

function TGlypsCache.TKeyEqualityComparer.IsEqual(const Left, Right): Boolean;
var L: TGlyphKey absolute Left;
    R: TGlyphKey absolute Right;
begin
  Result := (L.ch = R.ch) and (L.size = R.size) and (L.font = R.font);
end;

{ TGlypsCache }

constructor TGlypsCache.Create(const AAtlas: TavAtlasArrayReferenced);
var eq: IEqualityComparer;
begin
  eq := TKeyEqualityComparer.Create;
  FAtlas := AAtlas;
  FGlyphs:= TGlyphsMap.Create(eq);
end;

function TGlypsCache.ObtainGlyph(const AGlyph: WideChar; const AFont: string; const ASize: Integer): ISpriteIndex;
var key: TGlyphKey;
begin
  key.ch := AGlyph;
  key.font := AFont;
  key.size := ASize;
  if not FGlyphs.TryGetValue(key, Result) then
  begin
    Result := FAtlas.ObtainSprite( RenderGlyph(AGlyph, AFont, ASize) );
    FGlyphs.AddOrSet(key, Result);
  end;
end;

procedure TGlypsCache.ObtainGlyphs(const AGlyphs: string; const AFont: string; const ASize: Integer; const AOut: ISpriteIndexArr);
var s: WideString;
    i: Integer;
begin
  s := WideString(AGlyphs);
  for i := 1 to Length(s) do
    AOut.Add(ObtainGlyph(s[i], AFont, ASize));
end;

function TGlypsCache.RenderGlyph(const AGlyph: WideChar; const AFont: string; const ASize: Integer): ITextureMip;
var ABCMetrics: TVec3i;
begin
  Result := GenerateGlyphImage(AFont, AGlyph, ASize, False, False, False, ABCMetrics);
end;

{ TSpawnObject }

procedure TSpawnObject.LoadingComplete;
begin
  inherited;
  World.SpawnManager.Add(Self);
end;

{ TSpawnManager }

procedure TSpawnManager.Add(const AObj: TSpawnObject);
begin
  FSpawners.Insert(AObj);
end;

function TSpawnManager.Count: Integer;
begin
  Result := FSpawners.Count;
end;

constructor TSpawnManager.Create(const AWorld: TWorld);
var c: IComparer;
begin
  FWorld := AWorld;
  c := TPriorityComparer.Create;
  FSpawners := TSpawnHeap.Create(10, c);
end;

function TSpawnManager.IsReadyForSpawnNext: Boolean;
begin
  Result := (FNextSpawnTime < FWorld.Time) and (FWorld.EnemiesCount < 3) and (FSpawners.Count > 0);
end;

procedure TSpawnManager.UpdateState;
var spawn: TSpawnObject;
begin
  if IsReadyForSpawnNext() then
  begin
    spawn := FSpawners.ExtractTop;
    spawn.Spawn();
    FNextSpawnTime := FWorld.Time + 5000;
  end;
end;

{ TSpawnManager.TPriorityComparer }

function TSpawnManager.TPriorityComparer.Compare(const Left,  Right): Integer;
var L: TGameObject absolute Left;
    R: TGameObject absolute Right;
begin
  Result := Ord(L.Layer) - Ord(R.Layer);
  if Result <> 0 then Exit;
  Result := L.ZIndex - R.ZIndex;
end;

{ TSpawnObjectSprite }

procedure TSpawnObjectSprite.AfterConstruction;
begin
  inherited;
  FSize := Vec(1,1);
end;

function TSpawnObjectSprite.GetAngle: Single;
begin
  Result := FAngle;
end;

function TSpawnObjectSprite.GetDir: TVec2;
begin
  Result := VecSinCos(FAngle);
end;

function TSpawnObjectSprite.GetPos: TVec2;
begin
  Result := FPos;
end;

function TSpawnObjectSprite.GetSize: TVec2;
begin
  Result := FSize;
end;

procedure TSpawnObjectSprite.SetAngle(const Value: Single);
begin
  FAngle := Value;
end;

procedure TSpawnObjectSprite.SetDir(const Value: TVec2);
begin
  FAngle := ArcTan2(Value.y, Value.x);
end;

procedure TSpawnObjectSprite.SetPos(const Value: TVec2);
begin
  FPos := Value;
end;

procedure TSpawnObjectSprite.SetSize(const Value: TVec2);
begin
  FSize := Value;
end;

end.
