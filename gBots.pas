unit gBots;

interface

uses
  Windows,
  Classes, SysUtils,
  gWorld, gTypes, gBullets, gUnits,
  UPhysics2D, UPhysics2DTypes,
  B2Utils,
  mutils,
  SpineH,
  intfUtils;

type
  TBotTank = class(TTowerTank)
  private
    FPlayer: IWeakRef;
    function GetPlayer: TUnit;
    procedure SetPlayer(const Value: TUnit);
  protected
    function Filter_ExcludeUnits(const AObj: TGameBody): Boolean;
    function Filter_ForShooting(const AObj: TGameBody): Boolean;
  protected
    FMoveTarget: TVec2;

    property  Player: TUnit read GetPlayer write SetPlayer;
    procedure UpdateStep; override;
    function  GetDefaultSkin: string; override;
    function  GetMaxRotateSpeed: Single; override;
  public
    procedure Draw(const ASpineVertices: ISpineExVertices); override;
    procedure AfterConstruction; override;
  end;

  TStupidBot = class(TBotTank)
  private
  protected
    function GetMaxMoveSpeed: TVec2; override;
    function GetReloadDuration: Integer; override;
    procedure DoFire(); override;
  public
    procedure AfterConstruction; override;
  end;

  TTeslaBot = class(TBotTank)
  private
  protected
    function GetMaxMoveSpeed: TVec2; override;
    function GetReloadDuration: Integer; override;
    procedure DoFire(); override;
  public
    procedure AfterConstruction; override;
  end;

implementation

uses
  Math, gRegs;

{ TBotTank }

procedure TBotTank.AfterConstruction;
begin
  inherited;
  Player := TUnit(World.FindPlayerObject);
end;

procedure TBotTank.Draw(const ASpineVertices: ISpineExVertices);
begin
  inherited;
//  Draw_Rect(ASpineVertices, World.GetCommonTextures.WhitePix, FMoveTarget, Vec(1,0), Vec(1,1), 0.4, Vec(1,1,0,1));
end;

function TBotTank.Filter_ExcludeUnits(const AObj: TGameBody): Boolean;
begin
  Result := not (AObj is TUnit);
end;

function TBotTank.Filter_ForShooting(const AObj: TGameBody): Boolean;
begin
  if AObj = Self then Exit(False);
  if AObj is TBullet then Exit(False);
  Result := True;
end;

function TBotTank.GetDefaultSkin: string;
begin
  Result := 'red';
end;

function TBotTank.GetMaxRotateSpeed: Single;
begin
  Result := 0.02;
end;

function TBotTank.GetPlayer: TUnit;
begin
  Result := nil;
  if FPlayer <> nil then
    Result := TUnit(FPlayer.Obj);
  if Result = nil then FPlayer := nil;
end;

procedure TBotTank.SetPlayer(const Value: TUnit);
begin
  FPlayer := nil;
  if Value = nil then Exit;
  FPlayer := Value.WeakRef;
end;

procedure TBotTank.UpdateStep;

  function CanMoveStraight(): Boolean;
  var d: TVec2;
      dummy: TVec2;
  begin
    d := normalize(FMoveTarget - Pos);
    if World.RayCast(Pos, Pos + d * 2, dummy, {$IfDef FPC}@{$EndIf}Filter_ExcludeUnits)<>nil then Exit(False);
    if World.RayCast(Pos, Pos + Rotate(d,  0.28) * 2, dummy, {$IfDef FPC}@{$EndIf}Filter_ExcludeUnits)<>nil then Exit(False);
    if World.RayCast(Pos, Pos + Rotate(d, -0.28) * 2, dummy, {$IfDef FPC}@{$EndIf}Filter_ExcludeUnits)<>nil then Exit(False);
    Result := True;
  end;

  function RenewTarget(const Around: TVec2; const AtDist: TVec2): TVec2;
  const BOUNDS_X = 30;
        BOUNDS_Y = 18;
  var fi: Single;
      i: Integer;
      dummy: TVec2;
  begin
    for i := 0 to 10 do
    begin
      fi := Random * 2 * Pi;
      Result := Around + VecSinCos(fi) * (Random*(AtDist.y - AtDist.x) + AtDist.x);
      if Result.x < -BOUNDS_X then
        Result.x := (-BOUNDS_X - Result.x) + (-BOUNDS_X);
      if Result.x > BOUNDS_X then
        Result.x := (BOUNDS_X - Result.x) + (BOUNDS_X);
      if Result.y < -BOUNDS_Y then
        Result.y := (-BOUNDS_Y - Result.y) + (-BOUNDS_Y);
      if Result.y > BOUNDS_Y then
        Result.y := (BOUNDS_Y - Result.y) + (BOUNDS_Y);
