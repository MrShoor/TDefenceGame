unit BLight;

{$IfDef FPC}
  {$mode objfpc}{$H+}
{$Else}
  {$IfDef WIN32} {$Define WINDOWS} {$EndIf}
  {$IfDef WIN64} {$Define WINDOWS} {$EndIf}
{$EndIf}

interface

uses
  Classes, SysUtils, mutils;

type
  ISoundStream = interface
    procedure Play(const ALooped: Boolean = False);
    procedure Stop();
    function Playing: Boolean;
  end;

  TSoundPos = packed record
    Pos: TVec3;
    Dir: TVec3;
    Vel: TVec3;
  end;

  TAttr3DMode = (amNormal, amRelative, amOff);

  TSoundAttr3D = packed record
    Mode      : TAttr3DMode;
    DistRange : TVec2;
    AngleRange: TVec2i;  //in degrees
    OuterVol  : Cardinal;
  end;

  { ISoundStream3D }

  ISoundStream3D = interface (ISoundStream)
    function GetAttr3D: TSoundAttr3D;
    function GetPos3D: TSoundPos;
    procedure SetAttr3D(const AValue: TSoundAttr3D);
    procedure SetPos3D(const AValue: TSoundPos);
    property Pos3D : TSoundPos    read GetPos3D  write SetPos3D;
    property Attr3D: TSoundAttr3D read GetAttr3D write SetAttr3D;
  end;

  TListenerPos = packed record
    Pos   : TVec3;
    Vel   : TVec3;
    Front : TVec3;
    Top   : TVec3;
  end;

  { ILightPlayer }

  ILightPlayer = interface
    function GetListener3DPos: TListenerPos;
    procedure SetListener3DPos(const AValue: TListenerPos);

    procedure DropCache;
    function GetStream(const ASample: string): ISoundStream;
    function GetStream3D(const ASample: string): ISoundStream3D;

    property Listener3DPos: TListenerPos read GetListener3DPos write SetListener3DPos;
  end;

function GetLightPlayer: ILightPlayer;

implementation

uses
  Windows, Bass, avContnrs, avContnrsDefaults;

type
  TSampleKey = packed record
    name   : string;
    is3D   : Boolean;
  end;

  { TSampleKeyHash }

  TSampleKeyHasher = class (TInterfacedObject, IEqualityComparer)
    function Hash(const Value): Cardinal;
    function IsEqual(const Left, Right): Boolean;
  end;

  { TLightPlayer }

  TLightPlayer = class (TInterfacedObject, ILightPlayer)
  private type
    ISample = interface
      function Handle: HSAMPLE;
      function Looped: Boolean;
    end;

    { TSample }

    TSample = class (TObject, ISample)
    private
      FOwner : TLightPlayer;
      FRefCnt: Integer;
      FHandle: HSAMPLE;
      FLooped: Boolean;
    private
      function QueryInterface({$IFDEF FPC_HAS_CONSTREF}constref{$ELSE}const{$ENDIF} iid : tguid;out obj) : {$IfDef FPC}longint{$Else}HResult{$EndIf};{$IFNDEF WINDOWS}cdecl{$ELSE}stdcall{$ENDIF};
      function _AddRef : {$IfDef FPC}longint{$Else}Integer{$EndIf};{$IFNDEF WINDOWS}cdecl{$ELSE}stdcall{$ENDIF};
      function _Release : {$IfDef FPC}longint{$Else}Integer{$EndIf};{$IFNDEF WINDOWS}cdecl{$ELSE}stdcall{$ENDIF};

      function Handle: HSAMPLE;
      function Looped: Boolean;
    public
      constructor Create(const ADesc: TSampleKey; const AOwner: TLightPlayer);
      destructor Destroy; override;
    end;

    { TSoundStream }

    TSoundStream = class (TInterfacedObject, ISoundStream)
    private
      FPlayer : ILightPlayer;
      FSample : ISample;
      FChannel: HCHANNEL;
      procedure Play(const ALooped: Boolean = False);
      procedure Stop();
      function Playing: Boolean;
    public
      procedure SetSample(const ASample: ISample);
      constructor Create(const APlayer: ILightPlayer);
      destructor Destroy; override;
    end;

    { TSoundStream3D }

    TSoundStream3D = class (TSoundStream, ISoundStream3D)
    private
      function GetAttr3D: TSoundAttr3D;
      function GetPos3D : TSoundPos;
      procedure SetAttr3D(const AValue: TSoundAttr3D);
      procedure SetPos3D(const AValue : TSoundPos);
    public
      destructor Destroy; override;
    end;

    ISamples = {$IfDef FPC}specialize{$EndIf} IHashMap<TSampleKey, TSample>;
    TSamples = {$IfDef FPC}specialize{$EndIf} THashMap<TSampleKey, TSample>;
    IStrs = {$IfDef FPC}specialize{$EndIf} IArray<TSampleKey>;
    TStrs = {$IfDef FPC}specialize{$EndIf} TArray<TSampleKey>;
  private
    FSamples : ISamples;
    function ObtainSample(const ASample: string; const Is3D: Boolean): ISample;

    function GetListener3DPos: TListenerPos;
    procedure SetListener3DPos(const AValue: TListenerPos);

    procedure DropCache;
    function GetStream(const ASample: string): ISoundStream;
    function GetStream3D(const ASample: string): ISoundStream3D;
  public
    constructor Create;
    destructor Destroy; override;
  end;

