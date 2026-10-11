unit uGameStateManager;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, Generics.Collections, uGenericsModels,
  uSQLiteManager, uThreatAnomalyGenerator;

type
  TGameStatus = (gsMainMenu, gsActive, gsPaused, gsGameOver, gsCaseSolved);

  { Event Handler untuk infeksi baru }
  TInfectionEvent = procedure(Sender: TObject; ANewNode: TProcessNode) of object;

  { TGameStateManager: The core engine coordinating the simulation,
    tracking the active process tree, player progress, and win/loss conditions. }
  TGameStateManager = class
  private
    FStatus: TGameStatus;
    FExfiltrationProgress: Single;
    FDifficultyLevel: Integer;

    { Diubah menjadi Public (Property Read) agar bisa diakses jika diperlukan UI }
    FActiveThreatsCount: Integer;

    { Timer internal penyebaran infeksi }
    FInfectionTimer: Single;

    FProcessDict: TProcessDictionary;
    FFoundIoCs: TIoCList;
    FMetricsDB: TSQLiteManager;

    FOnNewInfection: TInfectionEvent;

    procedure InitializeBaseSystemProcesses;
  public
    constructor Create;
    destructor Destroy; override;

    procedure StartNewCase(ADifficulty: Integer);
    procedure EndCase(ASuccess: Boolean);

    { Driven by the Main UI Timer to progress the simulation (decay & exfiltration) }
    procedure UpdateTick(ADeltaTimeSec: Single);

    procedure RegisterFoundIoC(AIoC: TThreatIoC);

    { Active Mitigation: Terminates a process. Returns True if successful, False if BSOD/Failed }
    function TerminateProcess(APID: Cardinal; out AMessage: String): Boolean;

    property Status: TGameStatus read FStatus;
    property ExfiltrationProgress: Single read FExfiltrationProgress;
    property Processes: TProcessDictionary read FProcessDict;
    property IoCs: TIoCList read FFoundIoCs;
    property ActiveThreatsCount: Integer read FActiveThreatsCount;

    { Event untuk dihubungkan dengan UI MainForm }
    property OnNewInfection: TInfectionEvent read FOnNewInfection write FOnNewInfection;
  end;

implementation

{ TGameStateManager }

constructor TGameStateManager.Create;
var
  DBPath: String;
begin
  FStatus := gsMainMenu;
  FExfiltrationProgress := 0.0;
  FDifficultyLevel := 1;
  FActiveThreatsCount := 0;
  FInfectionTimer := 0.0;

  { Initialize Data Structures }
  FProcessDict := TProcessDictionary.Create([doOwnsValues]);
  FFoundIoCs := TIoCList.Create(True);

  { Setup Persistent Physical Database }
  FMetricsDB := TSQLiteManager.Create;

  { Mendapatkan path absolut: mundur 1 direktori dari bin\ ke root, lalu masuk ke assets\db\ }
  DBPath := ExpandFileName(ExtractFilePath(ParamStr(0)) + '..\assets\db\cyberforensic.db');

  if FMetricsDB.Connect(DBPath) then
  begin
    { Buat tabel SimLogs jika belum ada di database fisik }
    FMetricsDB.ExecuteDirect(
      'CREATE TABLE IF NOT EXISTS SimLogs (' +
      'LogID INTEGER PRIMARY KEY AUTOINCREMENT, ' +
      'Time TEXT NOT NULL, ' +
      'EventType TEXT NOT NULL, ' +
      'Description TEXT NOT NULL);'
    );
  end;
end;

destructor TGameStateManager.Destroy;
begin
  FMetricsDB.Free;
  FFoundIoCs.Free;
  FProcessDict.Free;
  inherited Destroy;
end;

procedure TGameStateManager.InitializeBaseSystemProcesses;
var
  SysNode, SmssNode, CsrssNode: TProcessNode;
begin
  FProcessDict.Clear;

  { Seed legitimate base OS processes }
  SysNode := TProcessNode.Create(4, 0, 'System', 'SYSTEM');
  FProcessDict.Add(SysNode.PID, SysNode);

  SmssNode := TProcessNode.Create(368, 4, 'smss.exe', 'SYSTEM');
  FProcessDict.Add(SmssNode.PID, SmssNode);

  CsrssNode := TProcessNode.Create(544, 368, 'csrss.exe', 'SYSTEM');
  FProcessDict.Add(CsrssNode.PID, CsrssNode);

  { Link parent-child relationships visually }
  SysNode.AddChild(SmssNode);
  SmssNode.AddChild(CsrssNode);
end;

procedure TGameStateManager.StartNewCase(ADifficulty: Integer);
begin
  FDifficultyLevel := ADifficulty;
  FExfiltrationProgress := 0.0;
  FInfectionTimer := 0.0;
  FFoundIoCs.Clear;

  { 1. Setup normal OS environment }
  InitializeBaseSystemProcesses;

  { 2. Inject procedural anomalies based on difficulty }
  TThreatGenerator.GenerateProcessAnomalies(FProcessDict, FDifficultyLevel);

  { Hitung jumlah ancaman awal berdasarkan tingkat kesulitan untuk baseline }
  FActiveThreatsCount := 3;

  FMetricsDB.ExecuteDirect('INSERT INTO SimLogs (Time, EventType, Description) ' +
                           'VALUES (datetime(''now''), ''START'', ''Case Initialized'');');

  FStatus := gsActive;
