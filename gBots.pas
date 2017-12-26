unit gBots;

interface

uses
  Classes, SysUtils,
  gWorld, gTypes, gBullets, gUnits,
  UPhysics2D, UPhysics2DTypes,
  B2Utils,
  mutils,
  SpineH,
  intfUtils;

const
  DEF_DROP_CHANCE = 2;

type
  TBotTank = class(TTowerTank)
  private
    FPlayer: IWeakRef;
    function GetPlayer: TUnit;
    procedure SetPlayer(const Value: TUnit);
  protected
    function Filter_ExcludeUnits(const AObj: TGameBody): Boolean;
    function Filter_ForMovement(const AObj: TGameBody): Boolean;
    function Filter_ForShooting(const AObj: TGameBody): Boolean;
  protected
    FMoveTarget: TVec2;

    function PredictTargetForShooting(const AUnit: TUnit): TVec2; virtual; abstract;
    function AllowShootNow(AUnit: TUnit): Boolean; virtual;

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
    FPowerRocket: Boolean;
    function PredictTargetForShooting(const AUnit: TUnit): TVec2; override;

    function GetMaxMoveSpeed: TVec2; override;
    function GetReloadDuration: Integer; override;
    procedure DoFire(); override;

    function GetDropClass: TGameObjectClass; virtual;
  public
    procedure AfterConstruction; override;
    destructor Destroy; override;
  end;

  TPowerBot = class(TStupidBot)
  protected
    function GetMaxMoveSpeed: TVec2; override;
    function GetDropClass: TGameObjectClass; override;
  public
    procedure AfterConstruction; override;
  end;

  TTeslaBot = class(TBotTank)
  private
  protected
    function PredictTargetForShooting(const AUnit: TUnit): TVec2; override;
    function AllowShootNow(AUnit: TUnit): Boolean; override;

    function GetMaxMoveSpeed: TVec2; override;
    function GetReloadDuration: Integer; override;
    procedure DoFire(); override;
  public
    procedure AfterConstruction; override;
    destructor Destroy; override;
  end;

  TMiniBot = class(TBotTank)
  private
  protected
    function PredictTargetForShooting(const AUnit: TUnit): TVec2; override;
    function AllowShootNow(AUnit: TUnit): Boolean; override;

    function GetMaxMoveSpeed: TVec2; override;
    function GetReloadDuration: Integer; override;
    procedure DoFire(); override;
  public
    procedure AfterConstruction; override;
    destructor Destroy; override;
  end;

implementation

uses
  Math, gRegs, gPickableItems;

{ TBotTank }

procedure TBotTank.AfterConstruction;
begin
  inherited;
  Player := TUnit(World.FindPlayerObject);
end;

function TBotTank.AllowShootNow(AUnit: TUnit): Boolean;
begin
  Result := True;
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

function TBotTank.Filter_ForMovement(const AObj: TGameBody): Boolean;
begin
  Result := True;//not (AObj is TTowerTank);
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
    if World.RayCast(Pos, Pos + d * 2, dummy, {$IfDef FPC}@{$EndIf}Filter_ForMovement)<>nil then Exit(False);
    if World.RayCast(Pos, Pos + Rotate(d,  0.33) * 2, dummy, {$IfDef FPC}@{$EndIf}Filter_ForMovement)<>nil then Exit(False);
    if World.RayCast(Pos, Pos + Rotate(d, -0.33) * 2, dummy, {$IfDef FPC}@{$EndIf}Filter_ForMovement)<>nil then Exit(False);
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
      if World.RayCast(Pos, Result, dummy, {$IfDef FPC}@{$EndIf}Filter_ForMovement) = nil then Exit;
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
    hpk: Single;
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
    aimTarget := PredictTargetForShooting(newPlayer);
    TowerTargetAt(aimTarget);
    aimHit := World.RayCast(Pos, aimTarget, dummy, {$IfDef FPC}@{$EndIf}Filter_ForShooting);
    if ((aimHit = nil) or (aimHit = newPlayer)) and AllowShootNow(newPlayer) then
      Fire();
  end
  else
    TowerTargetAt(Lerp(FTarget, Pos + Dir*7, 0.1));
