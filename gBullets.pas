unit gBullets;

{$IfDef FPC}
  {$mode objfpc}{$H+}
  {$ModeSwitch advancedrecords}
{$EndIf}

interface

uses
  gWorld, gTypes,
  UPhysics2D, UPhysics2DTypes,
  mutils, avRes,
  avContnrs,
  intfUtils;

type
  TBulletOwnerKind = (bokPlayer, bokBot);
  TOwnerInfo = packed record
    obj : IWeakRef; //TGameObject weak ref
    kind: TBulletOwnerKind;
    procedure Init(const AGameObject: TGameObject; const AKind: TBulletOwnerKind);
  end;

  TBullet = class (TGameDynamicBody)
  private
    FDeadTime: Int64;
    FOwner: TOwnerInfo;
  protected
    procedure UpdateStep; override;
    function  GetLiveTime: Integer; virtual; abstract;
  public
    procedure SetDefaultState(const AStartPos, AEndPos: TVec2; const ADir: TVec2; const AStartVel: TVec2);

    property  Owner : TOwnerInfo read FOwner write FOwner;
    procedure AfterConstruction; override;
  end;

  TRocket = class (TBullet)
  protected
    function Filter_UnitsOnly(const AObj: TGameBody): Boolean;

    procedure UpdateStep; override;
    function  GetLiveTime: Integer; override;
    function  CreateBodyDef(const APos: TVector2; const AAngle: Double): Tb2BodyDef; override;
  protected
    procedure OnHit(const AFixture: Tb2Fixture; const ThisFixture: Tb2Fixture; const AManifold: Tb2WorldManifold); override;
  public
    procedure DrawLightSources(const ALights: ILightInfoArr); override;

    procedure AfterConstruction; override;
  end;

  TSimpleGun = class (TBullet)
  protected
//    function Filter_UnitsOnly(const AObj: TGameBody): Boolean;

    procedure UpdateStep; override;
    function  CreateFixutreDefForShape(const AShape: Tb2Shape): Tb2FixtureDef; override;
    function  GetLiveTime: Integer; override;
    function  CreateBodyDef(const APos: TVector2; const AAngle: Double): Tb2BodyDef; override;
  protected
    procedure OnHit(const AFixture: Tb2Fixture; const ThisFixture: Tb2Fixture; const AManifold: Tb2WorldManifold); override;
  public
    procedure DrawLightSources(const ALights: ILightInfoArr); override;

    procedure AfterConstruction; override;
  end;

  TTeslaRay = class (TGameSprite)
  private type
    IRayPoints = {$IfDef FPC}specialize{$EndIf} IArray<TVec2>;
    TRayPoints = {$IfDef FPC}specialize{$EndIf} TArray<TVec2>;
  private
    FDeadTime: Int64;
    FOwner: TOwnerInfo;

    FRayPoints: IRayPoints;
    FRayPointsVel: IRayPoints;

    FLightingColor: TVec4;

    function Filter_ExcludeOwner(const AObj: TGameBody): Boolean;
  protected
    procedure UpdateStep; override;
    function  GetLiveTime: Integer;
  public
    procedure SetDefaultState(AStartPos, AEndPos: TVec2);

    property  Owner : TOwnerInfo read FOwner write FOwner;
    procedure AfterConstruction; override;

    function  HasSpineTris: Boolean; override;
    procedure Draw(const ASpineVertices: ISpineExVertices); override;
    procedure DrawLightSources(const ALights: ILightInfoArr); override;
  end;

implementation

uses
  gEffects, gUnits;

{ TBullet }

procedure TRocket.AfterConstruction;
const H : Single = 0.1;
      W : Single = 0.3;
var
  res: TGameResource;
begin
  inherited;
  res.Clear;
  SetLength(res.spine, 1);
  res.spine[0].LoadFromDir('rocket', World.Atlas);
  SetLength(res.fixtures_poly, 1);
  SetLength(res.fixtures_poly[0], 3);
  res.fixtures_poly[0][0] := Vec(0,  H);
  res.fixtures_poly[0][1] := Vec(W,  0);
  res.fixtures_poly[0][2] := Vec(0, -H);
  SetResource(res);
