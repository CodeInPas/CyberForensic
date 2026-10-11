unit uAsyncHexScannerThread;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, Math, uThreadSafeMessageQueue, uEntropyCalculator;

const
  SCAN_CHUNK_SIZE = 65536; { 64KB chunks for optimal disk I/O and cache usage }
  ENTROPY_THRESHOLD = 7.5; { Threshold for identifying encrypted/packed data }

type
  { TAsyncHexScannerThread: Background thread for heavy memory/file scanning
    without blocking the Main UI thread. }
  TAsyncHexScannerThread = class(TThread)
  private
    FFileName: String;
    FQueue: TGameMessageQueue;
    FSearchPattern: TBytes;
    FScanEntropy: Boolean;

    procedure PostMessageToUI(AAction: TWorkerAction; AProgress: Integer; const AText: String; AOffset: QWord; ASize: Integer);
    function FastPatternMatch(ABuffer: PByte; ABufferSize: Integer; const APattern: TBytes): Integer;
  protected
    procedure Execute; override;
  public
    constructor Create(const AFileName: String; AQueue: TGameMessageQueue; const APattern: TBytes; AScanHighEntropy: Boolean);
  end;

implementation

{ TAsyncHexScannerThread }

constructor TAsyncHexScannerThread.Create(const AFileName: String; AQueue: TGameMessageQueue; const APattern: TBytes; AScanHighEntropy: Boolean);
begin
  inherited Create(True); { Create suspended so properties can be set if needed before Start }
  FreeOnTerminate := True;
  FFileName := AFileName;
  FQueue := AQueue;
  FSearchPattern := APattern;
  FScanEntropy := AScanHighEntropy;
end;

procedure TAsyncHexScannerThread.PostMessageToUI(AAction: TWorkerAction; AProgress: Integer; const AText: String; AOffset: QWord; ASize: Integer);
var
  Msg: TWorkerMessage;
begin
  if not Assigned(FQueue) then Exit;

  Msg.Action := AAction;
  Msg.Progress := AProgress;
  Msg.TextPayload := AText;
  Msg.MemoryOffset := AOffset;
  Msg.DataSize := ASize;

  { Enqueue message safely to be processed by the UI thread via a Timer or idle event }
  FQueue.Enqueue(Msg);
end;

function TAsyncHexScannerThread.FastPatternMatch(ABuffer: PByte; ABufferSize: Integer; const APattern: TBytes): Integer;
var
  I, J, PatLen: Integer;
  Match: Boolean;
begin
  Result := -1;
  PatLen := Length(APattern);
  if (PatLen = 0) or (ABufferSize < PatLen) then Exit;

  { Efficient naive byte search; sufficient for MVP chunk scanning }
  for I := 0 to ABufferSize - PatLen do
  begin
    if ABuffer[I] = APattern[0] then
    begin
      Match := True;
      for J := 1 to PatLen - 1 do
      begin
        if ABuffer[I + J] <> APattern[J] then
        begin
          Match := False;
          Break;
        end;
      end;
      if Match then
      begin
        Result := I;
        Exit;
      end;
    end;
  end;
end;

procedure TAsyncHexScannerThread.Execute;
var
  FStream: TFileStream;
  Buffer: PByte;
  BytesRead, FileSize, CurrentPos, LastProgress, CurrentProgress: Int64;
  MatchOffset: Integer;
  ChunkEntropy: Single;
begin
  if not FileExists(FFileName) then
  begin
    PostMessageToUI(waError, 0, 'Memory dump file not found: ' + FFileName, 0, 0);
    Exit;
  end;

  PostMessageToUI(waLogMessage, 0, 'Starting Async Hex Scan...', 0, 0);

  { Allocate contiguous memory for the chunk buffer }
  GetMem(Buffer, SCAN_CHUNK_SIZE);
  try
    { fmShareDenyNone allows the Main UI's MemoryVirtualizer to read the file concurrently }
    FStream := TFileStream.Create(FFileName, fmOpenRead or fmShareDenyNone);
    try
      FileSize := FStream.Size;
      CurrentPos := 0;
      LastProgress := -1;

      while (CurrentPos < FileSize) and not Terminated do
      begin
        BytesRead := Min(SCAN_CHUNK_SIZE, FileSize - CurrentPos);
        FStream.ReadBuffer(Buffer^, BytesRead);

        { 1. Pattern Matching }
        if Length(FSearchPattern) > 0 then
        begin
          MatchOffset := FastPatternMatch(Buffer, BytesRead, FSearchPattern);
          if MatchOffset >= 0 then
            PostMessageToUI(waHexScanResult, -1, 'Byte Pattern Matched', CurrentPos + MatchOffset, Length(FSearchPattern));
        end;

        { 2. Entropy Analysis }
        if FScanEntropy then
        begin
          ChunkEntropy := CalculateMemoryEntropy(Buffer, BytesRead);
          if ChunkEntropy >= ENTROPY_THRESHOLD then
            PostMessageToUI(waIoCFound, -1, Format('High Entropy Block Detected (%.2f)', [ChunkEntropy]), CurrentPos, BytesRead);
        end;

        CurrentPos := CurrentPos + BytesRead;

        { Update Progress conservatively to avoid flooding the message queue }
        if FileSize > 0 then
          CurrentProgress := (CurrentPos * 100) div FileSize
        else
          CurrentProgress := 100;

        if CurrentProgress <> LastProgress then
        begin
          PostMessageToUI(waUpdateProgress, CurrentProgress, '', 0, 0);
          LastProgress := CurrentProgress;
        end;
      end;

    finally
      FStream.Free;
    end;
  finally
    FreeMem(Buffer, SCAN_CHUNK_SIZE);

    if Terminated then
      PostMessageToUI(waLogMessage, LastProgress, 'Scan Aborted', 0, 0)
    else
      PostMessageToUI(waLogMessage, 100, 'Scan Completed', 0, 0);
  end;
end;

end.

