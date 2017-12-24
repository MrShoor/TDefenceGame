unit gLevelLoader;

{$IfDef FPC}
  {$mode objfpc}{$H+}
  {$ModeSwitch advancedrecords}
{$EndIf}

interface

uses
  Classes, SysUtils, superobject,
  mutils,
  gWorld, gTypes;

const
  cPixelToWorld = 1/80;

type

  { TLevelLoader }

  TLevelLoader = class
  private type
    TImageList = array of string;
  private
    class function  LoadItem (const AObj: ISuperObject; const AWorld: TWorld; const ALayer: TGameLayer; const AImages: TImageList): TGameObject;
    class procedure LoadLayer(const AObj: ISuperObject; const AWorld: TWorld; const ALayer: TGameLayer; const AImages: TImageList);

    class function  LoadImages(const AObj: ISuperObject): TImageList;
    class procedure LoadLayers(const AObj: ISuperObject; const AWorld: TWorld; const AImages: TImageList);
  public
    class procedure LoadLevel(const AFileName: String; const AWorld: TWorld); overload;
  end;

const
  cGameLayerNames: array [TGameLayer] of string = (
    '',
    'Back3',
    'Back2',
    'Back1',
    'GameBack',
    'Game',
    'GameFore',
    'Fore1',
    'Fore2',
    'Fore3'
  );

implementation

uses Math, gRegs, SpineIntf, avTexLoader, avRes, avTypes;

type
  TCustomParam = packed record
    name : string;
    value: string;
  end;
  TCustomParams = array of TCustomParam;

  TCustomImageList = packed record
    width : single;
    images: TIntArr;
  end;
  TCustomImageListArr = array of TCustomImageList;

  { TCustomPolyLine }

  TCustomPolyLine = packed record
    line: TVec2Arr;
    function GetPoint(ASegmentIdx: Integer; ASegmentK: Single): TVec2;
    function MovePointByLine(var ASegmentIdx: Integer; var ASegmentK: Single; AMoveDistance: Single): Boolean;
  end;
  TCustomPolyLineArr = array of TCustomPolyLine;

function FindCustomValue(const ACP: TCustomParams; const AName: string): string;
var
  i: Integer;
begin
  for i := 0 to Length(ACP) - 1 do
    if ACP[i].name = AName then Exit(ACP[i].value);
  Result := '';
end;

function GetD_Def(const AObj: ISuperObject; const path: string; const ADefValue: Double): Double;
var
  obj: ISuperObject;
begin
  obj := AObj.O[path];
  if obj <> nil then
    Result := obj.AsDouble
  else
    Result := ADefValue;
end;

function GetI_Def(const AObj: ISuperObject; const path: string; const ADefValue: Integer): Integer;
var
  obj: ISuperObject;
begin
  obj := AObj.O[path];
  if obj <> nil then
    Result := obj.AsInteger
  else
    Result := ADefValue;
end;

function TryGetI(const AObj: ISuperObject; out AValue: Integer): Boolean;
begin
  if AObj = nil then Exit(False);
  AValue := AObj.AsInteger;
  Result := True;
end;

function GetVec2_Def(const AObj: ISuperObject; const path: string; const ADefValue: TVec2): TVec2;
var
  obj : ISuperObject;
  sarr: TSuperArray;
begin
  obj := AObj.O[path];
  if obj = nil then Exit(ADefValue);
  if not obj.IsType(stArray) then Exit(ADefValue);
  sarr := obj.AsArray;
  if sarr.Length < 2 then Exit(ADefValue);
  Result.x := sarr.D[0];
  Result.y := sarr.D[1];
end;

function TryGetVec2(const AObj: ISuperObject; var AValue: TVec2): Boolean;
var sarr: TSuperArray;
begin
  if AObj = nil then Exit(False);
  if not AObj.IsType(stArray) then Exit(False);
  sarr := AObj.AsArray;
  if sarr.Length < 2 then Exit(False);
  AValue.x := sarr.D[0];
  AValue.y := sarr.D[1];
  Result := True;
end;

