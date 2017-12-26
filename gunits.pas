unit gUnits;

{$IfDef FPC}
  {$mode objfpc}{$H+}
  {$ModeSwitch advancedrecords}
{$EndIf}

interface

uses
  Classes, SysUtils,
  avRes,
  gWorld, gTypes, gBullets,
  UPhysics2D, UPhysics2DTypes,
  B2Utils,
  mutils,
  SpineH,
  intfUtils;

type
  { TUnit }

  TUnit = class(TGameDynamicBody)
  private
    FMaxHP: Single;
    FHP: Single;
  protected
    procedure SetHP(const Value: Single); virtual;
    function GetMaxRotateSpeed: Single; virtual; abstract;

    procedure DoDealDamage(const APower: Single; const ADirection: TVec2; const AForceK: Single; const AOwner: TOwnerInfo); virtual;
  public
    function IsDead: Boolean;

    property MaxHP: Single read FMaxHP write FMaxHP;
    property HP: Single read FHP write SetHP;

    procedure DealDamage(const APower: Single; const ADirection: TVec2; const AForceK: Single; const AOwner: TOwnerInfo); virtual;
  end;

  TBox = class(TUnit)
  private
  protected
    function  CreateFixutreDefForShape(const AShape: Tb2Shape): Tb2FixtureDef; override;

    function GetMaxRotateSpeed: Single; override;
    procedure DoDealDamage(const APower: Single; const ADirection: TVec2; const AForceK: Single; const AOwner: TOwnerInfo); override;
  public
    procedure AfterConstruction; override;
    destructor Destroy; override;
  end;

  TBox2 = class(TBox)
  public
    procedure AfterConstruction; override;
  end;

  { TTowerTank }

  TspBonesArr = array of PspBone;

  TTowerTank = class(TUnit)
  public const
    SPEED_BOOST_RATE = 2;
    FIRE_BOOST_RATE = 2;
  protected
    FTarget: TVec2;

    FSpine: PGameSpineRes;

    FTargetBone: PspBone;
    FOutBones  : TspBonesArr;
    FFireBones : TspBonesArr;
    FFireIdx : Integer;

    FNextFireReadyTime: Int64;

    FSpeedBoost: Int64;
    FFireRateBoost: Int64;

    FIsPlayer: Boolean;
  protected
    function  GetDefaultSkin: string; virtual;
    function  GetMaxMoveSpeed: TVec2; virtual; abstract;
    function  GetReloadDuration: Integer; virtual; abstract;
    procedure DoFire(); virtual; abstract;
  protected
    procedure DoSetResource(const ARes: TGameResource); override;
  protected
    procedure ShootWithRocket(const APowerRocket: Boolean);
    procedure ShootWithMachineGun();
    procedure ShootWithTesla();
    procedure ShootWithGrenade();
    procedure DoDealDamage(const APower: Single; const ADirection: TVec2; const AForceK: Single; const AOwner: TOwnerInfo); override;
  public
    property IsPlayer: Boolean read FIsPlayer;

    property SpeedBoost: Int64 read FSpeedBoost write FSpeedBoost;
    property FireRateBoost: Int64 read FFireRateBoost write FFireRateBoost;

    procedure TowerTargetAt(const ATarget: TVec2);

    procedure Move(const AForwardForce: Single);
    procedure RotateBy(AAngle: Single); virtual;
    procedure RotateAt(const ATarget: TVec2);

    procedure Fire();

    procedure AfterConstruction; override;

    function  HasSpineTris: Boolean; override;
    procedure Draw(const ASpineVertices: ISpineExVertices); override;
    procedure DrawLightSources(const ALights: ILightInfoArr); override;
  end;

  TPlayerWeapon = (pwMachineGun, pwRocket, pwMiniRocket, pwTesla, pwGrenade);

  { TPlayer }

  TPlayer = class(TTowerTank)
  private
    FAmmo_Tesla: Integer;
    FAmmo_Grenade: Integer;
    FAmmo_MiniRocket: Integer;
    FAmmo_Rocket: Integer;
  protected
    FWheelTargetBone: PspBone;

    FTeslaBones : TspBonesArr;
    FOtherBones : TspBonesArr;

    FActiveWeapon: TPlayerWeapon;

    function GetDefaultSkin: string; override;
    function GetMaxRotateSpeed: Single; override;
    function GetMaxMoveSpeed: TVec2; override;
    function GetReloadDuration: Integer; override;

    procedure DoSetResource(const ARes: TGameResource); override;
  protected
    procedure DoFire(); override;
  public
    procedure DrawUI(const ASpineVertices: ISpineExVertices); override;
  public
    procedure SetWeapon(const AWeapon: TPlayerWeapon);

    procedure RotateBy(AAngle: Single); override;

    property Ammo_MiniRocket: Integer read FAmmo_MiniRocket write FAmmo_MiniRocket;
    property Ammo_Rocket: Integer read FAmmo_Rocket write FAmmo_Rocket;
    property Ammo_Grenade: Integer read FAmmo_Grenade write FAmmo_Grenade;
    property Ammo_Tesla: Integer read FAmmo_Tesla write FAmmo_Tesla;

    procedure AfterConstruction; override;
  end;

