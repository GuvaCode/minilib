unit mnSockets;
{**
 *  This file is part of the "Mini Library"
 *
 * @license   modifiedLGPL (modified of http://www.gnu.org/licenses/lgpl.html)
 *            See the file COPYING.MLGPL, included in this distribution,
 * @author    Zaher Dirkey <zaher, zaherdirkey>
 *}

{$IFDEF FPC}
{$mode delphi}
{$ENDIF}
{$M+}
{$H+}

interface

uses
  Classes,
  SysUtils,
  mnStreams;

type
  EmnException = class(Exception);
  EmnSocketException = class(Exception);
  TmnShutdown = (sdReceive, sdSend);
  TmnShutdowns = set of TmnShutdown;
  TmnError = (erSuccess, erTimeout, erClosed, erInvalid);
  TSelectCheck = (slRead, slWrite);

  TmnsoOption = (
    soReuseAddr,
    soKeepAlive,
    soNoDelay,
    //soBroadcast, soDebug, soDontLinger, soDontRoute, soOOBInLine, soAcceptConn
    soWaitBeforeRead, //Wait for data come before read, that double the time wait if you set SetReadTimeout if no data come
    soWaitBeforeWrite, //Wait for ready before write, idk what for
    soCloseTimeout, //close socket if read timeout
    soSSL  //TODO
    );
  TmnsoOptions = set of TmnsoOption;

  //maybe we should name it TmnSocket

  { TmnCustomSocket }

  TmnCustomSocket = class abstract(TObject)
  private
    FShutdownState: TmnShutdowns;
    function GetConnected: Boolean;
  protected
    function GetActive: Boolean; virtual; abstract;
    procedure CheckActive; //this will force exception, cuz you should not use socket in api implmentation without active socket, i meant use it in api section only
    function DoSelect(Timeout: Integer; Check: TSelectCheck): TmnError; virtual; abstract;
    function DoShutdown(How: TmnShutdowns): TmnError; virtual; abstract;
    function DoListen: TmnError; virtual; abstract;
    function DoSend(const Buffer; var Count: Longint): TmnError; virtual; abstract;
    function DoReceive(var Buffer; var Count: Longint): TmnError; virtual; abstract;
    property ShutdownState: TmnShutdowns read FShutdownState;
  public
    constructor Create;
    destructor Destroy; override;
    procedure Prepare; virtual;
    function Shutdown(How: TmnShutdowns): TmnError;
    function Close: TmnError; virtual; abstract;
    function Send(const Buffer; var Count: Longint): TmnError;
    function Receive(var Buffer; var Count: Longint): TmnError;
    function Select(Timeout: Integer; Check: TSelectCheck): TmnError;
    function Listen: TmnError;
    function Accept: TmnCustomSocket; virtual; abstract;
    property Active: Boolean read GetActive;
    property Connected: Boolean read GetConnected;
    function GetLocalAddress: string; virtual; abstract;
    function GetRemoteAddress: string; virtual; abstract;
    function GetLocalName: string; virtual; abstract;
    function GetRemoteName: string; virtual; abstract;
  end;

  { TmnCustomWallSocket }

  TmnCustomWallSocket = class abstract(TObject)
  private
  public
    constructor Create; virtual;
    destructor Destroy; override;
    procedure Bind(Options: TmnsoOptions; ReadTimeout: Integer; const Port: string; const Address: string; out vSocket: TmnCustomSocket; out vErr: Integer); virtual; abstract;
    procedure Connect(Options: TmnsoOptions; ConnectTimeout, ReadTimeout: Integer; const Port: string; const Address: string; out vSocket: TmnCustomSocket; out vErr: Integer); virtual; abstract;
  end;

  { Streams
    You can use mnClient.TmnClientSocketStrean or mnServer also
  }

  { TmnSocketStream }

  TmnSocketStream = class (TmnConnectionStream)
  private
    FSocket: TmnCustomSocket;
    FOptions: TmnsoOptions;
  protected
    procedure FreeSocket; virtual;
    function GetConnected: Boolean; override;
    function CreateSocket(out vErr: Integer): TmnCustomSocket; virtual;
    function DoRead(var Buffer; Count: Longint): Longint; override;
    function DoWrite(const Buffer; Count: Longint): Longint; override;
    procedure DoCloseWrite; override;
    procedure DoCloseRead; override;
    procedure DoHandleError(var Handle: Boolean; AError: Integer); virtual;
    function HandleError(AError: Integer): Boolean;
  public
    constructor Create; overload;
    constructor Create(vSocket: TmnCustomSocket); overload;
    destructor Destroy; override;
    procedure Connect; override;
    procedure Disconnect; override;
    function WaitToRead(vTimeout: Longint): TmnConnectionError; override; //select
    function WaitToWrite(vTimeout: Longint): TmnConnectionError; override; //select
    property Socket: TmnCustomSocket read FSocket;
    property Options: TmnsoOptions read FOptions write FOptions;
  end;

const
  WaitForEver: Longint = -1;

var
  //You can use full path, we will move it inside server object
  PrivateKeyFile: string = 'privatekey.pem';
  CertificateFile: string = 'certificate.pem';

function WallSocket: TmnCustomWallSocket;

implementation

uses
  {$ifdef FPC}
    {$ifdef WINDOWS} //Win32 and WinCE
     mnWinSockets
    {$else}
    {$ifdef LINUX}
     mnLinuxSockets
    {$endif}
    {$endif};
  {$else}
    {$if DEFINED(MSWINDOWS)} //Win32 and WinCE
     mnWinSockets //delphi is only Win32
    {$elseif DEFINED(LINUX)}
     mndLinuxSockets
    {$else}
     mnPosixSockets
    {$ifend};
  {$endif}
var
  FmnWallSocket: TmnCustomWallSocket = nil;

function WallSocket: TmnCustomWallSocket;
begin
  if FmnWallSocket = nil then
    FmnWallSocket := TmnWallSocket.Create;
  Result := FmnWallSocket;
end;

{ TmnCustomWallSocket }

constructor TmnCustomWallSocket.Create;
begin
  inherited;
end;

destructor TmnCustomWallSocket.Destroy;
begin
  inherited;
end;

{ TmnCustomSocket }

procedure TmnCustomSocket.CheckActive;
begin
  if (Self = nil) or (not Active) then
  begin
    Close;
    raise EmnException.Create('Socket is inactive');
  end
end;

constructor TmnCustomSocket.Create;
begin
  inherited;
end;

destructor TmnCustomSocket.Destroy;
begin
  if Active then
  begin
    Close;
  end;
  inherited;
end;

procedure TmnCustomSocket.Prepare;
begin
end;

function TmnCustomSocket.GetConnected: Boolean;
begin
  Result := Active and ([sdReceive, sdSend] <> FShutdownState)
end;

function TmnCustomSocket.Listen: TmnError;
begin
  Result := DoListen;
  if Result > erTimeout then
    Close;
end;

function TmnCustomSocket.Receive(var Buffer; var Count: Longint): TmnError;
begin
  Result := DoReceive(Buffer, Count);
  if Result > erTimeout then
    Close;
end;

function TmnCustomSocket.Select(Timeout: Integer; Check: TSelectCheck): TmnError;
begin
  Result := DoSelect(Timeout, Check);
  if Result > erTimeout then
    Close;
end;

function TmnCustomSocket.Send(const Buffer; var Count: Longint): TmnError;
begin
  Result := DoSend(Buffer, Count);
  if Result > erTimeout then
    Close;
end;

function TmnCustomSocket.Shutdown(How: TmnShutdowns): TmnError;
begin
  if How <> [] then
  begin
    Result := DoShutdown(How);
    if Result = erSuccess then
      FShutdownState := FShutdownState + How
    else
      if Result > erTimeout then
        Close;
  end
  else
    Result := erSuccess;
end;

{ TmnStream }

destructor TmnSocketStream.Destroy;
begin
  try
    Disconnect;
  finally
    inherited;
  end;
end;

function TmnSocketStream.DoWrite(const Buffer; Count: Longint): Longint;
begin
  if not Connected then
  begin
    FreeSocket;
    Result := 0;
    //DoError('Write: SocketStream not connected.') //we can't decide if it is error or disconnected gracefully, you need to check connected before write, maybe socket shutdown for write only
  end
  else if not (soWaitBeforeWrite in Options) or (WaitToWrite(WriteTimeout) = cerSuccess) then //TODO WriteTimeout
  begin
    if Socket.Send(Buffer, Count) >= erTimeout then //yes in send we take timeout as error, we cant try again
    begin
      FreeSocket;
      Result := 0;
    end
    else
      Result := Count;
  end
  else
  begin
    FreeSocket;
    Result := 0;
  end
end;

procedure TmnSocketStream.DoCloseWrite;
begin
  inherited;
  if Socket <> nil then
    Socket.Shutdown([sdSend]);
end;

procedure TmnSocketStream.DoCloseRead;
begin
  inherited;
  if Socket <> nil then
    Socket.Shutdown([sdReceive]);
end;

procedure TmnSocketStream.DoHandleError(var Handle: Boolean; AError: Integer);
begin
end;

function TmnSocketStream.HandleError(AError: Integer): Boolean;
begin
  Result := False;
  DoHandleError(Result, AError);
end;

function TmnSocketStream.DoRead(var Buffer; Count: Longint): Longint;
var
  err: TmnError;
  werr: TmnConnectionError;
begin
  Result := 0;
  if not Connected then
    ReadError //set EOF or raise error, not sure about raising error
  else
  begin
    if soWaitBeforeRead in Options then
      werr := WaitToRead(ReadTimeout)
    else
      werr := cerSuccess;

    if (werr = cerTimeout) then
    begin
      if soCloseTimeout in Options then
        FreeSocket;

      Result := 0;
    end
    else if (werr = cerSuccess) then
    begin
      err := Socket.Receive(Buffer, Count);
      if ((err = erTimeout) and (soCloseTimeout in Options)) or (err >= erClosed) then
      begin
        FreeSocket;
        Result := 0;
      end
      else
        Result := Count;
    end
    else
    begin
      FreeSocket;
      Result := 0;
    end;
  end;
end;

constructor TmnSocketStream.Create(vSocket: TmnCustomSocket);
begin
  inherited Create;
  FOptions := [soNoDelay];
  FSocket := vSocket;
end;

constructor TmnSocketStream.Create;
begin
  Create(nil);
end;

procedure TmnSocketStream.Disconnect;
begin
  if (Socket <> nil) and Socket.Connected then
    Close; //may be not but in slow matchine disconnect to take as effects as need (POS in 98)
  FreeSocket;
end;

function TmnSocketStream.GetConnected: Boolean;
begin
  Result := (Socket <> nil) and (Socket.Connected);
end;

procedure TmnSocketStream.Connect;
var
  aErr: Integer;
begin
  if Connected then
    raise EmnStreamException.Create('Already connected');

  if FSocket <> nil then
    raise EmnStreamException.Create('Socket must be nil');

  FSocket := CreateSocket(aErr);

  if FSocket = nil then
    if not HandleError(aErr) then
      raise EmnSocketException.CreateFmt('Connected fail [%d]', [aErr]);
end;

function TmnSocketStream.CreateSocket(out vErr: Integer): TmnCustomSocket;
begin
  Result := nil;//if server connect no need to create socket
end;

function TmnSocketStream.WaitToRead(vTimeout: Longint): TmnConnectionError;
var
  err: TmnError;
begin
  err := Socket.Select(vTimeout, slRead);
  if err = erSuccess then
    Result := cerSuccess
  else if (err = erTimeout) then
    Result := cerTimeout
  else
    Result := cerError;
end;

function TmnSocketStream.WaitToWrite(vTimeout: Longint): TmnConnectionError;
var
  err: TmnError;
begin
  err := Socket.Select(vTimeout, slWrite);
  if err = erSuccess then
    Result := cerSuccess
  else
    Result := cerError;
end;

procedure TmnSocketStream.FreeSocket;
begin
  FreeAndNil(FSocket);
end;

initialization
finalization
  FreeAndNil(FmnWallSocket);
end.
