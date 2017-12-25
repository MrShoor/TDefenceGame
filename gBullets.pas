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
    procedure SetDefaultState(const AStartPos: TVec2; const ADir: TVec2; const AStartVel: TVec2);

    procedure DrawLightSources(const ALights: ILightInfoArr); override;

    procedure AfterConstruction; override;
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
    unt.DealDamage(dmgPower, normalize(dmgDir), Owner);
  end;

  explosion := TExplosion.Create(World);
  explosion.Layer := glGameFore;
  explosion.ZIndex := 0;
  explosion.Pos := Pos;
  explosion.Angle := Random * 2 * Pi;

  World.SafeDestroy(Self);
end;

procedure TRocket.SetDefaultState(const AStartPos, ADir, AStartVel: TVec2);
begin
  Pos := AStartPos;
  if LenSqr(ADir) = 0 then
    Dir := Vec(1, 0)
  else
    Dir := ADir;
  Velocity := AStartVel;
end;

procedure TRocket.UpdateStep;
var v: TVec2;
begin
  inherited;
  v := Dir * 24.0;
  MainBody.ApplyForceToCenter(TVector2.From(v.x, v.y));
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

end.