const
  cPlayerSkinName : array [TPlayerWeapon] of string = ('machinegun', 'rocket', 'minirocket', 'tesla', 'grenade');

implementation

uses
  Math, gRegs, gEffects, gPickableItems;

{ TTowerTank }

procedure TTowerTank.Move(const AForwardForce: Single);
var force: TVec2;
    ms: TVec2;
begin
  ms := GetMaxMoveSpeed;
  if SpeedBoost > World.Time then ms := ms * SPEED_BOOST_RATE;
  
  force := Dir * AForwardForce;
  if AForwardForce > 0 then
    force := force * ms.x
  else
    force := force * ms.y;
  MainBody.ApplyForceToCenter(TVector2.From(force.x, force.y));
end;

procedure TTowerTank.RotateBy(AAngle: Single);
var maxSpeed: single;
begin
  maxSpeed := GetMaxRotateSpeed;
  if SpeedBoost > World.Time then maxSpeed := maxSpeed * SPEED_BOOST_RATE;
  AAngle := Clamp(AAngle, -maxSpeed, maxSpeed);
  Angle := Angle + AAngle;
end;

procedure TTowerTank.ShootWithGrenade;
var ownerInfo: TOwnerInfo;
    bullet: TBullet;
    firePos: TVec2;
    fireDir: TVec2;
begin
  ownerInfo.Init(Self, bokPlayer);

  bullet := TGrenade.Create(World);
  bullet.Owner := ownerInfo;
  bullet.Layer := Layer;
  bullet.ZIndex := ZIndex;

  fireDir := Normalize(FTarget-Pos);
  firePos := Vec(FFireBones[FFireIdx]^.WorldX, FFireBones[FFireIdx]^.WorldY) * GetTransform;
  bullet.SetDefaultState(firePos, FTarget, fireDir, fireDir*(50+Random*10));

  Inc(FFireIdx);
  if FFireIdx >= Length(FFireBones) then FFireIdx := 0;
end;

procedure TTowerTank.ShootWithMachineGun;
var ownerInfo: TOwnerInfo;
    bullet: TBullet;
    firePos: TVec2;
    fireDir: TVec2;
begin
  ownerInfo.Init(Self, bokPlayer);

  bullet := TSimpleGun.Create(World);
  bullet.Owner := ownerInfo;
  bullet.Layer := Layer;
  bullet.ZIndex := ZIndex;

  fireDir := Normalize(FTarget-Pos);
  firePos := Vec(FFireBones[FFireIdx]^.WorldX, FFireBones[FFireIdx]^.WorldY) * GetTransform;
  bullet.SetDefaultState(firePos, FTarget, fireDir, fireDir*80);

  Inc(FFireIdx);
  if FFireIdx >= Length(FFireBones) then FFireIdx := 0;