end;

function TRocket.CreateBodyDef(const APos: TVector2; const AAngle: Double): Tb2BodyDef;
begin
  Result := Tb2BodyDef.Create;
  Result.bodyType := b2_dynamicBody;
  Result.userData := Self;
  Result.position := APos;
  Result.angle := AAngle;
  Result.linearDamping := 0.2;
  Result.angularDamping := 0.2;
  Result.allowSleep := True;
end;

procedure TRocket.DrawLightSources(const ALights: ILightInfoArr);
var ls: TLightInfo;
    k : Single;
begin
  inherited;
  k := 0.3 + Sin(World.Time * 0.1)*0.1;
  ls.LightKind := 0;
  ls.LightPos := Vec(-0.6, 0) * GetTransform();
  ls.LightDist := 3;
  ls.LightColor := Vec(0.988235294117647, 0.792156862745098, 0.0117647058823529, 1.0)*k;
  ALights.Add(ls);
end;

function TRocket.Filter_UnitsOnly(const AObj: TGameBody): Boolean;
begin
  Result := AObj is TUnit;
end;

function TRocket.GetLiveTime: Integer;
begin
  Result := 4000;
end;

procedure TRocket.OnHit(const AFixture, ThisFixture: Tb2Fixture; const AManifold: Tb2WorldManifold);
const ROCKET_MAX_DMG = 30;
      ROCKET_MAX_RAD = 7;
var hittedBody: TGameBody;
    objs: IGameObjArr;
    unt: TUnit;
    i: Integer;
    dmgPower: Single;
    dmgDir  : TVec2;
    k: Single;

    explosion: TExplosion;
begin
  inherited;
  objs := QueryObjects(ROCKET_MAX_RAD, {$IfDef FPC}@{$EndIf}Filter_UnitsOnly);
  hittedBody := TGameBody(AFixture.GetBody.UserData);
  for i := 0 to objs.Count - 1 do
  begin
    unt := objs[i] as TUnit;
    if unt = hittedBody then
    begin
      dmgPower := ROCKET_MAX_DMG;
      dmgDir := unt.Pos - Pos + Dir;
    end
    else
    begin
      dmgDir := unt.Pos - Pos;
      k := 1 - clamp(Len(dmgDir)/ROCKET_MAX_RAD, 0, 1);
      k := k * k;
      dmgPower := ROCKET_MAX_DMG * k;
    end;
    unt.DealDamage(dmgPower, normalize(dmgDir), dmgPower*100, Owner);
  end;

  explosion := TExplosion.Create(World);
  explosion.Layer := glGameFore;
  explosion.ZIndex := 0;
  explosion.Pos := Pos - Dir*0.25;
  explosion.Angle := Random * 2 * Pi;

  World.SafeDestroy(Self);
end;

procedure TRocket.UpdateStep;
var v: TVec2;
begin
  inherited;
  v := Dir * 40.0;
  MainBody.ApplyForceToCenter(TVector2.From(v.x, v.y));
end;

procedure TBullet.SetDefaultState(const AStartPos, AEndPos, ADir, AStartVel: TVec2);
begin
  Pos := AStartPos;
  if LenSqr(ADir) = 0 then
    Dir := Vec(1, 0)
  else
    Dir := ADir;
  Velocity := AStartVel;
end;

procedure TBullet.UpdateStep;
begin
  inherited;
  if FDeadTime < World.Time then
    World.SafeDestroy(Self);
end;

{ TBullet }

procedure TBullet.AfterConstruction;
begin
  inherited;
  FDeadTime := World.Time + GetLiveTime();
  SubscribeForUpdateStep;
end;

{ TOwnerInfo }

