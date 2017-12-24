unit B2Utils;
{$IfDef FPC}
  {$Macro On}
  {$mode objfpc}{$H+}
  {$ModeSwitch advancedrecords}
  {$IfDef CPU86}
    {$FPUType sse2}
  {$EndIf}
  {$IfDef CPU64}
    {$FPUType sse64}
  {$EndIf}
  {$Define notDCC}
{$Else}
  {$Define DCC}
  {$IfDef WIN32}
    {$Define Windows}
  {$EndIf}
  {$IfDef WIN64}
    {$Define Windows}
  {$EndIf}
{$EndIf}

interface

uses
  SysUtils
  {$IfDef DCC}
    {$IfDef Windows}
    ,Windows
    {$EndIf}
  {$EndIf}
  , UPhysics2D, UPhysics2DTypes, IntfUtils;

type
  TOnHit = procedure (const OtherFixture: Tb2Fixture; const ThisFixture: Tb2Fixture; const AManifold: Tb2WorldManifold) of object;
  TOnLeave = procedure (const OtherFixture: Tb2Fixture; const ThisFixture: Tb2Fixture) of object;
  TOnPreSolve = procedure (const OtherFixture: Tb2Fixture; const ThisFixture: Tb2Fixture; var contact: Tb2Contact; const oldManifold: Tb2Manifold) of object;
  TOnPostSolve = procedure (const OtherFixture: Tb2Fixture; const ThisFixture: Tb2Fixture; var contact: Tb2Contact; const impulse: Tb2ContactImpulse) of object;

  TOnAllowContact = function (const OtherFixture: Tb2Fixture; const ThisFixture: Tb2Fixture): Boolean of object;

  IOnHitSubscriber = interface
  ['{A0D933B4-392D-454B-9859-DF9D572EC4B1}']
    function Body: Tb2Body;
    procedure OnHit(const OtherFixture: Tb2Fixture; const ThisFixture: Tb2Fixture; const AManifold: Tb2WorldManifold);
    procedure OnLeave(const OtherFixture: Tb2Fixture; const ThisFixture: Tb2Fixture);
  end;

  IOnPrePostSolver = interface
  ['{688789A6-9B99-4EEC-9922-132FC03F42A5}']
    function  Body: Tb2Body;
    procedure OnPreSolve(const OtherFixture: Tb2Fixture; const ThisFixture: Tb2Fixture; var contact: Tb2Contact; const oldManifold: Tb2Manifold);
    procedure OnPostSolve(const OtherFixture: Tb2Fixture; const ThisFixture: Tb2Fixture; var contact: Tb2Contact; const impulse: Tb2ContactImpulse);
  end;

  IOnFilterSubscriber = interface
  ['{3AD3716E-CF45-4231-8A79-5E967BCCBFC1}']
    function Body: Tb2Body;
    function OnAllowContact(const OtherFixture: Tb2Fixture; const ThisFixture: Tb2Fixture): Boolean;
  end;

  TOnHitSubscriber = class(TWeakedInterfacedObject, IOnHitSubscriber)
  private
    FOnHit   : TOnHit;
    FOnLeave : TOnLeave;
    FBody    : Tb2Body;
    function Body: Tb2Body;
    procedure OnHit(const OtherFixture: Tb2Fixture; const ThisFixture: Tb2Fixture; const AManifold: Tb2WorldManifold);
    procedure OnLeave(const OtherFIxture: Tb2Fixture; const ThisFixture: Tb2Fixture);
  public
    constructor Create(const ABody: Tb2Body; const AOnHit: TOnHit; const AOnLeave: TOnLeave);
  end;

  TOnPrePostSolverSubscriber = class(TWeakedInterfacedObject, IOnPrePostSolver)
  private
    FBody       : Tb2Body;
    FOnPreSolve : TOnPreSolve;
    FOnPostSolve: TOnPostSolve;
    function Body: Tb2Body;
    procedure OnPreSolve(const OtherFixture: Tb2Fixture; const ThisFixture: Tb2Fixture; var contact: Tb2Contact; const oldManifold: Tb2Manifold);
    procedure OnPostSolve(const OtherFixture: Tb2Fixture; const ThisFixture: Tb2Fixture; var contact: Tb2Contact; const impulse: Tb2ContactImpulse);
  public
    constructor Create(const ABody: Tb2Body; const AOnPresolve: TOnPreSolve; const AOnPostSolve: TOnPostSolve);
  end;

  TOnFilterSubscriber = class(TWeakedInterfacedObject, IOnFilterSubscriber)
  private
    FBody: Tb2Body;
    FOnAllowContact: TOnAllowContact;
    function Body: Tb2Body;
    function OnAllowContact(const OtherFixture: Tb2Fixture; const ThisFixture: Tb2Fixture): Boolean;
  public
    constructor Create(const ABody: Tb2Body; const AOnAllowContact: TOnAllowContact);
  end;

  TContactListener = class (Tb2ContactListener, IUnknown, IPublisher)
  private
    FRefCnt: Integer;
    FWorld : Tb2World;
  private
    function QueryInterface({$IFDEF FPC_HAS_CONSTREF}constref{$ELSE}const{$ENDIF} iid : tguid;out obj) : HRes;{$IFNDEF WINDOWS}cdecl{$ELSE}stdcall{$ENDIF};
    function _AddRef : longint;{$IFNDEF WINDOWS}cdecl{$ELSE}stdcall{$ENDIF};
    function _Release : longint;{$IFNDEF WINDOWS}cdecl{$ELSE}stdcall{$ENDIF};
  public
      function QueryCallback(proxyId: Int32): Boolean; override;
      function RayCastCallback(const input: Tb2RayCastInput; proxyId: Int32): PhysicsFloat; override;
  public
      /// Called when two fixtures begin to touch.
      procedure BeginContact(var contact: Tb2Contact); override;

      /// Called when two fixtures cease to touch.
      procedure EndContact(var contact: Tb2Contact); override;

      /// This is called after a contact is updated. This allows you to inspect a
      /// contact before it goes to the solver. If you are careful, you can modify the
      /// contact manifold (e.g. disable contact).
      /// A copy of the old manifold is provided so that you can detect changes.
      /// Note: this is called only for awake bodies.
      /// Note: this is called even when the number of contact points is zero.
      /// Note: this is not called for sensors.
      /// Note: if you set the number of contact points to zero, you will not
      /// get an EndContact callback. However, you may get a BeginContact callback
      /// the next step.
      procedure PreSolve(var contact: Tb2Contact; const oldManifold: Tb2Manifold); override;

      /// This lets you inspect a contact after the solver is finished. This is useful
      /// for inspecting impulses.
      /// Note: the contact manifold does not include time of impact impulses, which can be
      /// arbitrarily large if the sub-step is small. Hence the impulse is provided explicitly
      /// in a separate data structure.
      /// Note: this is only called for contacts that are touching, solid, and awake.
      procedure PostSolve(var contact: Tb2Contact; const impulse: Tb2ContactImpulse); override;
  public
    FSubs : array of IWeakRefIntf;
    FSubsPrePost: array of IWeakRefIntf;
    function IndexOf(const ASubscriber: IWeakedInterface): Integer;
    function IndexOfPrePost(const ASubscriber: IWeakedInterface): Integer;
    procedure Subscribe  (const ASubscriber: IWeakedInterface);
    procedure UnSubscribe(const ASubscriber: IWeakedInterface);
  public
    constructor Create(const AWorld: Tb2World);
    destructor Destroy; override;
  end;

  TContactFilter = class (Tb2ContactFilter, IUnknown, IPublisher)
  private
    FRefCnt: Integer;
    FWorld : Tb2World;
  private
    function QueryInterface({$IFDEF FPC_HAS_CONSTREF}constref{$ELSE}const{$ENDIF} iid : tguid;out obj) : HRes;{$IFNDEF WINDOWS}cdecl{$ELSE}stdcall{$ENDIF};
    function _AddRef : longint;{$IFNDEF WINDOWS}cdecl{$ELSE}stdcall{$ENDIF};
    function _Release : longint;{$IFNDEF WINDOWS}cdecl{$ELSE}stdcall{$ENDIF};
  public
    FSubs : array of IWeakRefIntf;
    function IndexOf(const ASubscriber: IWeakedInterface): Integer;
    procedure Subscribe  (const ASubscriber: IWeakedInterface);
    procedure UnSubscribe(const ASubscriber: IWeakedInterface);
  public
    function ShouldCollide(fixtureA, fixtureB: Tb2Fixture): Boolean; override;
  public
    constructor Create(const AWorld: Tb2World);
    destructor Destroy; override;
  end;