var lPlayer: ILightPlayer;

function GetLightPlayer: ILightPlayer;
begin
  if lPlayer = nil then lPlayer := TLightPlayer.Create;
  Result := lPlayer;
end;

procedure Error(const msg: string);
var
	s: string;
begin
 	s := msg + #13#10 + '(Error code: ' + IntToStr(BASS_ErrorGetCode) + ')';
  raise Exception.Create(s);
end;

{ TSampleKeyHasher }

function TSampleKeyHasher.Hash(const Value): Cardinal;
var v: TSampleKey absolute Value;
begin
  Result := Murmur2(v.name[1], Length(v.name)*SizeOf(Char)) xor Murmur2(v.is3D, SizeOf(v.is3D));
end;

function TSampleKeyHasher.IsEqual(const Left, Right): Boolean;
var l: TSampleKey absolute Left;
    r: TSampleKey absolute Right;
begin
  Result := (l.name = r.name) and (l.is3D = r.is3D);
end;

{ TLightPlayer.TSoundStream3D }

function TLightPlayer.TSoundStream3D.GetAttr3D: TSoundAttr3D;
const BASSToMode: array [0..2] of TAttr3DMode = (amNormal, amRelative, amOff);
var mode: Cardinal;
begin
  if FChannel = 0 then Exit;
  mode := 0;
  ZeroMemory(@Result, SizeOf(Result));
  if not BASS_ChannelGet3DAttributes(FChannel, mode, Result.DistRange.x, Result.DistRange.y, Cardinal(Result.AngleRange.x), Cardinal(Result.AngleRange.y), Result.OuterVol) then
    Error('Error ChannelGet3DAttributes');
  Result.Mode := BASSToMode[mode];
end;

function TLightPlayer.TSoundStream3D.GetPos3D: TSoundPos;
var p, o, v: BASS_3DVECTOR;
begin
  if FChannel = 0 then Exit;
  p.x :=  0; p.y := 0; p.z := 0;
  o.x :=  0; o.y := 0; o.z := 0;
  v.x :=  0; v.y := 0; v.z := 0;
  if not BASS_ChannelGet3DPosition(FChannel, p, o, v) then
    Error('Error ChannelGet3DPosition');
  Result.Pos := Vec(p.x, p.y, p.z);
  Result.Dir := Vec(o.x, o.y, o.z);
  Result.Vel := Vec(v.x, v.y, v.z);
end;

procedure TLightPlayer.TSoundStream3D.SetAttr3D(const AValue: TSoundAttr3D);
const ModeToBASS: array [TAttr3DMode] of Cardinal = (BASS_3DMODE_NORMAL, BASS_3DMODE_RELATIVE, BASS_3DMODE_OFF);
begin
  if FChannel = 0 then Exit;
  if not BASS_ChannelSet3DAttributes(FChannel, ModeToBASS[AValue.Mode], AValue.DistRange.x, AValue.DistRange.y, AValue.AngleRange.x, AValue.AngleRange.y, AValue.OuterVol) then
    Error('Error ChannelSet3DAttributes');
  BASS_Apply3D;
end;

