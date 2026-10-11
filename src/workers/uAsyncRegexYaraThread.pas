unit uAsyncRegexYaraThread;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, Math, RegExpr, uThreadSafeMessageQueue;

const
  SCAN_CHUNK_SIZE = 1048576; { 1MB chunks for optimal regex scanning speed }
  SCAN_OVERLAP    = 1024;    { 1KB overlap to catch patterns crossing chunk boundaries }

type
  TScanType = (stRegex, stYara);

  { TAsyncRegexYaraThread: Background thread for running Regular Expressions and
    YARA rules against large memory dumps without freezing the UI. }
  TAsyncRegexYaraThread = class(TThread)
  private
    FFileName: String;
    FQueue: TGameMessageQueue;
    FPattern: String;
    FScanType: TScanType;

    procedure PostMessageToUI(AAction: TWorkerAction; AProgress: Integer; const AText: String; AOffset: QWord; ASize: Integer);
  protected
    procedure Execute; override;
  public
    constructor Create(const AFileName: String; AQueue: TGameMessageQueue; const APattern: String; AScanType: TScanType);
  end;

implementation

{ TAsyncRegexYaraThread }

constructor TAsyncRegexYaraThread.Create(const AFileName: String; AQueue: TGameMessageQueue; const APattern: String; AScanType: TScanType);
begin
  inherited Create(True);
  FreeOnTerminate := True;
  FFileName := AFileName;
  FQueue := AQueue;
  FPattern := APattern;
  FScanType := AScanType;
end;

procedure TAsyncRegexYaraThread.PostMessageToUI(AAction: TWorkerAction; AProgress: Integer; const AText: String; AOffset: QWord; ASize: Integer);
var
  Msg: TWorkerMessage;
begin
  if not Assigned(FQueue) then Exit;

  Msg.Action := AAction;
  Msg.Progress := AProgress;
  Msg.TextPayload := AText;
  Msg.MemoryOffset := AOffset;
  Msg.DataSize := ASize;

  FQueue.Enqueue(Msg);
end;

procedure TAsyncRegexYaraThread.Execute;
var
  FStream: TFileStream;
  Buffer: PByte;
  ChunkStr: String;
  Regex: TRegExpr;
  BytesRead, FileSize, CurrentPos, LastProgress, CurrentProgress, AbsoluteOffset: Int64;
begin
  if not FileExists(FFileName) then
  begin
    PostMessageToUI(waError, 0, 'Target file not found: ' + FFileName, 0, 0);
    Exit;
  end;

  PostMessageToUI(waLogMessage, 0, 'Initializing Pattern Matcher...', 0, 0);

  GetMem(Buffer, SCAN_CHUNK_SIZE);
  Regex := TRegExpr.Create(FPattern);
  try
    { fmShareDenyNone allows other components (like HexViewer) to read the same file }
    FStream := TFileStream.Create(FFileName, fmOpenRead or fmShareDenyNone);
    try
      FileSize := FStream.Size;
      CurrentPos := 0;
      LastProgress := -1;

      while (CurrentPos < FileSize) and not Terminated do
      begin
        BytesRead := Min(SCAN_CHUNK_SIZE, FileSize - CurrentPos);
        FStream.Position := CurrentPos;
        FStream.ReadBuffer(Buffer^, BytesRead);

        { Convert raw byte buffer to string for TRegExpr processing }
        SetString(ChunkStr, PChar(Buffer), BytesRead);

        if Regex.Exec(ChunkStr) then
        begin
          repeat
            { Calculate the actual offset in the file }
            AbsoluteOffset := CurrentPos + Regex.MatchPos[0] - 1;

            PostMessageToUI(waIoCFound, -1,
              Format('[MATCH] %s', [Regex.Match[0]]),
              AbsoluteOffset,
              Regex.MatchLen[0]);

          until not Regex.ExecNext or Terminated;
        end;

        { Advance position, rewinding by overlap amount if not at EOF
          to ensure patterns cut between chunks are not missed }
        if (CurrentPos + BytesRead) < FileSize then
          CurrentPos := CurrentPos + BytesRead - SCAN_OVERLAP
        else
          CurrentPos := CurrentPos + BytesRead;

        { Calculate and emit progress }
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
    Regex.Free;
    FreeMem(Buffer, SCAN_CHUNK_SIZE);

    if Terminated then
      PostMessageToUI(waLogMessage, LastProgress, 'Scan Aborted by User', 0, 0)
    else
      PostMessageToUI(waLogMessage, 100, 'Scan Completed', 0, 0);
  end;
end;

end.