procedure TOwnerInfo.Init(const AGameObject: TGameObject; const AKind: TBulletOwnerKind);
begin
  obj := nil;
  if AGameObject <> nil then
    obj := AGameObject.WeakRef;
  kind := AKind;
end;

{ TSimpleGun }

procedure TSimpleGun.AfterConstruction;
var
  res: TGameResource;
  size: TVec2;
begin
  inherited;
  res.Clear;
  SetLength(res.images, 1);
  res.images[0] := World.GetCommonTextures.BulletTrace;
  size := Vec(res.images[0].Data.Width, res.images[0].Data.Height) / 80;
  res.tris := TSpineExVertices.Create;
  Draw_Sprite(res.tris, Vec(-size.x*0.5+size.y,0), Vec(1,0), size, res.images[0]);
  //Draw_Sprite(res.tris, Vec(0,0), Vec(1,0), size, res.images[0]);
  SetLength(res.fixtures_cir, 1);
  res.fixtures_cir[0] := Vec(0,0,size.y*0.5);
  SetResource(res);
end;

function TSimpleGun.CreateBodyDef(const APos: TVector2; const AAngle: Double): Tb2BodyDef;
begin
  Result := Tb2BodyDef.Create;
  Result.bodyType := b2_dynamicBody;
  Result.userData := Self;
  Result.position := APos;
  Result.angle := AAngle;
  Result.linearDamping := 0.05;
  Result.angularDamping := 0.05;
  Result.allowSleep := True;
end;

function TSimpleGun.CreateFixutreDefForShape(const AShape: Tb2Shape): Tb2FixtureDef;
begin
  Result := inherited CreateFixutreDefForShape(AShape);
  Result.restitution := 0.3;
  Result.density := 13.0;
end;

procedure TSimpleGun.DrawLightSources(const ALights: ILightInfoArr);
var ls: TLightInfo;
    k : Single;
    m : TMat3;
begin
  inherited;
//  m := GetTransform();
//
//  k := 0.1;
//  ls.LightKind := 0;
//  ls.LightPos := Vec(-0.2, 0)*m;
//  ls.LightDist := 1.0;
//  ls.LightColor := Vec(0.988235294117647, 0.792156862745098, 0.0117647058823529, 1.0)*k;
//  ALights.Add(ls);
end;

function TSimpleGun.GetLiveTime: Integer;
begin
  Result := 3000;
end;

procedure TSimpleGun.OnHit(const AFixture, ThisFixture: Tb2Fixture; const AManifold: Tb2WorldManifold);
const BULLET_MAX_DMG = 7;
var
  hittedBody: TGameBody;
  unt: TUnit;
  hitpower: Single;
begin
  inherited;
  hittedBody := TGameBody(AFixture.GetBody.UserData);
  if hittedBody is TUnit then
  begin
    unt := hittedBody as TUnit;
    hitpower := Len(Velocity)/80;
    unt.DealDamage(hitpower, unt.Pos - Pos, 0, Owner);
  end;
end;

procedure TSimpleGun.UpdateStep;
var v: TVec2;
begin
  inherited;
  v := Velocity;
  Dir := v;
  if LenSqr(v) < Sqr(20) then World.SafeDestroy(Self);
end;

{ TTeslaRay }

procedure TTeslaRay.AfterConstruction;
begin
  inherited;
  FDeadTime := World.Time + GetLiveTime;
  SubscribeForUpdateStep;
  FLightingColor := Vec(0.5,1.0,1.0,1.0);
end;

procedure TTeslaRay.Draw(const ASpineVertices: ISpineExVertices);
var sprite: ISpriteIndex;
    i: Integer;
begin
  inherited;
  sprite := World.GetCommonTextures.WhitePix;
  for i := 0 to FRayPoints.Count - 2 do
    Draw_Line(ASpineVertices, sprite, FRayPoints[i], FRayPoints[i+1], 0.1, FLightingColor);
end;

procedure TTeslaRay.DrawLightSources(const ALights: ILightInfoArr);
var i: Integer;
    ls: TLightInfo;