end;

procedure TTowerTank.ShootWithRocket(const APowerRocket: Boolean);
var ownerInfo: TOwnerInfo;
    bullet: TRocket;
    firePos: TVec2;
    fireDir: TVec2;
begin
  ownerInfo.Init(Self, bokPlayer);

  bullet := TRocket.Create(World);
  bullet.Owner := ownerInfo;
  bullet.Layer := Layer;
  bullet.ZIndex := ZIndex;

  fireDir := Normalize(FTarget-Pos);
  firePos := Vec(FFireBones[FFireIdx]^.WorldX, FFireBones[FFireIdx]^.WorldY) * GetTransform;
  bullet.SetDefaultState(firePos, FTarget, fireDir, fireDir*4 + Velocity);

  Inc(FFireIdx);
  if FFireIdx >= Length(FFireBones) then FFireIdx := 0;
end;

procedure TTowerTank.ShootWithTesla;
var ownerInfo: TOwnerInfo;
    ray: TTeslaRay;
    firePos: TVec2;
begin
  ownerInfo.Init(Self, bokPlayer);

  ray := TTeslaRay.Create(World);
  ray.Owner := ownerInfo;
  ray.Layer := Layer;
  ray.ZIndex := ZIndex;

  firePos := Vec(FFireBones[FFireIdx]^.WorldX, FFireBones[FFireIdx]^.WorldY) * GetTransform;

  ray.SetDefaultState(firePos, FTarget);
  Inc(FFireIdx);
  if FFireIdx >= Length(FFireBones) then FFireIdx := 0;
end;

function TTowerTank.GetDefaultSkin: string;
begin
  Result := 'red';
end;

procedure TTowerTank.DoDealDamage(const APower: Single; const ADirection: TVec2; const AForceK: Single; const AOwner: TOwnerInfo);
var fire: TExplosiveFire;
begin
  inherited;
  if FHP <= 0 then
  begin
    fire := TExplosiveFire.Create(World);
    fire.Layer := glFore1;
    fire.ZIndex := 0;
    fire.Pos := Pos;
    fire.AttachedObject := Self;
  end;
end;

procedure TTowerTank.DoSetResource(const ARes: TGameResource);
var
  i: Integer;
  pBone: PPspBone;
  boneName: string;
begin
  inherited DoSetResource(ARes);
  if Length(ARes.spine) = 0 then Exit;
  FSpine := @ARes.spine[0];
  FSpine^.SpineSkel.SetSkinByName(GetDefaultSkin());

  pBone := FSpine^.SpineSkel.Handle^.bones;
  for i := 0 to FSpine^.SpineSkel.Handle^.bonesCount - 1 do
  begin
    boneName := LowerCase(string(pBone^^.data^.name));
    if boneName = 'target' then
        FTargetBone := pBone^
    else
    if system.Pos('smoke_out', boneName) > 0 then
    begin
      SetLength(FOutBones, Length(FOutBones) + 1);
      FOutBones[High(FOutBones)] := pBone^;
    end
    else
    if system.Pos('bullet', boneName) > 0 then
    begin
      SetLength(FFireBones, Length(FFireBones) + 1);
      FFireBones[High(FFireBones)] := pBone^;
    end;
    Inc(pBone);
  end;
end;

procedure TTowerTank.TowerTargetAt(const ATarget: TVec2);
begin
  FTarget := ATarget;
end;

procedure TTowerTank.RotateAt(const ATarget: TVec2);
var newdir: TVec2;
begin
  newdir := ATarget - Pos;
  RotateBy(ShortestRotation(Angle, arctan2(newdir.y, newdir.x)));
end;

procedure TTowerTank.AfterConstruction;
begin
  inherited AfterConstruction;
  SubscribeForUpdateStep;
end;

