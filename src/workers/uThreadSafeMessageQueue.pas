unit uThreadSafeMessageQueue;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, syncobjs, Generics.Collections;

type
  { Generic Thread-Safe Queue for passing data between threads }
  generic TThreadSafeQueue<T> = class
  private
    FQueue: specialize TQueue<T>;
    FLock: TCriticalSection;
  public
    constructor Create;
    destructor Destroy; override;

    procedure Enqueue(const AItem: T);
    function Dequeue(out AItem: T): Boolean;
    function Count: Integer;
    procedure Clear;
  end;

  { Defines the type of message sent from background workers to the UI thread }
  TWorkerAction = (waUpdateProgress, waLogMessage, waHexScanResult, waIoCFound, waError);

  { Standardized Message Payload }
  TWorkerMessage = record
    Action: TWorkerAction;
    Progress: Integer;
    TextPayload: String;
    MemoryOffset: QWord;
    DataSize: Integer;
  end;

  { Concrete implementation for the game's message queue }
  TGameMessageQueue = specialize TThreadSafeQueue<TWorkerMessage>;

implementation

{ TThreadSafeQueue }

constructor TThreadSafeQueue.Create;
begin
  FQueue := specialize TQueue<T>.Create;
  FLock := TCriticalSection.Create;
end;

destructor TThreadSafeQueue.Destroy;
begin
  Clear;
  FLock.Free;
  FQueue.Free;
  inherited Destroy;
end;

procedure TThreadSafeQueue.Enqueue(const AItem: T);
begin
  FLock.Acquire;
  try
    FQueue.Enqueue(AItem);
  finally
    FLock.Release;
  end;
end;

function TThreadSafeQueue.Dequeue(out AItem: T): Boolean;
begin
  FLock.Acquire;
  try
    if FQueue.Count > 0 then
    begin
      AItem := FQueue.Dequeue;
      Result := True;
    end
    else
      Result := False;
  finally
    FLock.Release;
  end;
end;

function TThreadSafeQueue.Count: Integer;
begin
  FLock.Acquire;
  try
    Result := FQueue.Count;
  finally
    FLock.Release;
  end;
end;

procedure TThreadSafeQueue.Clear;
begin
  FLock.Acquire;
  try
    FQueue.Clear;
  finally
    FLock.Release;
  end;
end;

end.

