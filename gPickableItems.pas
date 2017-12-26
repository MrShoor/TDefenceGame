unit gPickableItems;

interface

uses
  gWorld, gTypes,
  UPhysics2D, UPhysics2DTypes, B2Utils,
  mutils, avRes, gUnits,
  avContnrs,
  intfUtils;

type
  TPickItem = class(TGameSingleBody)
  private
  protected
    FPicked: Boolean;
    FAllowRotate: Boolean;
    function CreateFixutreDefForShape(const AShape: Tb2Shape): Tb2FixtureDef; override;
    function CreateBodyDef(const APos: TVector2; const AAngle: Double): Tb2BodyDef; override;
  protected
    FOnHitLeave : IWeakedInterface;
    procedure OnHit(const AFixture: Tb2Fixture; const ThisFixture: Tb2Fixture; const AManifold: Tb2WorldManifold); virtual;
    procedure OnLeave(const AFixture: Tb2Fixture; const ThisFixture: Tb2Fixture); virtual;

    procedure DoSetResource(const ARes: TGameResource); override;

    procedure OnTankHit(const AUnit: TTowerTank); virtual; abstract;
    procedure GetResource(out ASprite: ISpriteIndex; out AllowRotate: Boolean; out AScale: Single); virtual; abstract;
  public
    function GetTransform(): TMat3; override;
    procedure AfterConstruction; override;
  end;

  TPickItem_HP = class(TPickItem)
  private
  protected
    procedure OnTankHit(const AUnit: TTowerTank); override;
    procedure GetResource(out ASprite: ISpriteIndex; out AllowRotate: Boolean; out AScale: Single); override;
  public
  end;

  TPickItem_Speed = class(TPickItem)
  private
  protected
    procedure OnTankHit(const AUnit: TTowerTank); override;
    procedure GetResource(out ASprite: ISpriteIndex; out AllowRotate: Boolean; out AScale: Single); override;
  public
  end;

  TPickItem_FireRate = class(TPickItem)
  private
  protected
    procedure OnTankHit(const AUnit: TTowerTank); override;
    procedure GetResource(out ASprite: ISpriteIndex; out AllowRotate: Boolean; out AScale: Single); override;
  public
  end;

  TPickItem_Canon_RocketMini = class(TPickItem)
  private
  protected
    procedure OnTankHit(const AUnit: TTowerTank); override;
    procedure GetResource(out ASprite: ISpriteIndex; out AllowRotate: Boolean; out AScale: Single); override;
  public
  end;

  TPickItem_Canon_Rocket = class(TPickItem)
  private
  protected
    procedure OnTankHit(const AUnit: TTowerTank); override;
    procedure GetResource(out ASprite: ISpriteIndex; out AllowRotate: Boolean; out AScale: Single); override;
  public
  end;

  TPickItem_Canon_Tesla = class(TPickItem)
  private
  protected
    procedure OnTankHit(const AUnit: TTowerTank); override;
    procedure GetResource(out ASprite: ISpriteIndex; out AllowRotate: Boolean; out AScale: Single); override;
  public
  end;

  TPickItem_Canon_Grenade = class(TPickItem)
  private
  protected
    procedure OnTankHit(const AUnit: TTowerTank); override;
    procedure GetResource(out ASprite: ISpriteIndex; out AllowRotate: Boolean; out AScale: Single); override;
  public
  end;

implementation

uses
  Math;

{ TPickItem }

procedure TPickItem.AfterConstruction;
var
  res : TGameResource;
  lsize: TVec2;
  s: Single;
begin
  inherited;
  res.Clear;
  SetLength(res.images, 1);
  GetResource(res.images[0], FAllowRotate, s);
  lsize := Vec(res.images[0].Data.Width, res.images[0].Data.Height) / 80;
  lsize := lsize * s;
  res.tris := TSpineExVertices.Create;
  Draw_Sprite(res.tris, Vec(0,0), Vec(1,0), lsize, res.images[0]);
  SetLength(res.fixtures_cir, 1);
  res.fixtures_cir[0] := Vec(0,0,(lsize.y+lsize.x)*0.25);
  SetResource(res);

  Layer  := glGame;
  ZIndex := 0;
end;

function TPickItem.CreateBodyDef(const APos: TVector2; const AAngle: Double): Tb2BodyDef;
begin
  Result := Tb2BodyDef.Create;
  Result.bodyType := b2_staticBody;
  Result.userData := Self;
  Result.position := APos;
  Result.angle := AAngle;
end;

function TPickItem.CreateFixutreDefForShape(const AShape: Tb2Shape): Tb2FixtureDef;
begin
  Result := Tb2FixtureDef.Create;
  Result.shape := AShape;
  Result.isSensor := True;
end;

procedure TPickItem.DoSetResource(const ARes: TGameResource);
begin
  inherited;
  FOnHitLeave := TOnHitSubscriber.Create(MainBody, {$IfDef FPC}@{$EndIf}OnHit, {$IfDef FPC}@{$EndIf}OnLeave);
  World.b2ContactListener.Subscribe(FOnHitLeave);
end;

function TPickItem.GetTransform: TMat3;
var m: TMat3;
    s: Single;
    rot: Single;
begin
  s := 1 + sin(World.Time*0.004)*0.2;
  if FAllowRotate then
    rot := World.Time*0.001
  else
    rot := 0;
  Result := Mat3(Vec(s, s), rot, Vec(0,0)) * inherited GetTransform();
end;

