unit ufrmMain;

{$mode objfpc}{$H+}

interface

uses
  Windows,
  Classes, SysUtils, Forms, Controls, Graphics, Dialogs, ExtCtrls, StdCtrls,
  Buttons, ComCtrls, LCLType, LCLIntf, uColorThemeConstants, uGameStateManager,
  uHexViewerComponent, uProcessGraphComponent, uTerminalEmulator,
  uThreatSpectrumComponent, uGenericsModels;

type
  { TfrmMain }
  TfrmMain = class(TForm)
  published
    cmbYaraMatcher: TComboBox;
    edtRegexEngine: TEdit;
    lblTitle: TLabel;
    lblSectionMeta: TLabel;
    lblSectionThreat: TLabel;
    lblSectionTools: TLabel;
    lblMetaPID: TLabel;
    lblMetaProcess: TLabel;
    lblMetaParent: TLabel;
    lblMetaOffset: TLabel;
    lblThreatDataExfil: TLabel;
    lblThreatDecay: TLabel;
    pnlTopBar: TPanel;
    pnlWorkspace: TPanel;
    pnlControlBoard: TPanel;

    pnlBottomArea: TPanel;

    pnlHexContainer: TPanel;
    pnlProcessContainer: TPanel;
    pnlTerminalContainer: TPanel;
    pnlMetadata: TPanel;
    pnlThreatMonitor: TPanel;
    pnlTools: TPanel;

    { Container baru untuk Grafik Spectrum }
    pnlSpectrumContainer: TPanel;

    shpExfilBarBG: TShape;
    shpExfilBarFG: TShape;

    splTop: TSplitter;
    splLeft: TSplitter;

    tmrGameTick: TTimer;

    procedure FormCreate(Sender: TObject);
    procedure FormDestroy(Sender: TObject);
    procedure tmrGameTickTimer(Sender: TObject);
  private
    FHexViewer: THexViewerComponent;
    FProcessGraph: TProcessGraphComponent;
    FTerminal: TTerminalEmulator;
    FSpectrumChart: TThreatSpectrumComponent; { <--- Instance Spectrum }

    FGameState: TGameStateManager;
    FActiveMemory: array[0..4095] of Byte;
    FSelectedNode: TProcessNode;

    procedure TerminalCommand(Sender: TObject; const ACommand: String);
    procedure UpdateUI;
    procedure ProcessNodeClicked(Sender: TObject; ANode: TProcessNode);

    procedure ScannerKeyDown(Sender: TObject; var Key: Word; Shift: TShiftState);
    procedure YaraRuleSelected(Sender: TObject);
    procedure PerformScan(const AScannerName, APattern: String);

    procedure StartNewCase;
    procedure HandleNewInfection(Sender: TObject; ANewNode: TProcessNode);
  public
  end;

var
  frmMain: TfrmMain;

implementation

{$R *.lfm}

{ TfrmMain }

