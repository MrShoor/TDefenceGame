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

  end;

  TStupidBotSpawner = class(TBotSpawner)

  end;

  TPowerBotSpawner = class(TBotSpawner)

  end;

  TTeslaBotSpawner = class(TBotSpawner)

  end;

  TMiniBotSpawner = class(TBotSpawner)

  end;

implementation

end.