procedure TPickItem.OnHit(const AFixture, ThisFixture: Tb2Fixture; const AManifold: Tb2WorldManifold);
var b: Tb2Body;
    o: TGameObject;
begin
  if FPicked then Exit;

  b := AFixture.GetBody;
  if b = nil then Exit;
  o := TGameObject(b.UserData);
  if not (o is TTowerTank) then Exit;
  OnTankHit(o as TTowerTank);
end;

procedure TPickItem.OnLeave(const AFixture, ThisFixture: Tb2Fixture);
begin

end;

{ TPickItem_HP }

procedure TPickItem_HP.GetResource(out ASprite: ISpriteIndex; out AllowRotate: Boolean; out AScale: Single);
begin
  ASprite := World.GetCommonTextures^.hp;
  AllowRotate := False;
  AScale := 1.5;
end;

procedure TPickItem_HP.OnTankHit(const AUnit: TTowerTank);
begin
  if AUnit.HP < AUnit.MaxHP then
  begin
    AUnit.HP := Min(AUnit.HP + 150, AUnit.MaxHP);
    World.SafeDestroy(Self);
    World.PlaySound('pick_aidkid', Pos, Vec(0,0));
    FPicked := True;
  end;
end;

{ TPickItem_Speed }

procedure TPickItem_Speed.GetResource(out ASprite: ISpriteIndex; out AllowRotate: Boolean; out AScale: Single);
begin
  ASprite := World.GetCommonTextures^.speed;
  AllowRotate := False;
  AScale := 1.5;
end;

procedure TPickItem_Speed.OnTankHit(const AUnit: TTowerTank);
var t: Int64;
begin
  t := Max(AUnit.SpeedBoost, World.Time);
  t := t + 7000;
  AUnit.SpeedBoost := t;
  World.SafeDestroy(Self);
  FPicked := True;
  World.PlaySound('pkup', Pos, Vec(0,0));
end;

{ TPickItem_FireRate }

procedure TPickItem_FireRate.GetResource(out ASprite: ISpriteIndex; out AllowRotate: Boolean; out AScale: Single);
begin
  ASprite := World.GetCommonTextures^.firerate;
  AllowRotate := False;
  AScale := 1.5;
end;

procedure TPickItem_FireRate.OnTankHit(const AUnit: TTowerTank);
var t: Int64;
begin
  t := Max(AUnit.FireRateBoost, World.Time);
  t := t + 7000;
  AUnit.FireRateBoost := t;
  World.SafeDestroy(Self);
  FPicked := True;
  World.PlaySound('pkup', Pos, Vec(0,0));
end;

{ TPcikItem_Canon_RocketMini }

procedure TPickItem_Canon_RocketMini.GetResource(out ASprite: ISpriteIndex; out AllowRotate: Boolean; out AScale: Single);
begin
  ASprite := World.GetCommonTextures^.canon_rocket_mini;
  AllowRotate := True;
  AScale := 1;
end;

procedure TPickItem_Canon_RocketMini.OnTankHit(const AUnit: TTowerTank);
begin
  if not (AUnit is TPlayer) then Exit;
  TPlayer(AUnit).Ammo_MiniRocket := TPlayer(AUnit).Ammo_MiniRocket + 15;
  World.SafeDestroy(Self);
  FPicked := True;
  World.PlaySound('pick_ammo', Pos, Vec(0,0));
end;

{ TPickItem_Canon_Rocket }

procedure TPickItem_Canon_Rocket.GetResource(out ASprite: ISpriteIndex; out AllowRotate: Boolean; out AScale: Single);
begin
  ASprite := World.GetCommonTextures^.canon_rocket;
  AllowRotate := True;
  AScale := 1;
end;

procedure TPickItem_Canon_Rocket.OnTankHit(const AUnit: TTowerTank);
begin
  if not (AUnit is TPlayer) then Exit;
  TPlayer(AUnit).Ammo_Rocket := TPlayer(AUnit).Ammo_Rocket + 15;
  World.SafeDestroy(Self);
  FPicked := True;
  World.PlaySound('pick_ammo', Pos, Vec(0,0));
end;

{ TPickItem_Canon_Tesla }

procedure TPickItem_Canon_Tesla.GetResource(out ASprite: ISpriteIndex; out AllowRotate: Boolean; out AScale: Single);
begin
  ASprite := World.GetCommonTextures^.canon_tesla;
  AllowRotate := True;
  AScale := 1;
end;

procedure TPickItem_Canon_Tesla.OnTankHit(const AUnit: TTowerTank);
begin
  if not (AUnit is TPlayer) then Exit;
  TPlayer(AUnit).Ammo_Tesla := TPlayer(AUnit).Ammo_Tesla + 100;
  World.SafeDestroy(Self);
  FPicked := True;
  World.PlaySound('pick_ammo', Pos, Vec(0,0));
end;

{ TPickItem_Canon_Grenade }

procedure TPickItem_Canon_Grenade.GetResource(out ASprite: ISpriteIndex; out AllowRotate: Boolean; out AScale: Single);
begin
  ASprite := World.GetCommonTextures^.canon_grenades;
  AllowRotate := True;
  AScale := 1;
end;

procedure TPickItem_Canon_Grenade.OnTankHit(const AUnit: TTowerTank);
begin
  if not (AUnit is TPlayer) then Exit;
  TPlayer(AUnit).Ammo_Grenade := TPlayer(AUnit).Ammo_Grenade + 20;
  World.SafeDestroy(Self);
  FPicked := True;
  World.PlaySound('pick_ammo', Pos, Vec(0,0));
end;

end.
