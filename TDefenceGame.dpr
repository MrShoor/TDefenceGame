program TDefenceGame;

uses
  Vcl.Forms,
  untmain in 'untmain.pas' {frmMain},
  B2Utils in 'B2Utils.pas',
  bass in 'bass.pas',
  blight in 'blight.pas',
  glevelloader in 'glevelloader.pas',
  gregs in 'gregs.pas',
  gworld in 'gworld.pas',
  UPhysics2D in 'Physics2D\UPhysics2D.pas',
  UPhysics2DControllers in 'Physics2D\UPhysics2DControllers.pas',
  UPhysics2DHelper in 'Physics2D\UPhysics2DHelper.pas',
  UPhysics2DPolygonTool in 'Physics2D\UPhysics2DPolygonTool.pas',
  UPhysics2DTypes in 'Physics2D\UPhysics2DTypes.pas',
  gtypes in 'gtypes.pas',
  gunits in 'gunits.pas',
  gBullets in 'gBullets.pas',
  gEffects in 'gEffects.pas',
  gLightRenderer in 'gLightRenderer.pas';

{$R *.res}

begin
  Application.Initialize;
  Application.MainFormOnTaskbar := True;
  Application.CreateForm(TfrmMain, frmMain);
  Application.Run;
end.