implementation

{ TContactListener }

procedure TContactListener.BeginContact(var contact: Tb2Contact);
var bodyA, bodyB: Tb2Body;

    i    : Integer;
    cnt  : Integer;
    sub  : IUnknown;
    OnHit: IOnHitSubscriber;

    wManifold : Tb2WorldManifold;
begin
  inherited;
  bodyA := contact.m_fixtureA.GetBody;
  bodyB := contact.m_fixtureB.GetBody;

  cnt := Length(FSubs);
  if cnt > 0 then
    contact.GetWorldManifold(wManifold);

  i := 0;
  while i < cnt do
  begin
    sub := FSubs[i].Intf;
    if sub = nil then
    begin
      Dec(cnt);
      FSubs[i] := FSubs[cnt];
      FSubs[cnt] := nil;
    end
    else
    begin
      //
      if Supports(sub, IOnHitSubscriber, OnHit) then
      begin
        if OnHit.Body = bodyA then
          OnHit.OnHit(contact.m_fixtureB, contact.m_fixtureA, wManifold);
        if OnHit.Body = bodyB then
          OnHit.OnHit(contact.m_fixtureA, contact.m_fixtureB, wManifold);
      end;
      //
      Inc(i);
    end;
  end;
  if Length(FSubs) <> cnt then
    SetLength(FSubs, cnt);
