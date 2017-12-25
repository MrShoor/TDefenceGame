unit gUnits;

{$IfDef FPC}
  {$mode objfpc}{$H+}
  {$ModeSwitch advancedrecords}
{$EndIf}

interface

uses
  Windows,
  Classes, SysUtils,
  gWorld, gTypes, gBullets,
  UPhysics2D, UPhysics2DTypes,
  B2Utils,
  mutils,
  SpineH,
  intfUtils;

type

  { TUnit }

  TUnit = class(TGameDynamicBody)
  protected
    function GetMaxRotateSpeed: Single; virtual; abstract;
  public
    procedure DealDamage(const APower: Single; const ADirection: TVec2; const AOwner: TOwnerInfo); virtual;
  end;

  { TTowerTank }

  TTowerTank = class(TUnit)
  protected
    FTarget: TVec2;

    FSpine: PGameSpineRes;

    FTargetBone: PspBone;
    FOutBones  : array of PspBone;
    FFireBones : array of PspBone;
    FFireIdx : Integer;

    FNextFireReadyTime: Int64;
  protected
    function  GetDefaultSkin: string; virtual;
    function  GetMaxMoveSpeed: TVec2; virtual; abstract;
    function  GetReloadDuration: Integer; virtual; abstract;
    procedure DoFire(); virtual; abstract;
  protected
    procedure DoSetResource(const ARes: TGameResource); override;
  public
    procedure TowerTargetAt(const ATarget: TVec2);

    procedure Move(const AForwardForce: Single);
    procedure RotateBy(AAngle: Single);
    procedure RotateAt(const ATarget: TVec2);

    procedure Fire();

    procedure AfterConstruction; override;

    function  HasSpineTris: Boolean; override;
    procedure Draw(const ASpineVertices: ISpineExVertices); override;
    procedure DrawLightSources(const ALights: ILightInfoArr); override;
  end;

  { TPlayer }

  TPlayer = class(TTowerTank)
  private
  protected
    function GetDefaultSkin: string; override;
    function GetMaxRotateSpeed: Single; override;
    function GetMaxMoveSpeed: TVec2; override;
    function GetReloadDuration: Integer; override;
  protected
    procedure DoFire(); override;
  public

    procedure AfterConstruction; override;
  end;

implementation

uses
  Math, gRegs;

{ TTowerTank }

procedure TTowerTank.Move(const AForwardForce: Single);
var force: TVec2;
begin
  force := Dir * AForwardForce;
  if AForwardForce > 0 then
    force := force * GetMaxMoveSpeed.x
  else
    force := force * GetMaxMoveSpeed.y;
  MainBody.ApplyForceToCenter(TVector2.From(force.x, force.y));
end;

procedure TTowerTank.RotateBy(AAngle: Single);
var maxSpeed: single;
begin
  maxSpeed := GetMaxRotateSpeed;
  AAngle := Clamp(AAngle, -maxSpeed, maxSpeed);
  Angle := Angle + AAngle;
end;

function TTowerTank.GetDefaultSkin: string;
begin
  Result := 'red';
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
  l.LightDist := 10;
  l.LightPos := Pos;
  l.LightColor := Vec(1,1,1,1);
  ALights.Add(l);
end;

procedure TTowerTank.Fire;
begin
  if FNextFireReadyTime > World.Time then Exit;
  FNextFireReadyTime := World.Time + GetReloadDuration;

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
  Result := Vec(100,100);
end;

procedure TPlayer.AfterConstruction;
begin
  inherited AfterConstruction;
end;

procedure TPlayer.DoFire;
var ownerInfo: TOwnerInfo;
    rocket: TRocket;
    firePos: TVec2;
    fireDir: TVec2;
begin
  ownerInfo.Init(Self, bokPlayer);

  rocket := TRocket.Create(World);
  rocket.Owner := ownerInfo;
  rocket.Layer := Layer;
  rocket.ZIndex := ZIndex;

  fireDir := Normalize(FTarget-Pos);
  firePos := Vec(FFireBones[FFireIdx]^.WorldX, FFireBones[FFireIdx]^.WorldY) * GetTransform;
  rocket.SetDefaultState(firePos, fireDir, fireDir + Velocity);

  if (FSpine <> nil) and (FSpine.SpineAnim <> nil) then FSpine.SpineAnim.SetAnimationByName(1, 'fire'+IntToStr(FFireIdx), false);

  Inc(FFireIdx);
  if FFireIdx >= Length(FFireBones) then FFireIdx := 0;
end;

function TPlayer.GetDefaultSkin: string;
begin
  Result := 'blue';
end;

function TPlayer.GetMaxRotateSpeed: Single;
begin
  Result := 0.02;
end;

function TPlayer.GetReloadDuration: Integer;
begin
  Result := 2000;
end;

{ TUnit }

procedure TUnit.DealDamage(const APower: Single; const ADirection: TVec2; const AOwner: TOwnerInfo);
begin

end;

initialization
  RegClass(TPlayer);

end.