procedure TLightPlayer.TSoundStream3D.SetPos3D(const AValue: TSoundPos);
var p, o, v: BASS_3DVECTOR;
begin
  if FChannel = 0 then Exit;
  p.x := AValue.Pos.x;
  p.y := AValue.Pos.y;
  p.z := AValue.Pos.z;
  o.x := AValue.Dir.x;
  o.y := AValue.Dir.y;
  o.z := AValue.Dir.z;
  v.x := AValue.Vel.x;
  v.y := AValue.Vel.y;
  v.z := AValue.Vel.z;
  if not BASS_ChannelSet3DPosition(FChannel, p, o, v) then
      Error('Error ChannelSet3DPosition');
  BASS_Apply3D;
end;

destructor TLightPlayer.TSoundStream3D.Destroy;
begin
  inherited Destroy;
end;

{ TLightPlayer.TSample }

function TLightPlayer.TSample.QueryInterface({$IFDEF FPC_HAS_CONSTREF}constref{$ELSE}const{$ENDIF} iid : tguid;out obj) : {$IfDef FPC}longint{$Else}HResult{$EndIf};{$IFNDEF WINDOWS}cdecl{$ELSE}stdcall{$ENDIF};
begin
  if getinterface(iid,obj) then
    result:=S_OK
  else
    result:=longint(E_NOINTERFACE);
end;

function TLightPlayer.TSample._AddRef: {$IfDef FPC}longint{$Else}Integer{$EndIf};{$IFNDEF WINDOWS}cdecl{$ELSE}stdcall{$ENDIF};
begin
  Result := InterLockedIncrement(FRefCnt);
end;

function TLightPlayer.TSample._Release: {$IfDef FPC}longint{$Else}Integer{$EndIf};{$IFNDEF WINDOWS}cdecl{$ELSE}stdcall{$ENDIF};
begin
  Result := InterLockedDecrement(FRefCnt);
end;

function TLightPlayer.TSample.Handle: HSAMPLE;
begin
  Result := FHandle;
end;

function TLightPlayer.TSample.Looped: Boolean;
begin
  Result := FLooped;
end;

constructor TLightPlayer.TSample.Create(const ADesc: TSampleKey; const AOwner: TLightPlayer);
var s: UnicodeString;
    flags: Cardinal;
begin
  FOwner := AOwner;
  s := UnicodeString(ADesc.name);
  if ADesc.is3D then
    flags := BASS_UNICODE or BASS_SAMPLE_MONO or BASS_SAMPLE_3D or BASS_SAMPLE_OVER_DIST
  else
    flags := BASS_UNICODE or BASS_SAMPLE_OVER_POS;

  FHandle := BASS_SampleLoad(False, Pointer(s), 0, 0, 5, flags);
  if FHandle = 0 then
    Error('Cant open stream');
end;

destructor TLightPlayer.TSample.Destroy;
begin
  if not BASS_SampleFree(FHandle) then
      Error('Cant free sample');
  inherited Destroy;
end;

{ TLightPlayer.TSoundStream }

procedure TLightPlayer.TSoundStream.Play(const ALooped: Boolean);
begin
  if FChannel = 0 then Exit;
  if not BASS_ChannelPlay(FChannel, False) then
    Error('Cant play');
  if ALooped then
  begin
    BASS_ChannelFlags(FChannel, BASS_SAMPLE_LOOP, BASS_SAMPLE_LOOP);
  end;
end;

function TLightPlayer.TSoundStream.Playing: Boolean;
var activeFlag: DWORD;
begin
  activeFlag := BASS_ChannelIsActive(FChannel);
  Result := (activeFlag = BASS_ACTIVE_PLAYING) or (activeFlag = BASS_ACTIVE_STALLED);
end;

procedure TLightPlayer.TSoundStream.Stop;
begin
  if FChannel = 0 then Exit;
  if not BASS_ChannelStop(FChannel) then
    Error('Cant stop');
end;

procedure TLightPlayer.TSoundStream.SetSample(const ASample: ISample);
var err: LongInt;
begin
  FSample := ASample;
  FChannel := BASS_SampleGetChannel(FSample.Handle, False);
  if FChannel = 0 then
  begin
    err := BASS_ErrorGetCode;
    if err <> BASS_ERROR_NOCHAN then
    begin
      Error('Cant create channel');
    end;
  end;
end;