procedure TfrmMain.FormCreate(Sender: TObject);
begin
  FSelectedNode := nil;

  Self.ShowHint := True;

  pnlProcessContainer.Hint := 'PROCESS TREE: Menampilkan hierarki proses sistem.' + sLineBreak +
                              'Klik pada sebuah proses untuk menganalisis data memorinya.';
  pnlProcessContainer.ShowHint := True;

  pnlHexContainer.Hint := 'HEX VIEWER: Menampilkan cuplikan memori mentah dari proses yang disorot.' + sLineBreak +
                          'Gunakan untuk mencari pola injeksi atau string mencurigakan.';
  pnlHexContainer.ShowHint := True;

  pnlTerminalContainer.Hint := 'TERMINAL FORENSIK: Ketik perintah untuk interaksi sistem.' + sLineBreak +
                               'Contoh: "help", "kill <PID>".';
  pnlTerminalContainer.ShowHint := True;

  shpExfilBarBG.Hint := 'BATAS WAKTU (EXFILTRATION): Jika bar ini penuh, malware berhasil' + sLineBreak +
                        'mencuri data sistem dan Anda KALAH!';
  shpExfilBarBG.ShowHint := True;
  lblThreatDataExfil.Hint := shpExfilBarBG.Hint;
  lblThreatDataExfil.ShowHint := True;

  edtRegexEngine.TextHint := 'Search IP pattern (e.g. 19.11.2.*)...';
  edtRegexEngine.Hint := 'REGEX SCANNER: Gunakan untuk mencari pola spesifik (misal: IP Address C2) di memori.';
  edtRegexEngine.ShowHint := True;
  edtRegexEngine.OnKeyDown := @ScannerKeyDown;

  cmbYaraMatcher.TextHint := 'Select YARA Rule...';
  cmbYaraMatcher.Hint := 'YARA MATCHER: Pilih aturan (rule) untuk mendeteksi signature malware yang sudah diketahui.';
  cmbYaraMatcher.ShowHint := True;
  cmbYaraMatcher.Items.Add('Rule: Detect Reflective Injection');
  cmbYaraMatcher.Items.Add('Rule: Find C2 Beaconing');
  cmbYaraMatcher.Items.Add('Rule: Identify AES Encryption Keys');
  cmbYaraMatcher.OnChange := @YaraRuleSelected;

  FHexViewer := THexViewerComponent.Create(Self);
  FHexViewer.Parent := pnlHexContainer;
  FHexViewer.Align := alClient;

  FProcessGraph := TProcessGraphComponent.Create(Self);
  FProcessGraph.Parent := pnlProcessContainer;
  FProcessGraph.Align := alClient;
  FProcessGraph.OnNodeClick := @ProcessNodeClicked;

  FTerminal := TTerminalEmulator.Create(Self);
  FTerminal.Parent := pnlTerminalContainer;
  FTerminal.Align := alClient;
  FTerminal.OnCommand := @TerminalCommand;

  { Pembuatan Komponen Spektrum Ancaman Baru }
  FSpectrumChart := TThreatSpectrumComponent.Create(Self);
  FSpectrumChart.Parent := pnlSpectrumContainer;
  FSpectrumChart.Align := alClient;
  FSpectrumChart.Hint := 'THREAT SPECTRUM: Menunjukkan distribusi ancaman aktif di memori secara Real-Time.';
  FSpectrumChart.ShowHint := True;

  FGameState := TGameStateManager.Create;
  FGameState.OnNewInfection := @HandleNewInfection;

  StartNewCase;
  tmrGameTick.Interval := 1000;
end;

procedure TfrmMain.FormDestroy(Sender: TObject);
begin
  tmrGameTick.Enabled := False;
  FGameState.Free;
end;

procedure TfrmMain.tmrGameTickTimer(Sender: TObject);
begin
  if FGameState.Status = gsActive then
  begin
    FGameState.UpdateTick(1.0);
    UpdateUI;
  end;
end;

procedure TfrmMain.StartNewCase;
begin
  FGameState.StartNewCase(1);
  FProcessGraph.LoadData(FGameState.Processes);
  FSelectedNode := nil;

  lblMetaPID.Caption := 'PID: N/A';
  lblMetaProcess.Caption := 'Process: Unknown';
  lblMetaParent.Caption := 'Parent: Unknown';
  lblMetaOffset.Caption := 'Memory Offset: 0x00000000';

  FillByte(FActiveMemory, SizeOf(FActiveMemory), 0);
  FHexViewer.LoadBuffer(@FActiveMemory[0], SizeOf(FActiveMemory), 0);

  FTerminal.ClearTerminal;
  FTerminal.Print('======================================', COLOR_TEXT_MUTED);
  FTerminal.Print('CYBER-FORENSIC OS v2.4 initialized.', COLOR_TEXT_PRIMARY);
  FTerminal.Print('New case started. Analyzing memory dump...', COLOR_STAT_WARN);
  FTerminal.Print('Type "help" for available commands.', COLOR_TEXT_MUTED);
  FTerminal.Print('======================================', COLOR_TEXT_MUTED);

  tmrGameTick.Enabled := True;
  UpdateUI;
end;

procedure TfrmMain.HandleNewInfection(Sender: TObject; ANewNode: TProcessNode);
begin
  if not Assigned(ANewNode) then Exit;

  MessageBeep(MB_ICONWARNING);
  FTerminal.Print('*** ALERT: NEW INFECTION DETECTED! ***', COLOR_HEX_DANGER);
  FTerminal.Print(Format('Suspicious process spawned: %s (PID: %d)', [ANewNode.ProcessName, ANewNode.PID]), COLOR_STAT_WARN);

  FProcessGraph.LoadData(FGameState.Processes);
  FProcessGraph.RefreshGraph;

  { Paksa spectrum chart untuk segera menggambar ulang saat ada malware baru }
  FSpectrumChart.UpdateSpectrum(FGameState.Processes);
