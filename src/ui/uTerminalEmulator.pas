unit uTerminalEmulator;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, Controls, Graphics, LCLType, Types,
  uColorThemeConstants, uBgraOffScreenRenderer;

type
  TCommandEvent = procedure(Sender: TObject; const ACommand: String) of object;

  TTerminalLine = record
    Text: String;
    Color: TColor;
  end;

  { TTerminalEmulator: High-performance, custom-rendered command line interface
    tailored for fast text rendering and command input without standard TMemo overhead. }
  TTerminalEmulator = class(TCustomControl)
  private
    FRenderer: TOffScreenRenderer;
    FLines: array of TTerminalLine;
    FLineCount: Integer;
    FInputBuffer: String;
    FPrompt: String;
    FMaxLines: Integer;
    FLineHeight: Integer;

    { Tambahan untuk melacak posisi kursor (berdasarkan index karakter) }
    FCursorPos: Integer;

    FOnCommand: TCommandEvent;

    procedure MeasureFont;
    procedure RenderToBuffer;
    procedure PushLine(const AText: String; AColor: TColor);
  protected
    procedure Paint; override;
    procedure Resize; override;
    procedure FontChanged(Sender: TObject); override;

    { KeyPress untuk karakter biasa }
    procedure KeyPress(var Key: char); override;

    { KeyDown untuk tombol panah, delete, dsb }
    procedure KeyDown(var Key: Word; Shift: TShiftState); override;

    procedure MouseDown(Button: TMouseButton; Shift: TShiftState; X, Y: Integer); override;
    procedure DoEnter; override;
    procedure DoExit; override;
  public
    constructor Create(AOwner: TComponent); override;
    destructor Destroy; override;

    procedure Print(const AText: String; AColor: TColor = COLOR_TEXT_TERMINAL);
    procedure ClearTerminal;

    property Prompt: String read FPrompt write FPrompt;
    property MaxLines: Integer read FMaxLines write FMaxLines;
    property OnCommand: TCommandEvent read FOnCommand write FOnCommand;
  end;

implementation

{ TTerminalEmulator }

constructor TTerminalEmulator.Create(AOwner: TComponent);
begin
  inherited Create(AOwner);
  ControlStyle := ControlStyle + [csOpaque];
  DoubleBuffered := True;
  TabStop := True;

  Color := COLOR_BG_TERMINAL;
  Font.Name := 'Consolas';
  Font.Size := 10;
  Font.Color := COLOR_TEXT_PRIMARY;

  FRenderer := TOffScreenRenderer.Create(Width, Height);

  FMaxLines := 1000;
  FLineCount := 0;
  SetLength(FLines, FMaxLines);

  FPrompt := 'volatility_core > ';
  FInputBuffer := '';
  FCursorPos := 0; { 0 berarti kursor ada di paling kiri (index 0) setelah prompt }

  MeasureFont;
end;

destructor TTerminalEmulator.Destroy;
begin
  SetLength(FLines, 0);
  FRenderer.Free;
  inherited Destroy;
end;

procedure TTerminalEmulator.MouseDown(Button: TMouseButton; Shift: TShiftState; X, Y: Integer);
begin
  inherited MouseDown(Button, Shift, X, Y);

  if CanFocus then
    SetFocus;
end;

procedure TTerminalEmulator.DoEnter;
begin
  inherited DoEnter;
  Invalidate;
end;

procedure TTerminalEmulator.DoExit;
begin
  inherited DoExit;
  Invalidate;
end;

procedure TTerminalEmulator.MeasureFont;
var
  Bmp: TBitmap;
begin
  Bmp := TBitmap.Create;
  try
    Bmp.Canvas.Font.Assign(Self.Font);
    FLineHeight := Bmp.Canvas.TextHeight('Wg') + 4;
  finally
    Bmp.Free;
  end;
end;

procedure TTerminalEmulator.Resize;
begin
  inherited Resize;
  if Assigned(FRenderer) then
  begin
    FRenderer.Resize(Width, Height);
    MeasureFont;
    Invalidate;
  end;
end;

procedure TTerminalEmulator.FontChanged(Sender: TObject);
begin
  inherited FontChanged(Sender);
  MeasureFont;
  Invalidate;
end;

procedure TTerminalEmulator.PushLine(const AText: String; AColor: TColor);
begin
  if FLineCount < FMaxLines then
  begin
    FLines[FLineCount].Text := AText;
    FLines[FLineCount].Color := AColor;
    Inc(FLineCount);
  end
  else
  begin
    System.Move(FLines[1], FLines[0], (FMaxLines - 1) * SizeOf(TTerminalLine));
    FLines[FMaxLines - 1].Text := AText;
    FLines[FMaxLines - 1].Color := AColor;
  end;
end;

procedure TTerminalEmulator.Print(const AText: String; AColor: TColor);
begin
  PushLine(AText, AColor);
  Invalidate;
end;

procedure TTerminalEmulator.ClearTerminal;
begin
  FLineCount := 0;
  Invalidate;
end;

{ --- NAVIGASI PANAH (KIRI/KANAN) & DELETE --- }
procedure TTerminalEmulator.KeyDown(var Key: Word; Shift: TShiftState);
begin
  inherited KeyDown(Key, Shift);

  if Key = VK_LEFT then
  begin
    if FCursorPos > 0 then
    begin
      Dec(FCursorPos);
      Invalidate;
    end;
    Key := 0;
  end
  else if Key = VK_RIGHT then
  begin
    if FCursorPos < Length(FInputBuffer) then
    begin
      Inc(FCursorPos);
      Invalidate;
    end;
    Key := 0;
  end
  else if Key = VK_DELETE then
  begin
    if FCursorPos < Length(FInputBuffer) then
    begin
      { Hapus karakter tepat di sebelah kanan kursor }
      Delete(FInputBuffer, FCursorPos + 1, 1);
      Invalidate;
    end;
    Key := 0;
  end
  else if Key = VK_HOME then
  begin
    FCursorPos := 0;
    Invalidate;
    Key := 0;
  end
  else if Key = VK_END then
  begin
    FCursorPos := Length(FInputBuffer);
    Invalidate;
    Key := 0;
  end;