function TTowerTank.HasSpineTris: Boolean;
begin
  if (FSpine <> nil) and (FSpine^.SpineSkel <> nil) and (FSpine^.SpineAnim <> nil) then
    Result := True
  else
    Result := inherited HasSpineTris();
end;

procedure TTowerTank.Draw(const ASpineVertices: ISpineExVertices);
begin
  if (FSpine <> nil) and (FSpine^.SpineSkel <> nil) and (FSpine^.SpineAnim <> nil) then
  begin
    FSpine^.SpineAnim.Apply(FSpine^.SpineSkel);
    //FSpine^.SpineSkel.Pos := Pos;
    if FTargetBone <> nil then
    begin
       FTargetBone^.pos := FTarget * GetTransformInv();
    end;
    FSpine^.SpineSkel.WriteVertices(GetSpineVertexCallBack(ASpineVertices, GetTransform()), 0);

    b2DebugDraw(ASpineVertices);
  end
  else
    inherited Draw(ASpineVertices);
end;

procedure TTowerTank.DrawLightSources(const ALights: ILightInfoArr);
var l: TLightInfo;
begin
  inherited;
  l.LightKind := 0;
  l.LightDist := 7;
  l.LightPos := Pos;
  l.LightColor := Vec(1,1,1,1);
  ALights.Add(l);
end;

procedure TTowerTank.Fire;
var k: Single;
begin
  if FireRateBoost > World.Time then k := 1/FIRE_BOOST_RATE else k := 1;
  if FNextFireReadyTime > World.Time then Exit;
  FNextFireReadyTime := World.Time + Round(GetReloadDuration*k);

  if FTargetBone <> nil then
  begin
     FTargetBone^.pos := FTarget * GetTransformInv();
     FSpine.SpineSkel.UpdateWorldTransform;
  end;

  DoFire();
end;

{ TPlayer }

function TPlayer.GetMaxMoveSpeed: TVec2;
begin
  Result := Vec(115, 115);
end;

procedure TPlayer.AfterConstruction;
begin
  inherited AfterConstruction;
  FMaxHP := 100;
  FHP := FMaxHP;
  FIsPlayer := True;
end;

procedure TPlayer.DoFire;
begin
  case FActiveWeapon of
    pwMachineGun: ShootWithMachineGun();
    pwRocket: ShootWithRocket(True);
    pwMiniRocket: ShootWithRocket(False);
    pwTesla: ShootWithTesla();
    pwGrenade: ShootWithGrenade();
  end;
  if FActiveWeapon <> pwTesla then
    if (FSpine <> nil) and (FSpine.SpineAnim <> nil) then FSpine.SpineAnim.SetAnimationByName(1, 'fire'+IntToStr(FFireIdx), false);
end;

procedure TPlayer.DoSetResource(const ARes: TGameResource);
var
  i: Integer;
  pBone: PPspBone;
  boneName: string;
begin
  inherited DoSetResource(ARes);
  if Length(ARes.spine) = 0 then Exit;
  FSpine := @ARes.spine[0];
  FSpine^.SpineSkel.SetSkinByName(GetDefaultSkin());

  pBone := FSpine^.SpineSkel.Handle^.bones;
  for i := 0 to FSpine^.SpineSkel.Handle^.bonesCount - 1 do
  begin
    boneName := LowerCase(string(pBone^^.data^.name));
    if boneName = 'drive_target' then
        FWheelTargetBone := pBone^
    else
    if system.Pos('bullet_tesla', boneName) > 0 then
    begin
      SetLength(FTeslaBones, Length(FTeslaBones) + 1);
      FTeslaBones[High(FTeslaBones)] := pBone^;
    end
    else
    if system.Pos('bullet', boneName) > 0 then
    begin
      SetLength(FOtherBones, Length(FOtherBones) + 1);
      FOtherBones[High(FOtherBones)] := pBone^;
    end;
    Inc(pBone);
  end;

  FFireBones := FOtherBones;
end;