end;

{ TStupidBot }

procedure TStupidBot.AfterConstruction;
begin
  inherited;
  MaxHP := 30;
  HP := MaxHP;
end;

destructor TStupidBot.Destroy;
var item: TPickItem;
begin
  if not World.InDestroy then
  begin
    case Random(DEF_DROP_CHANCE) of
      0: item := TPickItem(GetDropClass.Create(World));
    else
      item := nil;
    end;
    if item <> nil then item.Pos := Pos;
  end;
  inherited;
end;

procedure TStupidBot.DoFire;
begin
  inherited;
  ShootWithRocket(FPowerRocket);
end;

function TStupidBot.GetDropClass: TGameObjectClass;
begin
  Result := TPickItem_Canon_RocketMini;
end;

function TStupidBot.GetMaxMoveSpeed: TVec2;
begin
  Result := Vec(75,75);
end;

function TStupidBot.GetReloadDuration: Integer;
begin
  Result := 1300;
end;

function TStupidBot.PredictTargetForShooting(const AUnit: TUnit): TVec2;
var k: Single;
begin
  k := Len(AUnit.Pos - Pos)/50;
  Result := AUnit.Pos + (AUnit.Velocity {- Velocity}) * k;
end;

{ TTeslaBot }

procedure TTeslaBot.AfterConstruction;
begin
  inherited;
  MaxHP := 20;
  HP := MaxHP;
end;

function TTeslaBot.AllowShootNow(AUnit: TUnit): Boolean;
begin
  Result := LenSqr(AUnit.Pos - Pos) < Sqr(TTeslaRay.TESLA_RANGE + TTeslaRay.TESLA_SNAP_RANGE);
end;

destructor TTeslaBot.Destroy;
var item: TPickItem;
begin
  if not World.InDestroy then
  begin
    case Random(DEF_DROP_CHANCE) of
      0: item := TPickItem_Canon_Tesla.Create(World);
    else
      item := nil;
    end;
    if item <> nil then item.Pos := Pos;
  end;
  inherited;
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
  Result := 100;
end;

function TTeslaBot.PredictTargetForShooting(const AUnit: TUnit): TVec2;
begin
  Result := AUnit.Pos;
end;

{ TMiniBot }

procedure TMiniBot.AfterConstruction;
begin
  inherited;
  MaxHP := 20;
  HP := MaxHP;
end;

function TMiniBot.AllowShootNow(AUnit: TUnit): Boolean;
begin
  Result := LenSqr(AUnit.Pos - Pos) < Sqr(15);
end;

destructor TMiniBot.Destroy;
var item: TPickItem;
begin
  if not World.InDestroy then
  begin
    case Random(DEF_DROP_CHANCE) of
      0: item := TPickItem_Canon_Grenade.Create(World);
    else
      item := nil;
    end;
    if item <> nil then item.Pos := Pos;
  end;
  inherited;
end;

procedure TMiniBot.DoFire;
begin
  inherited;
  ShootWithGrenade();
end;

function TMiniBot.GetMaxMoveSpeed: TVec2;
begin
  Result := Vec(100,100);
end;

function TMiniBot.GetReloadDuration: Integer;
begin
  Result := 800;
end;

function TMiniBot.PredictTargetForShooting(const AUnit: TUnit): TVec2;
var k: Single;
begin
  k := Len(AUnit.Pos - Pos)/50;
  Result := AUnit.Pos + (AUnit.Velocity - Velocity) * k;
end;

{ TPowerBot }

procedure TPowerBot.AfterConstruction;
begin
  inherited;
  FPowerRocket := True;
  MaxHP := 50;
  HP := MaxHP;
end;

function TPowerBot.GetDropClass: TGameObjectClass;
begin
  Result := TPickItem_Canon_Rocket;
end;

function TPowerBot.GetMaxMoveSpeed: TVec2;
begin
  Result := Vec(50,50);
end;

initialization
RegClass(TPowerBot);
RegClass(TStupidBot);
RegClass(TTeslaBot);
RegClass(TMiniBot);

end.