end;

constructor TContactListener.Create(const AWorld: Tb2World);
begin
  FWorld := AWorld;
  FWorld.SetContactListener(Self);
end;

destructor TContactListener.Destroy;
begin
  FWorld.SetContactListener(nil);
  inherited;
end;

procedure TContactListener.EndContact(var contact: Tb2Contact);
var bodyA, bodyB: Tb2Body;

    i    : Integer;
    cnt  : Integer;
    sub  : IUnknown;
    OnHit: IOnHitSubscriber;
begin
  inherited;
  bodyA := contact.m_fixtureA.GetBody;
  bodyB := contact.m_fixtureB.GetBody;

  cnt := Length(FSubs);
  i := 0;
  while i < cnt do
  begin
    sub := FSubs[i].Intf;
    if sub = nil then
    begin
      Dec(cnt);
      FSubs[i] := FSubs[cnt];
      FSubs[cnt] := nil;
    end
    else
    begin
      //
      if Supports(sub, IOnHitSubscriber, OnHit) then
      begin
        if OnHit.Body = bodyA then
          OnHit.OnLeave(contact.m_fixtureB, contact.m_fixtureA);
        if OnHit.Body = bodyB then
          OnHit.OnLeave(contact.m_fixtureA, contact.m_fixtureB);
      end;
      //
      Inc(i);
    end;
  end;
  SetLength(FSubs, cnt);
end;

function TContactListener.IndexOf(const ASubscriber: IWeakedInterface): Integer;
var i: Integer;
begin
  Result := -1;
  for i := 0 to Length(FSubs) - 1 do
    if FSubs[i] = ASubscriber.WeakRef then Exit(i);