procedure TPlayer.DrawUI(const ASpineVertices: ISpineExVertices);
var test: ISpriteIndexArr;
begin
  inherited;
  test := World.ObtainGlyphs('Test', 'Arial', 24);
  Draw_UI_Text(ASpineVertices, test, Vec(50, 50), Vec(1,0,0,1));
end;

function TPlayer.GetDefaultSkin: string;
begin
  Result := cPlayerSkinName[pwMachineGun];
end;

function TPlayer.GetMaxRotateSpeed: Single;
var v: Single;
begin
  v := Len(Velocity);
  v := clamp(v / 10, 0, 1);
  Result := 0.02 * v;
end;

function TPlayer.GetReloadDuration: Integer;
begin
  Result := 1000;
  case FActiveWeapon of
    pwMachineGun: Result := 150;
    pwRocket    : Result := 1300;
    pwMiniRocket: Result := 1300;
    pwTesla     : Result := 100;
    pwGrenade   : Result := 800;
  end;
end;

procedure TPlayer.RotateBy(AAngle: Single);
begin
  if FWheelTargetBone <> nil then
     FWheelTargetBone^.pos := Vec(4, tan(AAngle));
  AAngle := AAngle * sign(dot(Velocity, Dir));
  inherited;
end;

procedure TPlayer.SetWeapon(const AWeapon: TPlayerWeapon);
begin
  FActiveWeapon := AWeapon;
  if (FSpine <> nil) and (FSpine.SpineSkel <> nil) then
    FSpine.SpineSkel.SetSkinByName(cPlayerSkinName[FActiveWeapon]);
  if FActiveWeapon = pwTesla then
    FFireBones := FTeslaBones
  else
    FFireBones := FOtherBones;
  FFireIdx := 0;
end;

{ TUnit }

procedure TUnit.DealDamage(const APower: Single; const ADirection: TVec2; const AForceK: Single; const AOwner: TOwnerInfo);
var f: TVec2;
begin
  f := ADirection * AForceK;
  MainBody.ApplyForceToCenter(TVector2.From(f.x, f.y));
  if FHP > 0 then
  begin
    FHP := FHP - APower;
    DoDealDamage(APower, ADirection, AForceK, AOwner);
  end;
end;

procedure TUnit.DoDealDamage(const APower: Single; const ADirection: TVec2; const AForceK: Single; const AOwner: TOwnerInfo);
begin

end;

function TUnit.IsDead: Boolean;
begin
  Result := FHP <= 0;
end;

procedure TUnit.SetHP(const Value: Single);
begin
  FHP := Value;
end;

{ TBox }

procedure TBox.AfterConstruction;
begin
  inherited;
  MaxHP := 75;
  HP := MaxHP;
end;

function TBox.CreateFixutreDefForShape(const AShape: Tb2Shape): Tb2FixtureDef;
begin
  Result := inherited CreateFixutreDefForShape(AShape);
  Result.density := 5;
end;

destructor TBox.Destroy;
var item: TPickItem;
begin
  if not World.InDestroy then
  begin
    case Random(3) of
      0: item := TPickItem_HP.Create(World);
      1: item := TPickItem_Speed.Create(World);
      2: item := TPickItem_FireRate.Create(World);
    else
      item := nil;
    end;
    if item <> nil then
    begin
      item.Pos := Pos;
    end;
  end;
  inherited;
end;

procedure TBox.DoDealDamage(const APower: Single; const ADirection: TVec2; const AForceK: Single; const AOwner: TOwnerInfo);
begin
  inherited;
  if IsDead then
  begin
    World.SafeDestroy(Self);
  end;
end;

function TBox.GetMaxRotateSpeed: Single;
begin
  Result := Pi*2;
end;

{ TBox2 }

procedure TBox2.AfterConstruction;
begin
  inherited;
  MaxHP := 25;
  HP := MaxHP;
end;

initialization
  RegClass(TPlayer);
  RegClass(TBox);

end.