end;

procedure TGameStateManager.EndCase(ASuccess: Boolean);
begin
  if ASuccess then
    FStatus := gsCaseSolved
  else
    FStatus := gsGameOver;
end;

procedure TGameStateManager.UpdateTick(ADeltaTimeSec: Single);
var
  ExfilRate: Single;
  NewMalware: TProcessNode;
begin
  if FStatus <> gsActive then Exit;

  { QA FIX: Laju exfiltrasi diturunkan (0.2) agar pemain memiliki waktu ~6-8 menit }
  ExfilRate := 0.2 * (FActiveThreatsCount / 3.0) * FDifficultyLevel * ADeltaTimeSec;

  if ExfilRate < 0.1 then ExfilRate := 0.1;

  FExfiltrationProgress := FExfiltrationProgress + ExfilRate;

  if FExfiltrationProgress >= 100.0 then
  begin
    FExfiltrationProgress := 100.0;
    EndCase(False); { Game Over: Threat Actor successfully exfiltrated data }
    Exit;
  end;

  { --- LOGIKA DYNAMIC PROCESS MIGRATION --- }
  FInfectionTimer := FInfectionTimer + ADeltaTimeSec;

  { QA FIX: Coba menyebarkan infeksi setiap ~15-20 detik sekali, HANYA jika ancaman aktif < 8 }
  if (FInfectionTimer > (15.0 + Random(5))) and (FActiveThreatsCount < 8) then
  begin
    FInfectionTimer := 0.0;

    if TThreatGenerator.TrySpreadInfection(FProcessDict, NewMalware) then
    begin
      Inc(FActiveThreatsCount);

      if Assigned(FOnNewInfection) then
        FOnNewInfection(Self, NewMalware);
    end;
  end;
end;

procedure TGameStateManager.RegisterFoundIoC(AIoC: TThreatIoC);
begin
  if Assigned(AIoC) then
  begin
    FFoundIoCs.Add(AIoC);

    FMetricsDB.ExecuteDirect(Format(
      'INSERT INTO SimLogs (Time, EventType, Description) VALUES (datetime(''now''), ''IOC_FOUND'', ''%s'');',
      [AIoC.Value]
    ));

    { Pengumpulan IoC kini tidak lagi langsung menang. Ini digunakan untuk skoring
      atau pengurangan persentase exfiltrasi (sebagai bonus) }
    FExfiltrationProgress := FExfiltrationProgress - 5.0;
    if FExfiltrationProgress < 0 then FExfiltrationProgress := 0;
  end;
end;

{ ACTIVE MITIGATION FUNCTION }
function TGameStateManager.TerminateProcess(APID: Cardinal; out AMessage: String): Boolean;
var
  TargetNode: TProcessNode;
begin
  Result := False;

  if FStatus <> gsActive then
  begin
    AMessage := 'Error: Cannot modify system state outside active case.';
    Exit;
  end;

  if not FProcessDict.TryGetValue(APID, TargetNode) then
  begin
    AMessage := Format('Error: Process with PID %d not found in memory.', [APID]);
    Exit;
  end;

  if TargetNode.IsTerminated then
  begin
    AMessage := Format('Error: Process %d is already terminated.', [APID]);
    Exit;
  end;

  if TargetNode.ThreatLevel = tlSafe then
  begin
    { CRITICAL FAILURE - BSOD }
    TargetNode.IsTerminated := True;
    AMessage := Format('CRITICAL ERROR: Terminated critical system process "%s". System crashing...', [TargetNode.ProcessName]);
    FExfiltrationProgress := 100.0;
    EndCase(False);
    Result := False;
  end
  else
  begin
    { SUCCESSFUL MITIGATION }
    TargetNode.IsTerminated := True;
    Dec(FActiveThreatsCount);
    if FActiveThreatsCount < 0 then FActiveThreatsCount := 0;

    { QA FIX: Jika yang dibunuh adalah Root Infector, berikan bonus waktu lebih besar (25%) }
    if TargetNode.IsInfector then
      FExfiltrationProgress := FExfiltrationProgress - 25.0
    else
      FExfiltrationProgress := FExfiltrationProgress - 10.0;

    if FExfiltrationProgress < 0 then FExfiltrationProgress := 0;

    AMessage := Format('SUCCESS: Malicious process "%s" (PID: %d) terminated.', [TargetNode.ProcessName, APID]);

    FMetricsDB.ExecuteDirect(Format(
      'INSERT INTO SimLogs (Time, EventType, Description) VALUES (datetime(''now''), ''MITIGATION'', ''Terminated %s'');',
      [TargetNode.ProcessName]
    ));

    { QA FIX: Syarat Kemenangan yang Sebenarnya -> SEMUA ANCAMAN DIMUSNAHKAN }
    if FActiveThreatsCount = 0 then
    begin
      EndCase(True);
    end;

    Result := True;
  end;
end;

end.
