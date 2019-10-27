unit mnStreamUtils;

{**
 *  This file is part of the "Mini Library"
 *
 * @license   modifiedLGPL (modified of http://www.gnu.org/licenses/lgpl.html)
 *            See the file COPYING.MLGPL, included in this distribution,
 * @author    Zaher Dirkey <zaher at parmaja dot com>
 * @ported    Most code of deflate and inflate ported from FPC source zstream, i just wrapped it into my StreamProxy
 *}

{$M+}{$H+}
{$IFDEF FPC}
{$MODE delphi}
{$ENDIF}

{.$define NoLog}

interface

uses
  Classes, SysUtils,
  {$ifdef FPC}zstream, {$endif} zlib,
  mnStreams;

type

  { TmnDeflateWriteStreamProxy }

  { TmnDeflateStreamProxy }

  TmnDeflateStreamProxy = class(TmnStreamOverProxy)
  private
    FLevel: TCompressionlevel;
    FGZip: Boolean;
  private
    WriteInfo: record
      ZStream: z_stream;
      ZBuffer: pointer;
    end;
    ReadInfo: record
      ZStream: z_stream;
      ZBuffer: pointer;
    end;
  const
    BufSize = 16384;
    DEF_MEM_LEVEL = 8;
    MAX_WBITS = 15;
  protected
    procedure InitWrite;
    procedure InitRead;
    procedure InternalCloseWrite;
    procedure InternalCloseRead;
  public
    constructor Create(Level: TCompressionlevel; GZip: Boolean = False);
    destructor Destroy; override;
    function Write(const Buffer; Count: Longint; out ResultCount, RealCount: Longint): Boolean; override;
    function Read(var Buffer; Count: Longint; out ResultCount, RealCount: Longint): Boolean; override;
    procedure CloseWrite; override;
    procedure CloseRead; override;
  end;

implementation

{ TmnDeflateWriteStreamProxy }

function TmnDeflateStreamProxy.Write(const Buffer; Count: Longint; out ResultCount, RealCount: Longint): Boolean;
var
  err: Smallint;
  HaveWrite: Longint;
begin
  InitWrite; //init it if not initialized
  with WriteInfo do
  begin
    ZStream.next_in := @Buffer;
    ZStream.avail_in := Count;
    while ZStream.avail_in <> 0 do
    begin
      if ZStream.avail_out = 0 then
      begin
        { Flush the buffer to the stream and update progress }
        Over.Write(ZBuffer^, BufSize, HaveWrite, RealCount);
        { reset output buffer }
        ZStream.next_out := ZBuffer;
        ZStream.avail_out := BufSize;
      end;
      err := deflate(ZStream, Z_NO_FLUSH);
      if err <> Z_OK then
        raise Exception.Create(zerror(err));
    end;
    ResultCount := Count;
    Result := True;
  end;
end;

function TmnDeflateStreamProxy.Read(var Buffer; Count: Longint; out ResultCount, RealCount: Longint): Boolean;
var
  err: Smallint;
  HaveRead: Longint;
begin
  InitRead; //init it if not initialized
  with ReadInfo do
  begin
    ZStream.next_out := @buffer;
    ZStream.avail_out := Count;
    while ZStream.avail_out <> 0 do
    begin
      if ZStream.avail_in = 0 then
      begin
        {Refill the buffer.}
        ZStream.next_in := ZBuffer;
        Over.Read(Zbuffer^, BufSize, HaveRead, RealCount);
        ZStream.avail_in := HaveRead;
      end;
      err := inflate(ZStream, Z_NO_FLUSH);
      if err = Z_STREAM_END then
        break;
      if err <> Z_OK then
        raise Edecompressionerror.Create(zerror(err));
    end;
    ResultCount := Count - ZStream.avail_out;
  end;
  Result := True;
end;

procedure TmnDeflateStreamProxy.CloseWrite;
begin
  InternalCloseWrite;
  inherited;
end;

procedure TmnDeflateStreamProxy.CloseRead;
begin
  InternalCloseRead;
  inherited CloseRead;
end;

procedure TmnDeflateStreamProxy.InternalCloseWrite;
var
  err: Smallint;
  Written, R: Longint;
begin
  with WriteInfo do
    if ZBuffer <> nil then
    begin
      {Compress remaining data still in internal zlib data buffers.}
      repeat
        if ZStream.avail_out = 0 then
        begin
          { Flush the buffer to the stream and update progress }
          Over.Write(ZBuffer^, BufSize, Written, R);
          { reset output buffer }
          ZStream.next_out := ZBuffer;
          ZStream.avail_out := BufSize;
        end;
        err := deflate(ZStream, Z_FINISH);
        if err = Z_STREAM_END then
          break;
        if (err <> Z_OK) then
          raise Exception.Create(zerror(err));
      until False;

      if ZStream.avail_out < BufSize then
      begin
        Over.Write(ZBuffer^, BufSize - ZStream.avail_out, Written, R);
      end;

      deflateEnd(ZStream);
      FreeMem(ZBuffer);
      ZBuffer := nil;
    end;
end;

procedure TmnDeflateStreamProxy.InternalCloseRead;
begin
  with ReadInfo do
    if ZBuffer <> nil then
    begin
      InflateEnd(ZStream);
      FreeMem(ZBuffer);
      ZBuffer := nil;
    end;
end;

procedure TmnDeflateStreamProxy.InitWrite;
var
  err: Smallint;
  l: Smallint;
  WindowBits: Integer;
begin
  with WriteInfo do
    if ZBuffer = nil then
    begin
      GetMem(ZBuffer, BufSize);

      ZStream.next_out := ZBuffer;
      ZStream.avail_out := BufSize;

      case FLevel of
        clnone:
          l := Z_NO_COMPRESSION;
        clfastest:
          l := Z_BEST_SPEED;
        cldefault:
          l := Z_DEFAULT_COMPRESSION;
        clmax:
          l := Z_BEST_COMPRESSION;
      end;

      WindowBits := MAX_WBITS;
      if FGZip then
        WindowBits := WindowBits + 16;
      err := deflateInit2(ZStream, l, Z_DEFLATED, WindowBits, DEF_MEM_LEVEL, Z_DEFAULT_STRATEGY);
      if err <> Z_OK then
        raise Exception.Create(zerror(err));
    end;
end;

procedure TmnDeflateStreamProxy.InitRead;
var
  err: Smallint;
  WindowBits: Integer;
begin
  with ReadInfo do
    if ZBuffer = nil then
    begin
      GetMem(ZBuffer, BufSize);

      ZStream.next_in := ZBuffer;
      ZStream.avail_in := 0;

      WindowBits := MAX_WBITS;
      if FGZip then
        WindowBits := WindowBits + 16;
      err := inflateInit2(ZStream, WindowBits);
      if err <> Z_OK then
        raise Exception.Create(zerror(err));
    end;
end;

constructor TmnDeflateStreamProxy.Create(Level: TCompressionlevel; GZip: Boolean);
begin
  inherited Create;
  FLevel := Level;
  FGZip := GZip;
end;

destructor TmnDeflateStreamProxy.Destroy;
begin
  InternalCloseWrite;
  InternalCloseRead;
  inherited Destroy;
end;

end.
