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
  mutils;

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
    function GetMaxMoveSpeed: TVec2; virtual; abstract;
  public
    procedure Move(const AFrowardForce: Single);
    procedure RotateBy(AAngle: Single);
    procedure RotateAt(const ATarget: TVec2);
  end;

  TPlayer = class(TTowerTank)
  private

  public
  end;

implementation

uses
  Math, gRegs;

{ TTowerTank }

procedure TTowerTank.Move(const AFrowardForce: Single);
var force: TVec2;
begin
  force := Dir * AFrowardForce;
  MainBody.ApplyForceToCenter(TVector2.From(force.x, force.y));
end;

procedure TTowerTank.RotateBy(AAngle: Single);
var maxSpeed: single;
begin
  maxSpeed := GetMaxRotateSpeed;
  AAngle := Clamp(AAngle, -maxSpeed, maxSpeed);
  Angle := Angle + AAngle;
end;

procedure TTowerTank.RotateAt(const ATarget: TVec2);
var newdir: TVec2;
begin
  newdir := ATarget - Pos;
  RotateBy(ShortestRotation(Angle, arctan2(newdir.y, newdir.x)));
end;

initialization
  RegClass(TPlayer);

end.
