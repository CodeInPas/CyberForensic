unit uMemoryStreamVirtualizer;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils;

type
  { TMemoryVirtualizer: Handles large memory dump files via on-demand paging
    (Windowing) to prevent Out of Memory (OOM) errors. }
  TMemoryVirtualizer = class
  private
    FStream: TFileStream;
    FFileSize: Int64;
    FBuffer: PByte;
    FBufferSize: Integer;
    procedure ReallocBuffer(ANewSize: Integer);
  public
    constructor Create(const AFileName: String);
    destructor Destroy; override;

    { Reads a chunk of data directly from disk into an internal buffer.
      Extremely fast for hex viewers as it only loads what is visible. }
    function ReadChunk(AOffset: Int64; ASize: Integer; out BytesRead: Integer): PByte;

    property FileSize: Int64 read FFileSize;
  end;

implementation

{ TMemoryVirtualizer }

constructor TMemoryVirtualizer.Create(const AFileName: String);
begin
  { Open file in read-only mode, allowing other processes to read it }
  FStream := TFileStream.Create(AFileName, fmOpenRead or fmShareDenyWrite);
  FFileSize := FStream.Size;
  FBuffer := nil;
  FBufferSize := 0;
end;

destructor TMemoryVirtualizer.Destroy;
begin
  if Assigned(FBuffer) then
    FreeMem(FBuffer);
  FStream.Free;
  inherited Destroy;
end;

procedure TMemoryVirtualizer.ReallocBuffer(ANewSize: Integer);
begin
  { Only reallocate if the requested size is different to avoid overhead }
  if FBufferSize <> ANewSize then
  begin
    if Assigned(FBuffer) then
      FreeMem(FBuffer);
    GetMem(FBuffer, ANewSize);
    FBufferSize := ANewSize;
  end;
end;

function TMemoryVirtualizer.ReadChunk(AOffset: Int64; ASize: Integer; out BytesRead: Integer): PByte;
begin
  Result := nil;
  BytesRead := 0;

  if not Assigned(FStream) or (AOffset < 0) or (AOffset >= FFileSize) or (ASize <= 0) then
    Exit;

  ReallocBuffer(ASize);

  FStream.Position := AOffset;

  { Prevent reading past the End of File (EOF) }
  if (AOffset + ASize) > FFileSize then
    BytesRead := FFileSize - AOffset
  else
    BytesRead := ASize;

  { Direct memory write to pointer for maximum efficiency }
  FStream.ReadBuffer(FBuffer^, BytesRead);

  Result := FBuffer;
end;

end.