end;

function TContactListener.IndexOfPrePost(const ASubscriber: IWeakedInterface): Integer;
var i: Integer;
begin
  Result := -1;
  for i := 0 to Length(FSubsPrePost) - 1 do
    if FSubsPrePost[i] = ASubscriber.WeakRef then Exit(i);
end;

procedure TContactListener.PostSolve(var contact: Tb2Contact; const impulse: Tb2ContactImpulse);
var bodyA, bodyB: Tb2Body;

    i    : Integer;
    cnt  : Integer;
    sub  : IUnknown;
    OnPrePostSolver: IOnPrePostSolver;
begin
  inherited;
  bodyA := contact.m_fixtureA.GetBody;
  bodyB := contact.m_fixtureB.GetBody;

  cnt := Length(FSubsPrePost);
  i := 0;
  while i < cnt do
  begin
    sub := FSubsPrePost[i].Intf;
    if sub = nil then
    begin
      Dec(cnt);
      FSubsPrePost[i] := FSubsPrePost[cnt];
      FSubsPrePost[cnt] := nil;
    end
    else
    begin
      //
      if Supports(sub, IOnPrePostSolver, OnPrePostSolver) then
      begin
        if OnPrePostSolver.Body = bodyA then
          OnPrePostSolver.OnPostSolve(contact.m_fixtureB, contact.m_fixtureA, contact, impulse);
        if OnPrePostSolver.Body = bodyB then
          OnPrePostSolver.OnPostSolve(contact.m_fixtureA, contact.m_fixtureB, contact, impulse);
      end;
      //
      Inc(i);
    end;
  end;
  SetLength(FSubsPrePost, cnt);
end;

procedure TContactListener.PreSolve(var contact: Tb2Contact; const oldManifold: Tb2Manifold);
var bodyA, bodyB: Tb2Body;

    i    : Integer;
    cnt  : Integer;
    sub  : IUnknown;
    OnPrePostSolver: IOnPrePostSolver;
begin
  inherited;
  bodyA := contact.m_fixtureA.GetBody;
  bodyB := contact.m_fixtureB.GetBody;

  cnt := Length(FSubsPrePost);
  i := 0;
  while i < cnt do
  begin
    sub := FSubsPrePost[i].Intf;
    if sub = nil then
    begin
      Dec(cnt);
      FSubsPrePost[i] := FSubsPrePost[cnt];
      FSubsPrePost[cnt] := nil;
    end
    else
    begin
      //
      if Supports(sub, IOnPrePostSolver, OnPrePostSolver) then
      begin
        if OnPrePostSolver.Body = bodyA then
          OnPrePostSolver.OnPreSolve(contact.m_fixtureB, contact.m_fixtureA, contact, oldManifold);
        if OnPrePostSolver.Body = bodyB then
          OnPrePostSolver.OnPreSolve(contact.m_fixtureA, contact.m_fixtureB, contact, oldManifold);
      end;
      //
      Inc(i);
    end;
  end;
  SetLength(FSubsPrePost, cnt);
end;

function TContactListener.QueryCallback(proxyId: Int32): Boolean;
begin

end;

function TContactListener.QueryInterface({$IFDEF FPC_HAS_CONSTREF}constref{$ELSE}const{$ENDIF} iid : tguid;out obj) : HRes;{$IFNDEF WINDOWS}cdecl{$ELSE}stdcall{$ENDIF};
begin
  if GetInterface(IID, Obj) then
    Result := S_OK
  else
    Result := E_NOINTERFACE;
end;

function TContactListener.RayCastCallback(const input: Tb2RayCastInput;
  proxyId: Int32): PhysicsFloat;
begin

end;

