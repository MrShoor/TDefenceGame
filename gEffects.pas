unit gEffects;

interface

uses
  gWorld, gTypes,
  mutils, avRes;

type
  TExplosion = class(TGameSprite)
  private
    FDeadTime: Int64;
  protected
    procedure UpdateStep; override;
  public
    procedure AfterConstruction; override;
  end;

implementation

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

  FDeadTime := World.Time + 350;

  SubscribeForUpdateStep;
end;

procedure TExplosion.UpdateStep;
begin
  inherited;
  if FDeadTime < World.Time then
    World.SafeDestroy(Self);
end;

end.