end;

procedure TfrmMain.ScannerKeyDown(Sender: TObject; var Key: Word; Shift: TShiftState);
begin
  if Key = VK_RETURN then
  begin
    PerformScan('Regex', edtRegexEngine.Text);
    Key := 0;
  end;
end;

procedure TfrmMain.YaraRuleSelected(Sender: TObject);
begin
  if cmbYaraMatcher.ItemIndex >= 0 then
    PerformScan('YARA', cmbYaraMatcher.Text);
end;

procedure TfrmMain.TerminalCommand(Sender: TObject; const ACommand: String);
var
  Cmd, TargetPIDStr, ResultMsg: String;
  TargetPID: Cardinal;
begin
  Cmd := LowerCase(Trim(ACommand));

  if Cmd = 'help' then
    FTerminal.Print('Available commands: pslist, malfind, netscan, kill <PID>, clear, restart')
  else if Cmd = 'clear' then
    FTerminal.ClearTerminal
  else if (Cmd = 'restart') or (Cmd = 'newcase') then
    StartNewCase
  else if (Pos('malfind', Cmd) = 1) or (Pos('netscan', Cmd) = 1) then
    PerformScan('Terminal', Cmd)
  else if Pos('kill ', Cmd) = 1 then
  begin
    TargetPIDStr := Trim(Copy(Cmd, 6, Length(Cmd)));
    TargetPID := StrToIntDef(TargetPIDStr, 0);

    if TargetPID = 0 then
    begin
      FTerminal.Print('Usage error. Format: kill <PID>', COLOR_HEX_DANGER);
      Exit;
    end;

    FTerminal.Print(Format('Executing SIGKILL on PID %d...', [TargetPID]), COLOR_TEXT_MUTED);

    if FGameState.TerminateProcess(TargetPID, ResultMsg) then
    begin
      FTerminal.Print(ResultMsg, clLime);
      MessageBeep(MB_OK);
    end
    else
    begin
      FTerminal.Print(ResultMsg, COLOR_HEX_DANGER);
      MessageBeep(MB_ICONHAND);
    end;

    FProcessGraph.RefreshGraph;

    { Update spektrum agar grafik menyesuaikan status kill terbaru }
    FSpectrumChart.UpdateSpectrum(FGameState.Processes);

    UpdateUI;

    if Assigned(FSelectedNode) and (FSelectedNode.PID = TargetPID) then
      ProcessNodeClicked(Self, FSelectedNode);
  end
  else
    FTerminal.Print('Command not found: ' + Cmd, COLOR_HEX_DANGER);
end;

procedure TfrmMain.PerformScan(const AScannerName, APattern: String);
var
  IoC: TThreatIoC;
  SimulatedOffset: QWord;
begin
  if FGameState.Status <> gsActive then Exit;

  if not Assigned(FSelectedNode) then
  begin
    FTerminal.Print(AScannerName + ' Error: No process selected in tree.', COLOR_HEX_DANGER);
    Exit;
  end;

  FTerminal.Print(Format('Running %s scan on PID %d...', [AScannerName, FSelectedNode.PID]), COLOR_TEXT_MUTED);

  if FSelectedNode.ThreatLevel > tlSafe then
  begin
    SimulatedOffset := FSelectedNode.PID * $10000;

    IoC := TThreatIoC.Create(
      AScannerName, APattern,
      'Detected in ' + FSelectedNode.ProcessName,
      SimulatedOffset, FSelectedNode.ThreatLevel
    );

    FGameState.RegisterFoundIoC(IoC);
    MessageBeep(MB_ICONWARNING);

    FTerminal.Print('>> THREAT DETECTED! IoC Registered.', COLOR_HEX_DANGER);
    FTerminal.Print(Format('Progress: Found %d critical IoCs.', [FGameState.IoCs.Count]), COLOR_STAT_WARN);
  end
  else
  begin
    FTerminal.Print('>> Scan complete: Process is clean.', COLOR_STAT_SAFE);
  end;
