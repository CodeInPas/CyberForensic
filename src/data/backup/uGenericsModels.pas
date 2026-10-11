unit uGenericsModels;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, Generics.Collections;

type
  TThreatLevel = (tlSafe, tlSuspicious, tlMalicious, tlCritical);
  TMemoryProtection = (mpRead, mpWrite, mpExecute, mpReadWrite, mpReadWriteExecute);

  { TMemoryRegion: Represents a chunk of virtual memory }
  TMemoryRegion = class
  public
    BaseAddress: QWord;
    Size: QWord;
    Protection: TMemoryProtection;
    Entropy: Single;
    IsCorrupted: Boolean;
    constructor Create(ABaseAddress, ASize: QWord; AProtection: TMemoryProtection);
  end;

  { TProcessNode: Represents an OS process in the Process Tree }
  TProcessNode = class
  public
    PID: Cardinal;
    ParentPID: Cardinal;
    ProcessName: String;
    UserName: String;
    CreationTime: TDateTime;
    ThreatLevel: TThreatLevel;
    IsOrphaned: Boolean;

    { Status untuk Active Mitigation: Apakah proses ini sudah di-kill oleh pemain? }
    IsTerminated: Boolean;

    { Navigation & Data Storage }
    MemoryRegions: specialize TObjectList<TMemoryRegion>;
    Children: specialize TList<TProcessNode>;

    constructor Create(APID, AParentPID: Cardinal; AName, AUser: String);
    destructor Destroy; override;
    procedure AddChild(AChildNode: TProcessNode);
  end;

  { TThreatIoC: Indicator of Compromise found during investigation }
  TThreatIoC = class
  public
    IoCType: String;   { e.g., 'IP', 'Regex', 'Yara', 'AES_Key' }
    Value: String;     { e.g., '192.168.1.100' }
    Description: String;
    OffsetFound: QWord;
    Severity: TThreatLevel;

    constructor Create(AType, AValue, ADesc: String; AOffset: QWord; ASeverity: TThreatLevel);
  end;

  { Data Collections for the Game Engine }
  TProcessDictionary = class(specialize TObjectDictionary<Cardinal, TProcessNode>);
  TMemoryRegionList = class( specialize TObjectList<TMemoryRegion>);
  TIoCList = class(specialize TObjectList<TThreatIoC>);

implementation

{ TMemoryRegion }

constructor TMemoryRegion.Create(ABaseAddress, ASize: QWord; AProtection: TMemoryProtection);
begin
  BaseAddress := ABaseAddress;
  Size := ASize;
  Protection := AProtection;
  Entropy := 0.0;
  IsCorrupted := False;
end;

{ TProcessNode }

constructor TProcessNode.Create(APID, AParentPID: Cardinal; AName, AUser: String);
begin
  PID := APID;
  ParentPID := AParentPID;
  ProcessName := AName;
  UserName := AUser;
  CreationTime := Now;
  ThreatLevel := tlSafe;
  IsOrphaned := False;
  IsTerminated := False; { Default saat terbuat, proses berjalan }

  { MemoryRegions owns the objects, will free them automatically }
  MemoryRegions := specialize TObjectList<TMemoryRegion>.Create(True);
  { Children list only holds references, does not own the objects }
  Children := specialize TList<TProcessNode>.Create;
end;

destructor TProcessNode.Destroy;
begin
  MemoryRegions.Free;
  Children.Free;
  inherited Destroy;
end;

procedure TProcessNode.AddChild(AChildNode: TProcessNode);
begin
  if Assigned(AChildNode) then
    Children.Add(AChildNode);
end;

{ TThreatIoC }

constructor TThreatIoC.Create(AType, AValue, ADesc: String; AOffset: QWord; ASeverity: TThreatLevel);
begin
  IoCType := AType;
  Value := AValue;
  Description := ADesc;
  OffsetFound := AOffset;
  Severity := ASeverity;
end;

end.
