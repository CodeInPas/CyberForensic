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
    FOnCommand: TCommandEvent;

    procedure MeasureFont;
    procedure RenderToBuffer;
    procedure PushLine(const AText: String; AColor: TColor);
  protected
    procedure Paint; override;
    procedure Resize; override;
    procedure FontChanged(Sender: TObject); override;

    { Menggunakan KeyPress untuk menangkap ketikan, Backspace, dan Enter secara absolut }
    procedure KeyPress(var Key: char); override;

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

{ --- PERBAIKAN LOGIKA KEYBOARD --- }
procedure TTerminalEmulator.KeyPress(var Key: char);
begin
  inherited KeyPress(Key);

  if Key = #8 then { Karakter Backspace }
  begin
    if Length(FInputBuffer) > 0 then
    begin
      Delete(FInputBuffer, Length(FInputBuffer), 1);
      Invalidate;
    end;
    Key := #0; { Konsumsi tombol agar tidak memicu bunyi beep sistem }
  end
  else if Key = #13 then { Karakter Enter / Return }
  begin
    if Length(FInputBuffer) > 0 then
    begin
      Print(FPrompt + FInputBuffer, COLOR_TEXT_MUTED);
      if Assigned(FOnCommand) then
        FOnCommand(Self, FInputBuffer);
      FInputBuffer := '';
      Invalidate;
    end;
    Key := #0;
  end
  else if Key in [#32..#126] then { Hanya izinkan karakter ASCII yang dapat diketik (Spasi s/d Tilde) }
  begin
    FInputBuffer := FInputBuffer + Key;
    Invalidate;
    Key := #0;
  end;
end;

procedure TTerminalEmulator.RenderToBuffer;
var
  C: TCanvas;
  I: Integer;
  CurrentY: Integer;
  VisibleLinesCount: Integer;
  StartIdx: Integer;
begin
  if not Assigned(FRenderer) then Exit;

  FRenderer.Clear(COLOR_BG_TERMINAL);

  C := FRenderer.Buffer.Canvas;
  C.Font.Assign(Self.Font);
  C.Brush.Style := bsClear;

  if FLineHeight <= 0 then Exit;

  VisibleLinesCount := (Height div FLineHeight) - 1;

  StartIdx := FLineCount - VisibleLinesCount;
  if StartIdx < 0 then StartIdx := 0;

  CurrentY := 4;

  for I := StartIdx to FLineCount - 1 do
  begin
    C.Font.Color := FLines[I].Color;
    C.TextOut(8, CurrentY, FLines[I].Text);
    Inc(CurrentY, FLineHeight);
  end;

  CurrentY := Height - FLineHeight - 4;

  C.Font.Color := COLOR_TEXT_PRIMARY;
  C.TextOut(8, CurrentY, FPrompt + FInputBuffer);

  if Focused then
  begin
    C.TextOut(8 + C.TextWidth(FPrompt + FInputBuffer), CurrentY, '_');
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
