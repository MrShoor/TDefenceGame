program TDefenceGame;

uses
  Vcl.Forms,
  untMain in 'untMain.pas' {frmMain},
  B2Utils in 'B2Utils.pas',
  bass in 'bass.pas',
  blight in 'blight.pas',
  glevelloader in 'glevelloader.pas',
  gregs in 'gregs.pas',
  gtypes in 'gtypes.pas',
  gworld in 'gworld.pas',
  UPhysics2D in 'Physics2D\UPhysics2D.pas',
  UPhysics2DControllers in 'Physics2D\UPhysics2DControllers.pas',
  UPhysics2DHelper in 'Physics2D\UPhysics2DHelper.pas',
  UPhysics2DPolygonTool in 'Physics2D\UPhysics2DPolygonTool.pas',
  UPhysics2DTypes in 'Physics2D\UPhysics2DTypes.pas';

{$R *.res}

begin
  Application.Initialize;
  Application.MainFormOnTaskbar := True;
  Application.CreateForm(TfrmMain, frmMain);
  Application.Run;
end.
