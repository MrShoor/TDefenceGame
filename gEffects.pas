unit gEffects;

interface

uses
  gWorld, gTypes,
  mutils, avRes;

type
  TExplosion = class(TGameSprite)
  private const
    cLIFE_TIME = 350;
  private
    FDeadTime: Int64;
  protected
    procedure UpdateStep; override;
  public
    procedure DrawLightSources(const ALights: ILightInfoArr); override;
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

  FDeadTime := World.Time + cLIFE_TIME;

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
  ls.LightDist := 10;
  ls.LightColor := Vec(0.988235294117647, 0.792156862745098, 0.0117647058823529, 1.0)*k;
  ALights.Add(ls);
end;

procedure TExplosion.UpdateStep;
begin
  inherited;
  if FDeadTime < World.Time then
    World.SafeDestroy(Self);
end;

end.