function TryGetVec3(const AObj: ISuperObject; var AValue: TVec3): Boolean;
var sarr: TSuperArray;
begin
  if AObj = nil then Exit(False);
  if not AObj.IsType(stArray) then Exit(False);
  sarr := AObj.AsArray;
  if sarr.Length < 2 then Exit(False);
  AValue.x := sarr.D[0];
  AValue.y := sarr.D[1];
  AValue.z := sarr.D[2];
  Result := True;
end;

function LoadIntArr(const AObj: ISuperObject): TIntArr;
var sarr: TSuperArray;
    i: Integer;
begin
  Result := nil;
  if AObj = nil then Exit;
  if not AObj.IsType(stArray) then Exit;
  sarr := AObj.AsArray;
  SetLength(Result, sarr.Length);
  for i := 0 to sarr.Length - 1 do
    Result[i] := sarr.I[i];
end;

function LoadVec2Arr(const AObj: ISuperObject): TVec2Arr;
var
  i: Integer;
  sarr: TSuperArray;
begin
  Result := nil;
  if AObj = nil then Exit;
  if not AObj.IsType(stArray) then Exit;
  sarr := AObj.AsArray;
  SetLength(Result, sarr.Length);
  for i := 0 to sarr.Length - 1 do
    if not TryGetVec2(sarr.O[i], Result[i]) then Assert(False);
end;


function GetLayer(const AObj: ISuperObject): TGameLayer;
var lName: String;
begin
  lName := AObj.S['Name'];
  for Result := glBack3 to glFore3 do
    if cGameLayerNames[Result] = lName then Exit;
  Result := glNone;
end;

{ TCustomPolyLine }

function TCustomPolyLine.GetPoint(ASegmentIdx: Integer; ASegmentK: Single): TVec2;
begin
  Result := lerp(line[ASegmentIdx], line[ASegmentIdx+1], ASegmentK);
end;

function TCustomPolyLine.MovePointByLine(var ASegmentIdx: Integer; var ASegmentK: Single; AMoveDistance: Single): Boolean;
var v1, v2: TVec2;
    l: Single;
begin
  if AMoveDistance = 0 then Exit(true);
  if (ASegmentIdx >= Length(line) - 1) and (ASegmentK >= 1) then
    Exit(false);
  if (ASegmentIdx >= Length(line)) then Exit(false);

  while true do
  begin
    v1 := line[ASegmentIdx];
    v2 := line[ASegmentIdx+1];
    v1 := lerp(v1, v2, ASegmentK);
    l := Len(v2-v1);
    if l < AMoveDistance then
    begin
      AMoveDistance := AMoveDistance - l;
      if ASegmentIdx = Length(line) - 2 then
      begin
        ASegmentK := 1;
        Exit(False);
      end;
      Inc(ASegmentIdx);
      ASegmentK := 0;
    end
    else
    begin
      ASegmentK := ASegmentK + AMoveDistance / Len(line[ASegmentIdx+1]-line[ASegmentIdx]);
      if ASegmentK > 1 then
      begin
        ASegmentK := 0;
        Inc(ASegmentIdx);
      end;
      Exit(True);
    end;
  end;
end;

{ TLevelLoader }

