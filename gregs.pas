unit gRegs;

interface

uses
  gWorld;

procedure RegClass(const AGameObjClass: TGameObjectClass);
function FindClass(const AName: string): TGameObjectClass;

implementation

uses
  avContnrs;

type
  TGameObjClassArr = {$IfDef FPC}specialize{$EndIf}TArray<TGameObjectClass>;
  IGameObjClassArr = {$IfDef FPC}specialize{$EndIf}IArray<TGameObjectClass>;

var GV_RegClasses : IGameObjClassArr;

procedure RegClass(const AGameObjClass: TGameObjectClass);
begin
  if FindClass(AGameObjClass.ClassName) = nil then
    GV_RegClasses.Add(AGameObjClass);
end;

function FindClass(const AName: string): TGameObjectClass;
var i: Integer;
begin
  Result := nil;
  for i := 0 to GV_RegClasses.Count - 1 do
    if GV_RegClasses[i].ClassName = AName then Exit(GV_RegClasses[i]);
end;

initialization
  GV_RegClasses := TGameObjClassArr.Create;

end.