constructor TLightPlayer.TSoundStream.Create(const APlayer: ILightPlayer);
begin
  FPlayer := APlayer;
end;

destructor TLightPlayer.TSoundStream.Destroy;
begin
  FSample := nil;
  inherited Destroy;
end;

{ TLightPlayer }

function TLightPlayer.ObtainSample(const ASample: string; const Is3D: Boolean): ISample;
var s: TSample;
    key: TSampleKey;
begin
  key.name := ASample;
  key.is3D := Is3D;
  if not FSamples.TryGetValue(key, s) then
  begin
    s := TSample.Create(key, Self);
    FSamples.AddOrSet(key, s);
  end;
  Result := s;
end;

function TLightPlayer.GetListener3DPos: TListenerPos;
var p, v, f, t: BASS_3DVECTOR;
begin
  p.x := 0; p.y := 0; p.z := 0;
  v.x := 0; v.y := 0; v.z := 0;
  f.x := 0; f.y := 0; f.z := 0;
  t.x := 0; t.y := 0; t.z := 0;
  if not BASS_Get3DPosition(p, v, f, t) then
    Error('Error Get3DPosition');
  Result.Pos   := Vec(p.x, p.y, p.z);
  Result.Vel   := Vec(v.x, v.y, v.z);
  Result.Front := Vec(f.x, f.y, f.z);
  Result.Top   := Vec(t.x, t.y, t.z);
end;

procedure TLightPlayer.SetListener3DPos(const AValue: TListenerPos);
var p, v, f, t: BASS_3DVECTOR;
begin
  p.x := AValue.Pos.x;
  p.y := AValue.Pos.y;
  p.z := AValue.Pos.z;

  v.x := AValue.Vel.x;
  v.y := AValue.Vel.y;
  v.z := AValue.Vel.z;

  f.x := AValue.Front.x;
  f.y := AValue.Front.y;
  f.z := AValue.Front.z;

  t.x := AValue.Top.x;
  t.y := AValue.Top.y;
  t.z := AValue.Top.z;
  if not BASS_Set3DPosition(p, v, f, t) then
    Error('Error Set3DPosition');
  BASS_Apply3D;
end;

procedure TLightPlayer.DropCache;
var Key: TSampleKey;
    Value: TSample;
    Keys: IStrs;
    i: Integer;
begin
  Keys := TStrs.Create();
  FSamples.Reset;
  while FSamples.Next(Key, Value) do
  begin
    if Value.FRefCnt = 0 then
    begin
      Keys.Add(Key);
      Value.Free;
    end;
  end;

  for i := 0 to Keys.Count - 1 do
    FSamples.Delete(Keys[i]);
end;

function TLightPlayer.GetStream(const ASample: string): ISoundStream;
var sample: ISample;
    stream: TSoundStream;
begin
  sample := ObtainSample(ASample, False);
  stream := TSoundStream.Create(Self);
  Result := stream;
  stream.SetSample(sample);
end;

function TLightPlayer.GetStream3D(const ASample: string): ISoundStream3D;
var sample: ISample;
    stream: TSoundStream3D;
begin
  sample := ObtainSample(ASample, True);
  stream := TSoundStream3D.Create(Self);
  Result := stream;
  stream.SetSample(sample);
end;

constructor TLightPlayer.Create;
var cmp: IEqualityComparer;
begin
  // check the correct BASS was loaded
  if (HIWORD(BASS_GetVersion) <> BASSVERSION) then
  begin
  	MessageBox(0,'An incorrect version of BASS.DLL was loaded',nil,MB_ICONERROR);
  	Halt;
  end;

  // Initialize audio - default device, 44100hz, stereo, 16 bits
  if not BASS_Init(-1, 44100, BASS_DEVICE_3D, 0, nil) then
  	Error('Error initializing audio!');
  if not BASS_Set3DFactors(1.0, 1.0, 1.0) then
    Error('Error Set3DFactors');

  BASS_SetEAXParameters(-1, 0.0, -1.0, -1.0);

  cmp := TSampleKeyHasher.Create;
  FSamples := TSamples.Create(cmp);
end;

destructor TLightPlayer.Destroy;
begin
  DropCache;
  // Close BASS
  BASS_Free();
  inherited Destroy;
end;

initialization

finalization
  lPlayer := nil;

end.