begin
  inherited;
  ls.LightKind := 0;
  ls.LightColor := FLightingColor*0.15;
  ls.LightDist := 5.0;
  for i := 0 to FRayPoints.Count - 1 do
  begin
    ls.LightPos := FRayPoints[i];
    ALights.Add(ls);
  end;
end;

function TTeslaRay.Filter_ExcludeOwner(const AObj: TGameBody): Boolean;
begin
  if not (AObj is TUnit) then Exit(False);
  if FOwner.obj <> nil then
    if FOwner.obj.Obj = AObj then Exit(False);
  Result := True;
end;

function TTeslaRay.GetLiveTime: Integer;
begin
  Result := PHYS_STEP * 15;
end;

function TTeslaRay.HasSpineTris: Boolean;
begin
  Result := (FRayPoints <> nil) and (FRayPoints.Count > 1);
end;

procedure TTeslaRay.SetDefaultState(AStartPos, AEndPos: TVec2);

const TESLA_RANGE = 8;

  procedure GenerateRay(const Pt1, Pt2, Vel: TVec2);
  var midPt: TVec2;
      n: TVec2;
      s: Single;
  begin
    n := Rotate90(Pt2 - Pt1, Random(2) = 0);
    if LenSqr(n) < sqr(2.0) then Exit;
    n := n * 0.08;
    midPt := Lerp(Pt1, Pt2, 0.5 + Random()*0.2 - 0.1) + n;

    if Random(2) = 0 then s := -1 else s := 1;
    s := s * (Random()*3);
    n := n * s + Vel;

    GenerateRay(Pt1, midPt, n);
    FRayPoints.Add(midPt);
    FRayPointsVel.Add(n);
    GenerateRay(midPt, Pt2, n);
  end;

var objs: IGameObjArr;
    minDist, Dist: Single;
    obj: TGameObject;
    I: Integer;
    v1, v2: TVec2;
    shootDir: TVec2;
begin
  shootDir := AEndPos - AStartPos;
  if LenSqr(shootDir) > sqr(TESLA_RANGE) then
  begin
    shootDir := SetLen(shootDir, TESLA_RANGE);
    AEndPos := AStartPos + shootDir;
  end;

  obj := nil;
  minDist := 4;
  objs := World.QueryObjects(AEndPos, minDist, {$IfDef FPC}@{$EndIf}Filter_ExcludeOwner);
  for I := 0 to objs.Count-1 do
  begin
    Dist := Len(AEndPos - objs[i].Pos);
    if Dist < minDist then
    begin
      obj := objs[i];
      minDist := Dist;
    end;
  end;
  if obj <> nil then
    AEndPos := obj.Pos;

  if FOwner.obj <> nil then
    v1 := TUnit(FOwner.obj.Obj).Velocity
  else
    v1 := Vec(0,0);

  if obj is TGameDynamicBody then
    v2 := TGameDynamicBody(obj).Velocity
  else
    v2 := Vec(0,0);

  FRayPoints := TRayPoints.Create;
  FRayPointsVel := TRayPoints.Create;
  FRayPoints.Add(AStartPos);
  FRayPointsVel.Add(v1);
  GenerateRay(AStartPos, AEndPos, (v1+v2)*0.5);
  FRayPoints.Add(AEndPos);
  FRayPointsVel.Add(v2);

  if (obj <> nil) and (obj is TUnit) then
    TUnit(obj).DealDamage(2, Normalize(AEndPos - AStartPos), 0, FOwner);
end;

procedure TTeslaRay.UpdateStep;
var i, n: Integer;
    kk: Single;
begin
  inherited;
  if FDeadTime <= World.Time then
    World.SafeDestroy(Self);
  n := FRayPoints.Count - 1;
  for i := 0 to n do
  begin
    kk := 1.0 - abs(i/n - 0.5)*2.0;
    FRayPoints[i] := FRayPoints[i] + FRayPointsVel[i] * (PHYS_STEP/1000*(kk*Random*2));
  end;
end;

end.