class function TLevelLoader.LoadItem(const AObj: ISuperObject; const AWorld: TWorld; const ALayer: TGameLayer; const AImages: TImageList): TGameObject;

  function LoadCustomParams(const AObj: ISuperObject): TCustomParams;
  var cpArray: TSuperArray;
      i: Integer;
  begin
    Result := nil;
    if AObj = nil then Exit;
    if not AObj.IsType(stArray) then Exit;
    cpArray := AObj.AsArray;
    SetLength(Result, cpArray.Length);
    for i := 0 to cpArray.Length - 1 do
    begin
      Result[i].name  := cpArray.O[i].S['N'];
      Result[i].value := cpArray.O[i].S['V'];
    end;
  end;

  function GetItemType(const cp: TCustomParams) : TGameObjectClass;
  var clsName: string;
  begin
    clsName := FindCustomValue(cp, 'Class');
    Result := FindClass(clsName);
    if Result <> nil then Exit;
    Result := TGameSprite;
    if AObj.O['Fixtures'] <> nil then
      Result := TGameSingleBody;
  end;

  procedure LoadTris(const AObj: ISuperObject; var ARes: TGameResource);
    procedure AddSpriteIfNotExist(const ASprite: ISpriteIndex);
    var
      i: Integer;
    begin
      for i := 0 to Length(ARes.images) - 1 do
        if ARes.images[i] = ASprite then Exit;
      SetLength(ARes.images, Length(ARes.images)+1);
      ARes.images[High(ARes.images)] := ASprite;
    end;
  var sv  : TSpineVertexEx;
      sarr: TSuperArray;
      i: Integer;
      imgIndex: Integer;
      sprite: ISpriteIndex;
  begin
    ARes.tris := TSpineExVertices.Create;
    if AObj = nil then Exit;
    if not AObj.IsType(stArray) then Exit;
    sarr := AObj.AsArray;

    sv.vsColor := Vec(1,1,1,1);
    for i := 0 to sarr.Length - 1 do
    begin
      if not TryGetI(sarr[i].O['Img'], imgIndex) then Continue;
      if not TryGetVec3(sarr[i].O['Crd'], sv.vsCoord) then Continue;
      if not TryGetVec2(sarr[i].O['Tex'], sv.vsTexCrd) then Continue;
      if not TryGetVec2(sarr[i].O['Wrp'], sv.vsWrapMode) then Continue;
      sprite := AWorld.Atlas.ObtainSprite(Default_ITextureManager.LoadTexture(AImages[imgIndex], SIZE_DEFAULT, SIZE_DEFAULT, TImageFormat.A8R8G8B8).MipData(0,0));
      if sprite = nil then Continue;
      AddSpriteIfNotExist(sprite);
      sv.vsAtlasRef := sprite.Index;
      ARes.tris.Add(sv);
    end;
  end;

  procedure LoadFixtures(const AObj: ISuperObject; var ARes: TGameResource);
  var fixtures : TSuperArray;
      polygons : TSuperArray;
      vertices : TSuperArray;
      circles  : TSuperArray;
      i, j, k, n : Integer;
      v: TVec2;
      v3: TVec3;
  begin
    ARes.fixtures_poly := nil;
    ARes.fixtures_cir  := nil;
    if AObj = nil then Exit;
    if not AObj.IsType(stArray) then Exit;
    fixtures := AObj.AsArray;
    for k := 0 to fixtures.Length - 1 do
    begin
      polygons := fixtures.O[k].A['Polys'];
      if polygons <> nil then
      begin
        n := Length(ARes.fixtures_poly);
        SetLength(ARes.fixtures_poly, n + polygons.Length);
        for i := 0 to polygons.Length - 1 do
        begin
          vertices := polygons[i].AsArray;
          if vertices = nil then
            ARes.fixtures_poly[n+i] := nil
          else
            SetLength(ARes.fixtures_poly[n+i], vertices.Length);
          for j := 0 to vertices.Length - 1 do
          begin
            if not TryGetVec2(vertices.O[j], v) then Assert(False);
            ARes.fixtures_poly[n+i][j] := v;
          end;
        end;
      end;

      circles := fixtures.O[k].A['Circles'];
      if circles <> nil then
      begin
        n := Length(ARes.fixtures_cir);
        SetLength(ARes.fixtures_cir, n + circles.Length);
        for i := 0 to circles.Length - 1 do
        begin
          if not TryGetVec3(circles.O[i], v3) then Assert(False);
          ARes.fixtures_cir[n+i] := v3;
        end;
      end;
    end;
  end;

  procedure LoadShadowCasters(const AObj: ISuperObject; var ARes: TGameResource);
    function GetSignedArea(const Cntr: TVec2Arr): Single;
    var i: Integer;
        p1, p2: TVec2;
    begin
      Result := 0;
      for i := 0 to Length(Cntr) - 1 do
      begin
        p1 := Cntr[i];
        p2 := Cntr[(i+1) mod Length(Cntr)];
        Result := Result + (p1.x+p2.x)*(p2.y-p1.y);
      end;
      Result := Result * 0.5;
    end;

    procedure ReverseCntr(const Cntr: TVec2Arr);
    var i, j: Integer;
        tmp: TVec2;
    begin
      j := Length(Cntr) - 1;
      for i := 0 to (Length(Cntr) div 2) - 1 do
      begin
        tmp := Cntr[i];
        Cntr[i] := Cntr[j];
        Cntr[j] := tmp;
        Dec(j);
      end;
    end;

  var
    i: Integer;
    sarr: TSuperArray;
  begin
    ARes.shadowcasters := nil;
    if AObj = nil then Exit;
    if not AObj.IsType(stArray) then Exit;
    sarr := AObj.AsArray;
    SetLength(ARes.shadowcasters, sarr.Length);
    for i := 0 to sarr.Length - 1 do
    begin
      ARes.shadowcasters[i] := LoadVec2Arr(sarr.O[i]['LineStrip']);
      if GetSignedArea(ARes.shadowcasters[i]) < 0 then
        ReverseCntr(ARes.shadowcasters[i]);
    end;
  end;