end;

procedure TfrmMain.UpdateUI;
var
  ExfilPct: Integer;
begin
  { --- Update Spectrum Chart setiap detik --- }
  if Assigned(FSpectrumChart) then
    FSpectrumChart.UpdateSpectrum(FGameState.Processes);

  if FGameState.Status = gsGameOver then
  begin
    lblThreatDataExfil.Caption := 'SYSTEM COMPROMISED - GAME OVER';
    shpExfilBarFG.Brush.Color := $000000FF;
    shpExfilBarFG.Width := shpExfilBarBG.Width;

    if tmrGameTick.Enabled then
    begin
      MessageBeep(MB_ICONHAND);
      FTerminal.Print('CRITICAL: EXFILTRATION COMPLETE. SYSTEM COMPROMISED.', COLOR_HEX_DANGER);
      FTerminal.Print('Type "restart" to try again.', COLOR_TEXT_MUTED);
      tmrGameTick.Enabled := False;
    end;
    Exit;
  end
  else if FGameState.Status = gsCaseSolved then
  begin
    lblThreatDataExfil.Caption := 'CASE SOLVED - THREAT CONTAINED';
    shpExfilBarFG.Brush.Color := $00E2B75A;

    if tmrGameTick.Enabled then
    begin
      MessageBeep(MB_OK);
      FTerminal.Print('SUCCESS: ALL THREATS CONTAINED. YOU WON!', clLime);
      FTerminal.Print('Type "newcase" for another challenge.', COLOR_TEXT_MUTED);
      tmrGameTick.Enabled := False;
    end;
    Exit;
  end;

  ExfilPct := Trunc(FGameState.ExfiltrationProgress);
  lblThreatDataExfil.Caption := Format('DATA EXFILTRATED: %d%%', [ExfilPct]);

  shpExfilBarFG.Width := Trunc((ExfilPct / 100.0) * shpExfilBarBG.Width);

  if ExfilPct > 80 then
    shpExfilBarFG.Brush.Color := $002A2AFF
  else if ExfilPct > 50 then
    shpExfilBarFG.Brush.Color := $0000A5FF
  else
    shpExfilBarFG.Brush.Color := $00E2A13D;
end;

procedure TfrmMain.ProcessNodeClicked(Sender: TObject; ANode: TProcessNode);
var
  SimulatedOffset: Cardinal;
  I: Integer;
  ProcStr: String;
begin
  if not Assigned(ANode) then Exit;

  FSelectedNode := ANode;

  lblMetaPID.Caption := 'PID: ' + IntToStr(ANode.PID);
  lblMetaProcess.Caption := 'Process: ' + ANode.ProcessName;

  if ANode.ParentPID > 0 then
    lblMetaParent.Caption := 'Parent: ' + IntToStr(ANode.ParentPID)
  else
    lblMetaParent.Caption := 'Parent: Unknown (Orphaned)';

  SimulatedOffset := ANode.PID * $10000;
  lblMetaOffset.Caption := Format('Memory Offset: 0x%8.8X', [SimulatedOffset]);

  if ANode.IsTerminated then
  begin
    FillByte(FActiveMemory, SizeOf(FActiveMemory), 0);
  end
  else
  begin
    for I := Low(FActiveMemory) to High(FActiveMemory) do
      FActiveMemory[I] := Random(256);

    FActiveMemory[0] := $4D; // M
    FActiveMemory[1] := $5A; // Z
    FActiveMemory[2] := $90;
    FActiveMemory[3] := $00;

    ProcStr := 'ProcName: ' + ANode.ProcessName;
    for I := 1 to Length(ProcStr) do
    begin
      if (32 + I) <= High(FActiveMemory) then
        FActiveMemory[32 + I - 1] := Ord(ProcStr[I]);
    end;

    if ANode.ThreatLevel > tlSafe then
    begin
      FActiveMemory[128] := $EB;
      FActiveMemory[129] := $10;
      FActiveMemory[130] := $90;
      FActiveMemory[131] := $90;
      FActiveMemory[132] := $E8;
    end;
  end;

  FHexViewer.LoadBuffer(@FActiveMemory[0], SizeOf(FActiveMemory), SimulatedOffset);
end;

end.
