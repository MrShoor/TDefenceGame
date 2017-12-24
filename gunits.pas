unit gUnits;

{$IfDef FPC}
  {$mode objfpc}{$H+}
  {$ModeSwitch advancedrecords}
{$EndIf}

interface

uses
  Classes, SysUtils,
  gWorld, gTypes,
  UPhysics2DTypes,
  mutils, SpineH;

type

  { TUnit }

  TUnit = class(TGameDynamicBody)
  protected
    function GetMaxRotateSpeed: Single; virtual; abstract;
  public

  end;

  { TTowerTank }

  TTowerTank = class(TUnit)
  protected
    FTarget: TVec2;

    FSpine: PGameSpineRes;

    FTargetBone: PspBone;
    FOutBones  : array of PspBone;
    FFireBones : array of PspBone;

    function GetMaxMoveSpeed: TVec2; virtual; abstract;

    procedure DoSetResource(const ARes: TGameResource); override;
    procedure UpdateStep; override;
  public
    procedure TowerTargetAt(const ATarget: TVec2);

    procedure Move(const AForwardForce: Single);
    procedure RotateBy(AAngle: Single);
    procedure RotateAt(const ATarget: TVec2);

    procedure AfterConstruction; override;

    function  HasSpineTris: Boolean; override;
    procedure Draw(const ASpineVertices: ISpineExVertices); override;
  end;

  { TPlayer }

  TPlayer = class(TTowerTank)
  private
  protected
    function GetMaxRotateSpeed: Single; override;
    function GetMaxMoveSpeed: TVec2; override;
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

procedure TTowerTank.DoSetResource(const ARes: TGameResource);
var
  i: Integer;
  pBone: PPspBone;
  boneName: string;
begin
  inherited DoSetResource(ARes);
  if Length(ARes.spine) = 0 then Exit;
  FSpine := @ARes.spine[0];

  pBone := FSpine^.SpineSkel.Handle^.bones;
  for i := 0 to FSpine^.SpineSkel.Handle^.bonesCount - 1 do
  begin
    boneName := LowerCase(pBone^^.data^.name);
    if boneName = 'target' then
        FTargetBone := pBone^
    else
    if system.Pos('smoke_out', boneName) > 0 then
    begin
      SetLength(FOutBones, Length(FOutBones) + 1);
      FOutBones[High(FOutBones)] := pBone^;
    end
    else
    if system.Pos('fire_out', boneName) > 0 then
    begin
      SetLength(FFireBones, Length(FFireBones) + 1);
      FFireBones[High(FFireBones)] := pBone^;
    end;
    Inc(pBone);
  end;
//  FSpine^.SpineAnim.SetAnimationByName(0, 'fire', true);
end;

procedure TTowerTank.UpdateStep;
begin
  inherited UpdateStep;
  if (FSpine <> nil) and (FSpine^.SpineAnim <> nil) then
    FSpine^.SpineAnim.Update(PHYS_STEP/1000);
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
  end
  else
    inherited Draw(ASpineVertices);
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

function TPlayer.GetMaxRotateSpeed: Single;
begin
  Result := 0.02;
end;

initialization
  RegClass(TPlayer);

end.
