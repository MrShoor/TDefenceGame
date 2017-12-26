unit gEffects;

interface

uses
  gWorld, gTypes,
  UPhysics2D, UPhysics2DTypes,
  mutils, avRes,
  intfUtils;

type
  TExplosion = class(TGameSprite)
  private const
    cLIFE_TIME = 350;
  private
    FDeadTime: Int64;
    FExplosionScale: Single;
  protected
    procedure UpdateStep; override;
  public
    function GetTransform: TMat3; override;

    property ExplosionScale: Single read FExplosionScale write FExplosionScale;
    procedure DrawLightSources(const ALights: ILightInfoArr); override;
    procedure AfterConstruction; override;
  end;

  TExplosiveFire = class(TGameSprite)
  private const
    cLIFE_TIME = 5000;
  private
    FDeadTime: Int64;
    FAttachedObject: IWeakRef;
    function GetAttachedObject: TGameObject;
    procedure SetAttachedObject(const Value: TGameObject);
  protected
    procedure UpdateStep; override;
  public
    property AttachedObject: TGameObject read GetAttachedObject write SetAttachedObject;
    procedure DrawLightSources(const ALights: ILightInfoArr); override;
    procedure AfterConstruction; override;
  end;

implementation

uses
  gUnits, gBullets;

{ TExplosion }

procedure TExplosion.AfterConstruction;
var
  res: TGameResource;
begin
  inherited;
  res.Clear;
  SetLength(res.spine, 1);
  res.spine[0].LoadFromDir('explosion', World.Atlas);
  SetResource(res);

  FDeadTime := World.Time + cLIFE_TIME;

  FExplosionScale := 1;

  SubscribeForUpdateStep;
end;

procedure TExplosion.DrawLightSources(const ALights: ILightInfoArr);
var ls: TLightInfo;
    k: Single;
begin
  inherited;
  k := (FDeadTime - World.Time)/cLIFE_TIME;
  k := Clamp(k, 0, 1);
  k := k * k;

  ls.LightKind := 0;
  ls.LightPos := Vec(-0.6, 0) * GetTransform();
  ls.LightDist := 10*ExplosionScale;
  ls.LightColor := Vec(0.988235294117647, 0.792156862745098, 0.0117647058823529, 1.0)*k;
  ALights.Add(ls);
end;

function TExplosion.GetTransform: TMat3;
begin
  Result := Mat3Scale(Vec(FExplosionScale, FExplosionScale)) * inherited GetTransform();
end;

procedure TExplosion.UpdateStep;
begin
  inherited;
  if FDeadTime < World.Time then
    World.SafeDestroy(Self);
end;

{ TExplosiveFire }

procedure TExplosiveFire.AfterConstruction;
var
  res: TGameResource;
begin
  inherited;
  res.Clear;
  SetLength(res.spine, 1);
  res.spine[0].LoadFromDir('fire_loop', World.Atlas);
  SetResource(res);

  FDeadTime := World.Time + cLIFE_TIME;

  SubscribeForUpdateStep;
end;

procedure TExplosiveFire.DrawLightSources(const ALights: ILightInfoArr);
var ls: TLightInfo;
    k: Single;
begin
  inherited;
  k := 0.9 + (sin(World.Time*0.01) + 1.0) * 0.5 * 0.1;
  k := k * k;

  ls.LightKind := 0;
  ls.LightPos := Pos + Vec(Random, Random)*0.3;
  ls.LightDist := 10;
  ls.LightColor := Vec(0.988235294117647, 0.792156862745098, 0.0117647058823529, 1.0)*k;
  ALights.Add(ls);
end;

function TExplosiveFire.GetAttachedObject: TGameObject;
begin
  Result := nil;
  if FAttachedObject <> nil then
  begin
    Result := TGameObject(FAttachedObject.Obj);
    if Result = nil then FAttachedObject := nil;
  end;
end;

procedure TExplosiveFire.SetAttachedObject(const Value: TGameObject);
begin
  FAttachedObject := nil;
  if Value <> nil then
    FAttachedObject := Value.WeakRef;
end;

procedure TExplosiveFire.UpdateStep;
const MAX_DMG = 50;
      MAX_RAD = 7;
var aobj: TGameObject;
    exp : TExplosion;

    objs: IGameObjArr;
    i: Integer;
    k: Single;
    dmgDir: TVec2;
    dmgPower: Single;
    oi: TOwnerInfo;
begin
  inherited;
  aobj := AttachedObject;
  if aobj <> nil then
    Pos := aobj.Pos;

  if FDeadTime < World.Time then
  begin
    World.SafeDestroy(Self);
    if aobj <> nil then
    begin
      World.SafeDestroy(aobj);
      exp := TExplosion.Create(World);
      exp.Pos := Pos;
      exp.Angle := Random * 2 * Pi;
      exp.ExplosionScale := 3;
      exp.Layer := Layer;
      exp.ZIndex := ZIndex;

      objs := World.QueryObjects(Pos, MAX_RAD, nil);
      for i := 0 to objs.Count - 1 do
      begin
        dmgDir := objs[i].Pos - Pos;
        if LenSqr(dmgDir) = 0 then Continue;
        k := 1 - clamp(Len(dmgDir)/MAX_RAD, 0, 1);
        k := k * k;
        dmgDir := normalize(dmgDir);
        dmgPower := MAX_DMG * k;

        if objs[i] is TUnit then
        begin
          oi.Init(aobj, bokPlayer);
          TUnit(objs[i]).DealDamage(dmgPower, dmgDir, dmgPower*400, oi);
        end
        else
        if objs[i] is TGameSingleBody then
        begin
          dmgDir := dmgDir * dmgPower * 400;
          TGameSingleBody(objs[i]).MainBody.ApplyForceToCenter(TVector2.From(dmgDir.x, dmgDir.y));
        end;
      end;
    end;
  end;
end;

end.