var itemType: TGameObjectClass;
    vert   : ISpineExVertices;
    sprites: ISpriteIndexSet;
    cp: TCustomParams;
    res: TGameResource;
begin
  Result := nil;

  cp := LoadCustomParams(AObj.O['Custom']);

  itemType := GetItemType(cp);
  if itemType = nil then Exit;

  LoadTris(AObj.O['Tris'], res);
  LoadFixtures(AObj.O['Fixtures'], res);
  LoadShadowCasters(AObj.O['Shadow'], res);

  Result := itemType.Create(AWorld);
  Result.Size := GetVec2_Def(AObj, 'Scale', Vec(1,1));
  Result.Dir := VecSinCos(GetD_Def(AObj, 'Rot', 0));
  Result.Pos := GetVec2_Def(AObj, 'Pos', Vec(0,0));
  Result.Name := AObj.S['Name'];

  Result.SetResource(res);
end;

class procedure TLevelLoader.LoadLayer(const AObj: ISuperObject; const AWorld: TWorld; const ALayer: TGameLayer; const AImages: TImageList);
var sarr: TSuperArray;
    i: Integer;
    gobj: TGameObject;
    items: ISuperObject;
begin
  items := AObj.O['Items'];
  if items = nil then Exit;
  if not items.IsType(stArray) then Exit;
  sarr := items.AsArray;
  for i := 0 to sarr.Length - 1 do
  begin
    gobj := LoadItem(sarr[i], AWorld, ALayer, AImages);
    gobj.Layer := ALayer;
    gobj.ZIndex := i;
  end;
end;

class function TLevelLoader.LoadImages(const AObj: ISuperObject): TImageList;
var sarr: TSuperArray;
    i: Integer;
begin
  if not AObj.IsType(stArray) then Exit(nil);
  sarr := AObj.AsArray;
  SetLength(Result, sarr.Length);
  for i := 0 to sarr.Length - 1 do
    Result[i] := ExpandFileName(sarr.S[i]);
end;

class procedure TLevelLoader.LoadLayers(const AObj: ISuperObject; const AWorld: TWorld; const AImages: TImageList);
var sarr: TSuperArray;
    i: Integer;
    obj: ISuperObject;
    layer: TGameLayer;
begin
  if not AObj.IsType(stArray) then Exit;
  sarr := AObj.AsArray;
  for i := 0 to sarr.Length - 1 do
  begin
    obj := sarr[i];
    layer := GetLayer(obj);
    if layer = glNone then Continue;
    LoadLayer(obj, AWorld, layer, AImages);
  end;
end;

class procedure TLevelLoader.LoadLevel(const AFileName: String; const AWorld: TWorld);
var obj: ISuperObject;
    images: TImageList;
    oldDir: string;
    i: Integer;
begin
  oldDir := GetCurrentDir;
  try
    SetCurrentDir(ExtractFilePath(AFileName));

    obj := TSuperObject.ParseFile(AFileName, True);
    images := LoadImages(obj.O['Images']);
    for i := 0 to Length(images)-1 do
      Default_ITextureManager.LoadTexture(images[i]);
    LoadLayers(obj.O['Layers'], AWorld, images);
    //LoadLevel(obj.O['composite'], AWorld, IdentityMat3, [], glNone);
  finally
    SetCurrentDir(oldDir);
  end;
end;

end.

