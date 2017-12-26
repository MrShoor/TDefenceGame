unit gLevelResults;

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
  TLevelResultState = (lrsInPlay, lrsFail, lrsDone);

  TLevelResults = class(TGameSprite)
  private
    FLevelResult: TLevelResultState;
  public
    property LevelResult: TLevelResultState read FLevelResult write FLevelResult;
    procedure DrawUI(const ASpineVertices: ISpineExVertices); override;
  end;

implementation

uses Math;

{ TLevelResults }

procedure TLevelResults.DrawUI(const ASpineVertices: ISpineExVertices);
var str: ISpriteIndexArr;
    basePos: TVec2;
//    size: TVec2;
begin
  inherited;
  case FLevelResult of
    lrsInPlay: ;
    lrsFail: begin
      basePos := Vec(400, 670);
      str := World.ObtainGlyphs('Позор! Это поражение', 'Arial', 64);
      Draw_UI_Str(ASpineVertices, str, basePos, Vec(1, 1), Vec(1,0,0,1));
      basePos.y := basePos.y - 100;
      str := World.ObtainGlyphs('Нажми R для рестрата', 'Arial', 32);
      Draw_UI_Str(ASpineVertices, str, basePos, Vec(1, 1), Vec(1,0,0,1));

      //Draw_UI_Symbol(ASpineVertices, World.GetCommonTextures.canon_machinegun, basePos+Vec(50, 0), Vec(0.5,0.5), Vec(1,1,1,1));
    end;
    lrsDone: begin
      basePos := Vec(400, 770);
      str := World.ObtainGlyphs('Это ПОБЕДА!!!', 'Arial', 64);
      Draw_UI_Str(ASpineVertices, str, basePos, Vec(1, 1), Vec(0,1,0,1));

      basePos.y := basePos.y - 100;
      str := World.ObtainGlyphs('Я уж думал ты никогда не пройдешь. Вот тебе ёлочка в подарок:', 'Arial', 18);
      Draw_UI_Str(ASpineVertices, str, basePos, Vec(1, 1), Vec(0,1,0,1));

      basePos.y := basePos.y - 180;
      Draw_UI_Symbol(ASpineVertices, World.GetCommonTextures.ctree, basePos+Vec(50, 0), Vec(1,1), Vec(1,1,1,1));

      basePos.y := basePos.y - 180;
      str := World.ObtainGlyphs('Нажми R для рестрата', 'Arial', 32);
      Draw_UI_Str(ASpineVertices, str, basePos, Vec(1, 1), Vec(0,1,0,1));
    end;
  end;
end;

end.
