unit uThreatAnomalyGenerator;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, Math, uGenericsModels, Generics.Collections;

type
  TAnomalyType = (atOrphanedProcess, atReflectiveDLL, atHighEntropyPayload, atHiddenSocket);

  { TThreatGenerator: Procedurally generates anomalies in the process tree and memory
    to ensure each gameplay session is unique and cannot be memorized by players. }
  TThreatGenerator = class
  private
    class var FSpoofedNames: array[0..4] of String;
    class var FC2IPs: array[0..3] of String;
  public
    class constructor Create;

    { Injects anomalous processes into an existing process dictionary (simulating Process Hollowing / Spoofing) }
    class procedure GenerateProcessAnomalies(AProcessDict: TProcessDictionary; ADifficultyLevel: Integer);

    { Simulates injecting encrypted shellcode or hidden data into a memory region, returning an IoC }
    class function InjectMaliciousPayload(AMemoryRegion: TMemoryRegion; out AIoC: TThreatIoC): Boolean;

    { Fitur Baru: Menyebarkan infeksi (Spawning anak proses jahat) jika Root Infector masih hidup }
    class function TrySpreadInfection(AProcessDict: TProcessDictionary; out ANewMalware: TProcessNode): Boolean;
  end;

implementation

{ TThreatGenerator }

class constructor TThreatGenerator.Create;
begin
  Randomize;
  { Common system processes often targeted by malware for disguise }
  FSpoofedNames[0] := 'svchost.exe';
  FSpoofedNames[1] := 'lsass.exe';
  FSpoofedNames[2] := 'explorer.exe';
  FSpoofedNames[3] := 'winlogon.exe';
  FSpoofedNames[4] := 'csrss.exe';

  { Mock Command & Control (C2) IP Addresses for extraction }
  FC2IPs[0] := '192.168.10.55';
  FC2IPs[1] := '45.33.32.156';
  FC2IPs[2] := '185.199.108.153';
  FC2IPs[3] := '104.21.44.200';
end;

class procedure TThreatGenerator.GenerateProcessAnomalies(AProcessDict: TProcessDictionary; ADifficultyLevel: Integer);
var
  I, TargetCount: Integer;
  MaliciousPID: Cardinal;
  FakeParentPID: Cardinal;
  NewNode: TProcessNode;
  TargetName: String;
  ValidParents: array[0..2] of Cardinal;
begin
  if not Assigned(AProcessDict) then Exit;

  { Daftar PID dari proses sistem sah yang dibuat di uGameStateManager }
  ValidParents[0] := 4;   { System }
  ValidParents[1] := 368; { smss.exe }
  ValidParents[2] := 544; { csrss.exe }

  { Pastikan minimal ada 3 ancaman agar pemain bisa memenangkan permainan (3 IoC) }
  TargetCount := Max(3, ADifficultyLevel + 2);

  for I := 1 to TargetCount do
  begin
    MaliciousPID := Cardinal(RandomRange(4000, 9999));
    TargetName := FSpoofedNames[Random(Length(FSpoofedNames))];

    { Taktik Malware: 50% menyamar jadi proses turunan sah, 50% orphaned (induk palsu) }
    if Random(2) = 0 then
      FakeParentPID := Cardinal(RandomRange(100, 999)) { Induk acak (Orphaned) }
    else
      FakeParentPID := ValidParents[Random(Length(ValidParents))]; { Menempel di sistem (Spoofing) }

    NewNode := TProcessNode.Create(MaliciousPID, FakeParentPID, TargetName, 'SYSTEM');

    { Acak tingkat ancaman }
    case Random(3) of
      0: NewNode.ThreatLevel := tlSuspicious;
      1: NewNode.ThreatLevel := tlMalicious;
      2: NewNode.ThreatLevel := tlCritical;
    end;

    { Set status orphaned berdasarkan parent yang dipilih }
    NewNode.IsOrphaned := (FakeParentPID <> 4) and (FakeParentPID <> 368) and (FakeParentPID <> 544);

    { DYNAMIC MIGRATION: Jadikan malware PERTAMA yang terbuat sebagai Root Infector (Induk) }
    if I = 1 then
      NewNode.IsInfector := True;

    { Insert into the simulation state }
    AProcessDict.Add(MaliciousPID, NewNode);
  end;
end;

class function TThreatGenerator.TrySpreadInfection(AProcessDict: TProcessDictionary; out ANewMalware: TProcessNode): Boolean;
var
  Node, InfectorNode: TProcessNode;
  Infectors: specialize TList<TProcessNode>;
  MaliciousPID: Cardinal;
  NewNode: TProcessNode;
  TargetNames: array[0..3] of String;
begin
  Result := False;
  ANewMalware := nil;
  if not Assigned(AProcessDict) then Exit;

  Infectors := specialize TList<TProcessNode>.Create;
  try
    { Cari semua Infector (Root) yang masih hidup }
    for Node in AProcessDict.Values do
    begin
      if (Node.IsInfector) and (not Node.IsTerminated) then
        Infectors.Add(Node);
    end;

    { Jika semua infector sudah mati di-kill pemain, penyebaran berhenti (Aman!) }
    if Infectors.Count = 0 then Exit;

    { Pilih salah satu root infector secara acak sebagai parent dari malware baru }
    InfectorNode := Infectors[Random(Infectors.Count)];

    { Malware baru yang akan di-spawn sebagai proses siluman }
    TargetNames[0] := 'powershell.exe';
    TargetNames[1] := 'cmd.exe';
    TargetNames[2] := 'wscript.exe';
    TargetNames[3] := 'rundll32.exe';

    MaliciousPID := Cardinal(RandomRange(10000, 65000));

    NewNode := TProcessNode.Create(MaliciousPID, InfectorNode.PID, TargetNames[Random(4)], 'SYSTEM');

    NewNode.ThreatLevel := tlMalicious;
    NewNode.IsNewlyInfected := True; { Tanda untuk memicu UI (flash/jumpscare) }
    NewNode.IsOrphaned := False;

    { Tambahkan ke memori simulasi }
    AProcessDict.Add(MaliciousPID, NewNode);

    ANewMalware := NewNode;
    Result := True;
  finally
    Infectors.Free;
  end;
end;

class function TThreatGenerator.InjectMaliciousPayload(AMemoryRegion: TMemoryRegion; out AIoC: TThreatIoC): Boolean;
var
  IoCValue: String;
  Offset: QWord;
begin
  Result := False;
  AIoC := nil;
  if not Assigned(AMemoryRegion) then Exit;

  { Simulate High Entropy characteristic of encrypted/packed malware data }
  AMemoryRegion.Entropy := 7.5 + (Random * 0.49); { Entropy range: 7.50 to 7.99 }

  { RWX (Read-Write-Execute) protection is a primary forensic indicator for memory injection }
  AMemoryRegion.Protection := mpReadWriteExecute;
  AMemoryRegion.IsCorrupted := True;

  { Embed an Indicator of Compromise at a random offset within this region }
  IoCValue := FC2IPs[Random(Length(FC2IPs))];

  { Calculate a safe offset inside the region bounds }
  if AMemoryRegion.Size > 100 then
    Offset := AMemoryRegion.BaseAddress + QWord(Random(Int64(AMemoryRegion.Size div 2)))
  else
    Offset := AMemoryRegion.BaseAddress;

  { Catatan: Sesuai struktur constructor yang baru di uGenericsModels }
  AIoC := TThreatIoC.Create('IPv4_C2', IoCValue, 'Hidden C2 Socket Connection', Offset, tlCritical);
  Result := True;
end;

end.