procedure TContactListener.Subscribe(const ASubscriber: IWeakedInterface);
begin
  if Supports(ASubscriber, IOnHitSubscriber) then
  begin
    SetLength(FSubs, Length(FSubs)+1);
    FSubs[High(FSubs)] := ASubscriber.WeakRef;
  end;
  if Supports(ASubscriber, IOnPrePostSolver) then
  begin
    SetLength(FSubsPrePost, Length(FSubsPrePost)+1);
    FSubsPrePost[High(FSubsPrePost)] := ASubscriber.WeakRef;
  end;
end;

procedure TContactListener.UnSubscribe(const ASubscriber: IWeakedInterface);
var n, last: Integer;
begin
  if Supports(ASubscriber, IOnHitSubscriber) then
  begin
    n := IndexOf(ASubscriber);
    if n < 0 then Exit;
    last := High(FSubs);
    if n <> last then FSubs[n] := FSubs[last];
    FSubs[last] := nil;
    SetLength(FSubs, last);
  end;
  if Supports(ASubscriber, IOnPrePostSolver) then
  begin
    n := IndexOfPrePost(ASubscriber);
    if n < 0 then Exit;
    last := High(FSubsPrePost);
    if n <> last then FSubsPrePost[n] := FSubsPrePost[last];
    FSubsPrePost[last] := nil;
    SetLength(FSubsPrePost, last);
  end;
end;

function TContactListener._AddRef: longint; stdcall;
begin
  FRefCnt := InterLockedIncrement(FRefCnt);
  Result := FRefCnt;
end;

function TContactListener._Release: longint; stdcall;
begin
  FRefCnt := InterLockedDecrement(FRefCnt);
  if FRefCnt = 0 then
    Free;
  Result := FRefCnt;
end;

{ TOnHitSubscriber }

function TOnHitSubscriber.Body: Tb2Body;
begin
  Result := FBody;
end;

constructor TOnHitSubscriber.Create(const ABody: Tb2Body; const AOnHit: TOnHit; const AOnLeave: TOnLeave);
begin
  FBody := ABody;
  FOnHit := AOnHit;
  FOnLeave := AOnLeave;
end;

procedure TOnHitSubscriber.OnHit(const OtherFixture: Tb2Fixture; const ThisFixture: Tb2Fixture; const AManifold: Tb2WorldManifold);
begin
  if Assigned(FOnHit) then
    FOnHit(OtherFixture, ThisFixture, AManifold);
end;

procedure TOnHitSubscriber.OnLeave(const OtherFixture: Tb2Fixture; const ThisFixture: Tb2Fixture);
begin
  if Assigned(FOnLeave) then
    FOnLeave(OtherFixture, ThisFixture);
end;

{ TOnFilterSubscriber }

function TOnFilterSubscriber.Body: Tb2Body;
begin
  Result := FBody;
end;

constructor TOnFilterSubscriber.Create(const ABody: Tb2Body; const AOnAllowContact: TOnAllowContact);
begin
  FBody := ABody;
  FOnAllowContact := AOnAllowContact;
end;

function TOnFilterSubscriber.OnAllowContact(const OtherFixture, ThisFixture: Tb2Fixture): Boolean;
begin
  if Assigned(FOnAllowContact) then
    Result := FOnAllowContact(OtherFixture, ThisFixture)
  else
    Result := True;
end;

{ TContactFilter }

constructor TContactFilter.Create(const AWorld: Tb2World);
begin
  FWorld := AWorld;
  FWorld.SetContactFilter(Self);
end;

destructor TContactFilter.Destroy;
begin
  FWorld.SetContactFilter(nil);
  inherited;
end;

function TContactFilter.IndexOf(const ASubscriber: IWeakedInterface): Integer;
var i: Integer;
begin
  Result := -1;
  for i := 0 to Length(FSubs) - 1 do
    if FSubs[i] = ASubscriber.WeakRef then Exit(i);
end;