//      Result.x := Clamp(Result.x, -23, 23);
//      Result.y := Clamp(Result.y, -14, 14);
      if World.RayCast(Pos, Result, dummy, {$IfDef FPC}@{$EndIf}Filter_ExcludeUnits) = nil then Exit;
    end;
  end;

  procedure MoveToTarget();
  var v: Single;
  begin
    RotateAt(FMoveTarget);
    v := Dot(Dir, normalize(FMoveTarget - Pos));
    Move(v);
  end;

var newPlayer: TUnit;
    seeTarget: Boolean;
    canMove : Boolean;
    dummy: TVec2;
    n: TVec2;
    hpk: Single;
    k: Single;
    aimTarget: TVec2;
    aimHit: TGameBody;
begin
  inherited;
  if IsDead then Exit;

  newPlayer := Player;
  if newPlayer = nil then
  begin
    newPlayer := TUnit(World.FindPlayerObject);
    Player := newPlayer;
  end;
  if newPlayer = nil then
    seeTarget := False
  else
    seeTarget := World.RayCast(Pos, newPlayer.Pos, dummy, {$IfDef FPC}@{$EndIf}Filter_ForShooting) = newPlayer;
  if seeTarget and newPlayer.IsDead then
  begin
    seeTarget := False;
    newPlayer := nil;
  end;

  canMove := CanMoveStraight();

  if (Len(FMoveTarget - Pos) < 2) then
  begin
    if seeTarget then
    begin
      hpk := HP / MaxHP;
      FMoveTarget := newPlayer.Pos + SetLen(Pos - newPlayer.Pos, lerp(13, 5, hpk));
    end
    else
    begin
      FMoveTarget := RenewTarget(Pos + Dir * 7, Vec(3, 7));
    end;
  end;
  if not canMove then
  begin
    FMoveTarget := RenewTarget(Pos - Dir * 5, Vec(0, 7));
  end;

  MoveToTarget();

  if seeTarget then
  begin
    k := Len(newPlayer.Pos - Pos)/50;
    aimTarget := newPlayer.Pos + (newPlayer.Velocity - Velocity) * k;
    TowerTargetAt(aimTarget);
    aimHit := World.RayCast(Pos, aimTarget, dummy, {$IfDef FPC}@{$EndIf}Filter_ForShooting);
    if (aimHit = nil) or (aimHit = newPlayer) then
      Fire();
  end
  else
    TowerTargetAt(Lerp(FTarget, Pos + Dir*7, 0.1));
end;

{ TStupidBot }

procedure TStupidBot.AfterConstruction;
begin
  inherited;
  MaxHP := 60;
  HP := MaxHP;
end;

procedure TStupidBot.DoFire;
begin
  inherited;
  ShootWithRocket();
end;

function TStupidBot.GetMaxMoveSpeed: TVec2;
begin
  Result := Vec(75,75);
end;

function TStupidBot.GetReloadDuration: Integer;
begin
  Result := 1000;
end;

{ TTeslaBot }

procedure TTeslaBot.AfterConstruction;
begin
  inherited;
  MaxHP := 40;
  HP := MaxHP;
end;

procedure TTeslaBot.DoFire;
begin
  inherited;
  ShootWithTesla();
end;

function TTeslaBot.GetMaxMoveSpeed: TVec2;
begin
  Result := Vec(100,100);
end;

function TTeslaBot.GetReloadDuration: Integer;
begin
  Result := 0;
end;

initialization
RegClass(TStupidBot);

end.
