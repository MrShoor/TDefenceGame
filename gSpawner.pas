unit gSpawner;

interface

uses
  Classes, SysUtils,
  gWorld, gTypes, gBullets, gUnits, gBots,
  UPhysics2D, UPhysics2DTypes,
  B2Utils,
  mutils,
  SpineH,
  intfUtils;

type
  TBotSpawner = class(TSpawnObjectSprite)
  private
    FFinishSpawnTime: Int64;
    FActive: Boolean;
    FSpawned: Boolean;
  protected
    FOriginalResource: TGameResource;
    procedure UpdateStep; override;
    procedure DoSetResource(const ARes: TGameResource); override;

    function GetBotClass: TGameObjectClass; virtual; abstract;
  public
    procedure Spawn(); override;

    function  HasSpineTris: Boolean; override;
    procedure DrawLightSources(const ALights: ILightInfoArr); override;
  end;

  TStupidBotSpawner = class(TBotSpawner)
  protected
    function GetBotClass: TGameObjectClass; override;
  end;

  TPowerBotSpawner = class(TBotSpawner)
  protected
    function GetBotClass: TGameObjectClass; override;
  end;

  TTeslaBotSpawner = class(TBotSpawner)
  protected
    function GetBotClass: TGameObjectClass; override;
  end;

  TMiniBotSpawner = class(TBotSpawner)
  protected
    function GetBotClass: TGameObjectClass; override;
  end;

implementation

uses
  gRegs;

{ TBotSpawner }

procedure TBotSpawner.DoSetResource(const ARes: TGameResource);
begin
  FOriginalResource := ARes;
  FRes.Clear;
  SetLength(FRes.spine, 1);
  FRes.spine[0].LoadFromDir('spawn', World.Atlas);
end;

procedure TBotSpawner.DrawLightSources(const ALights: ILightInfoArr);
begin
  inherited;

end;

function TBotSpawner.HasSpineTris: Boolean;
begin
  Result := False;
  if not FActive then Exit;
  Result := True;
end;

procedure TBotSpawner.Spawn;
begin
  FActive := True;
  FFinishSpawnTime := World.Time + 1000;
  SubscribeForUpdateStep;
end;

procedure TBotSpawner.UpdateStep;
var bot: TGameObject;
begin
  if not FActive then Exit;
  inherited;
  if (FFinishSpawnTime < World.Time) and (not FSpawned) then
  begin
    World.SafeDestroy(Self);
    FSpawned := True;

    bot := GetBotClass.Create(World);
    bot.SetResource(FOriginalResource);
    bot.Layer := Layer;
    bot.ZIndex := ZIndex;
    bot.Pos := Pos;
    bot.Angle := Angle;
    bot.Size := Size;
  end;
end;

{ TStupidBotSpawner }

function TStupidBotSpawner.GetBotClass: TGameObjectClass;
begin
  Result := TStupidBot;
end;

{ TPowerBotSpawner }

function TPowerBotSpawner.GetBotClass: TGameObjectClass;
begin
  Result := TPowerBot;
end;

{ TTeslaBotSpawner }

function TTeslaBotSpawner.GetBotClass: TGameObjectClass;
begin
  Result := TTeslaBot;
end;

{ TMiniBotSpawner }

function TMiniBotSpawner.GetBotClass: TGameObjectClass;
begin
  Result := TMiniBot;
end;

initialization
RegClass(TStupidBotSpawner);
RegClass(TPowerBotSpawner);
RegClass(TTeslaBotSpawner);
RegClass(TMiniBotSpawner);

end.