function TContactFilter.QueryInterface({$IFDEF FPC_HAS_CONSTREF}constref{$ELSE}const{$ENDIF} iid : tguid;out obj) : HRes;{$IFNDEF WINDOWS}cdecl{$ELSE}stdcall{$ENDIF};
begin
  if GetInterface(IID, Obj) then
    Result := S_OK
  else
    Result := E_NOINTERFACE;
end;

function TContactFilter.ShouldCollide(fixtureA, fixtureB: Tb2Fixture): Boolean;
var bodyA, bodyB: Tb2Body;
    cnt  : Integer;
    sub  : IUnknown;
    OnFilter: IOnFilterSubscriber;
    i: Integer;
begin
  Result := inherited ShouldCollide(fixtureA, fixtureB);
  if not Result then Exit;
  cnt := Length(FSubs);

  bodyA := fixtureA.GetBody;
  bodyB := fixtureB.GetBody;

  i := 0;
  while i < cnt do
  begin
    sub := FSubs[i].Intf;
    if sub = nil then
    begin
      Dec(cnt);
      FSubs[i] := FSubs[cnt];
      FSubs[cnt] := nil;
    end
    else
    begin
      //
      if Supports(sub, IOnFilterSubscriber, OnFilter) then
      begin
        if OnFilter.Body = bodyA then
        begin
          Result := OnFilter.OnAllowContact(fixtureB, fixtureA);
          if not Result then Exit;
        end;
        if OnFilter.Body = bodyB then
        begin
          Result := OnFilter.OnAllowContact(fixtureA, fixtureB);
          if not Result then Exit;
        end;
      end;
      //
      Inc(i);
    end;
  end;
end;

procedure TContactFilter.Subscribe(const ASubscriber: IWeakedInterface);
begin
  SetLength(FSubs, Length(FSubs)+1);
  FSubs[High(FSubs)] := ASubscriber.WeakRef;
end;

procedure TContactFilter.UnSubscribe(const ASubscriber: IWeakedInterface);
var n, last: Integer;
begin
  n := IndexOf(ASubscriber);
  if n < 0 then Exit;
  last := High(FSubs);
  if n <> last then FSubs[n] := FSubs[last];
  FSubs[last] := nil;
  SetLength(FSubs, last);
end;

function TContactFilter._AddRef: longint;{$IFNDEF WINDOWS}cdecl{$ELSE}stdcall{$ENDIF};
begin
  FRefCnt := InterLockedIncrement(FRefCnt);
  Result := FRefCnt;
end;

function TContactFilter._Release: longint;{$IFNDEF WINDOWS}cdecl{$ELSE}stdcall{$ENDIF};
begin
  FRefCnt := InterLockedDecrement(FRefCnt);
  if FRefCnt = 0 then
    Free;
  Result := FRefCnt;
end;

{ TOnPrePostSolverSubscriber }

function TOnPrePostSolverSubscriber.Body: Tb2Body;
begin
  Result := FBody;
end;

constructor TOnPrePostSolverSubscriber.Create(const ABody: Tb2Body; const AOnPresolve: TOnPreSolve; const AOnPostSolve: TOnPostSolve);
begin
  FBody := ABody;
  FOnPreSolve := AOnPresolve;
  FOnPostSolve := AOnPostSolve;
end;

procedure TOnPrePostSolverSubscriber.OnPostSolve(const OtherFixture: Tb2Fixture; const ThisFixture: Tb2Fixture; var contact: Tb2Contact; const impulse: Tb2ContactImpulse);
begin
  if Assigned(FOnPostSolve) then FOnPostSolve(OtherFixture, ThisFixture, contact, impulse);
end;

procedure TOnPrePostSolverSubscriber.OnPreSolve(const OtherFixture: Tb2Fixture; const ThisFixture: Tb2Fixture; var contact: Tb2Contact; const oldManifold: Tb2Manifold);
begin
  if Assigned(FOnPreSolve) then FOnPreSolve(OtherFixture, ThisFixture, contact, oldManifold);
end;

end.