end;

{ --- PENGETIKAN KARAKTER --- }
procedure TTerminalEmulator.KeyPress(var Key: char);
begin
  inherited KeyPress(Key);

  if Key = #8 then { Karakter Backspace }
  begin
    if (Length(FInputBuffer) > 0) and (FCursorPos > 0) then
    begin
      Delete(FInputBuffer, FCursorPos, 1);
      Dec(FCursorPos);
      Invalidate;
    end;
    Key := #0;
  end
  else if Key = #13 then { Karakter Enter / Return }
  begin
    if Length(FInputBuffer) > 0 then
    begin
      Print(FPrompt + FInputBuffer, COLOR_TEXT_MUTED);
      if Assigned(FOnCommand) then
        FOnCommand(Self, FInputBuffer);
      FInputBuffer := '';
      FCursorPos := 0; { Reset kursor }
      Invalidate;
    end;
    Key := #0;
  end
  else if Key in [#32..#126] then { ASCII Biasa }
  begin
    { Sisipkan karakter di posisi kursor }
    Insert(Key, FInputBuffer, FCursorPos + 1);
    Inc(FCursorPos);
    Invalidate;
    Key := #0;
  end;
end;

{ --- RENDERER DENGAN WORDWRAP --- }
procedure TTerminalEmulator.RenderToBuffer;
var
  C: TCanvas;
  I, J, CurrentY: Integer;
  LineText, Remainder, WrapLine: String;
  MaxAvailableWidth, TotalNeededLines: Integer;

  { List dinamis untuk menampung baris hasil wrap sementara }
  RenderedLines: array of record
    Text: String;
    Color: TColor;
  end;

begin
  if not Assigned(FRenderer) then Exit;

  FRenderer.Clear(COLOR_BG_TERMINAL);

  C := FRenderer.Buffer.Canvas;
  C.Font.Assign(Self.Font);
  C.Brush.Style := bsClear;

  if FLineHeight <= 0 then Exit;

  { Jarak dari kiri & kanan (Margin) }
  MaxAvailableWidth := Width - 16;
  if MaxAvailableWidth < 50 then MaxAvailableWidth := 50;

  SetLength(RenderedLines, 0);

  { --- FASE 1: Memecah semua baris riwayat berdasarkan lebar layar (Word Wrap) --- }
  for I := 0 to FLineCount - 1 do
  begin
    Remainder := FLines[I].Text;

    while Remainder <> '' do
    begin
      WrapLine := '';
      for J := 1 to Length(Remainder) do
      begin
        { Cek apakah string sejauh ini melebihi lebar layar }
        if C.TextWidth(WrapLine + Remainder[J]) > MaxAvailableWidth then
        begin
          Break;
        end;
        WrapLine := WrapLine + Remainder[J];
      end;

      { Tambahkan potongan string ke daftar render }
      SetLength(RenderedLines, Length(RenderedLines) + 1);
      RenderedLines[High(RenderedLines)].Text := WrapLine;
      RenderedLines[High(RenderedLines)].Color := FLines[I].Color;

      { Hapus bagian yang sudah di-wrap dari sisa string }
      Delete(Remainder, 1, Length(WrapLine));
    end;
  end;

  { --- FASE 2: Render dari bawah ke atas agar selalu nempel di posisi Prompt --- }
  TotalNeededLines := Length(RenderedLines);
  CurrentY := Height - FLineHeight - 4; { Ini baris khusus Prompt & Ketikan }

  { Gambar mundur (dari garis paling baru ke garis paling lama riwayat) }
  for I := TotalNeededLines - 1 downto 0 do
  begin
    CurrentY := CurrentY - FLineHeight;
    if CurrentY < 0 then Break; { Berhenti jika sudah melewati batas atas layar }

    C.Font.Color := RenderedLines[I].Color;
    C.TextOut(8, CurrentY, RenderedLines[I].Text);
  end;

  { --- FASE 3: Render Prompt & Baris Ketikan Aktif (Di Bottom) --- }
  CurrentY := Height - FLineHeight - 4;
  C.Font.Color := COLOR_TEXT_PRIMARY;

  { Cek apakah teks input aktif melebihi layar }
  { (Jika panjang, kita render dari ujung kursor ke belakang) }
  LineText := FPrompt + FInputBuffer;

  if C.TextWidth(LineText) > MaxAvailableWidth then
  begin
     { Jika terlalu panjang, potong dari kiri agar kursor tetap terlihat }
     while (C.TextWidth(LineText) > MaxAvailableWidth) and (Length(LineText) > Length(FPrompt)) do
     begin
       Delete(LineText, Length(FPrompt) + 1, 1);
     end;
  end;

  C.TextOut(8, CurrentY, LineText);

  { --- FASE 4: Render Kursor (Garid bawah _) --- }
  if Focused then
  begin
    { Hitung lebar teks dari FPrompt sampai titik kursor berada }
    WrapLine := FPrompt + Copy(FInputBuffer, 1, FCursorPos);
    C.TextOut(8 + C.TextWidth(WrapLine), CurrentY, '_');
  end;
end;

procedure TTerminalEmulator.Paint;
begin
  inherited Paint;
  if Assigned(FRenderer) then
  begin
    RenderToBuffer;
    FRenderer.RenderToCanvas(Canvas, 0, 0);
  end;
end;

end.
