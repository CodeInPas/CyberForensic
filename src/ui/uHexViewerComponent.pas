unit uHexViewerComponent;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, Controls, Graphics, Math, LCLIntf, LCLType,
  uColorThemeConstants, uBgraOffScreenRenderer, BGRABitmap;

type
  { THexViewerComponent: High-performance custom control for displaying hexadecimal
    data streams with adaptive syntax highlighting and zero-flicker double buffering. }
  THexViewerComponent = class(TCustomControl)
  private
    FRenderer: TOffScreenRenderer;
    FData: PByte;
    FDataSize: Integer;
    FBaseOffset: QWord;

    FCharWidth: Integer;
    FLineHeight: Integer;
    FVisibleLines: Integer;

    procedure MeasureFont;
    procedure RenderDataToBuffer;
    function GetByteColor(AByte: Byte): TColor;
    function GetPrintableChar(AByte: Byte): Char;
  protected
    procedure Paint; override;
    procedure Resize; override;
    procedure FontChanged(Sender: TObject); override;
  public
    constructor Create(AOwner: TComponent); override;
    destructor Destroy; override;

    { Feeds the visible window buffer directly from the Virtualizer }
    procedure LoadBuffer(ABuffer: PByte; ASize: Integer; AOffset: QWord);

    property VisibleLines: Integer read FVisibleLines;
    property LineHeight: Integer read FLineHeight;
  end;

implementation

{ THexViewerComponent }

constructor THexViewerComponent.Create(AOwner: TComponent);
begin
  inherited Create(AOwner);
  ControlStyle := ControlStyle + [csOpaque, csDoubleClicks];
  DoubleBuffered := True;

  Color := COLOR_BG_TERMINAL;
  Font.Name := 'Consolas';
  Font.Size := 10;
  Font.Color := COLOR_TEXT_PRIMARY;

  FRenderer := TOffScreenRenderer.Create(Width, Height);

  FData := nil;
  FDataSize := 0;
  FBaseOffset := 0;

  MeasureFont;
end;

destructor THexViewerComponent.Destroy;
begin
  FRenderer.Free;
  inherited Destroy;
end;

procedure THexViewerComponent.MeasureFont;
var
  Bmp: TBitmap;
begin
  Bmp := TBitmap.Create;
  try
    Bmp.Canvas.Font.Assign(Self.Font);
    FCharWidth := Bmp.Canvas.TextWidth('0');
    FLineHeight := Bmp.Canvas.TextHeight('0') + 4; { 4px vertical padding }
  finally
    Bmp.Free;
  end;

  if FLineHeight > 0 then
    FVisibleLines := Height div FLineHeight
  else
    FVisibleLines := 0;
end;

procedure THexViewerComponent.Resize;
begin
  inherited Resize;
  if Assigned(FRenderer) then
  begin
    FRenderer.Resize(Width, Height);
    MeasureFont;
    RenderDataToBuffer;
  end;
end;

procedure THexViewerComponent.FontChanged(Sender: TObject);
begin
  inherited FontChanged(Sender);
  MeasureFont;
  RenderDataToBuffer;
  Invalidate;
end;

function THexViewerComponent.GetByteColor(AByte: Byte): TColor;
begin
  case AByte of
    $00: Result := COLOR_HEX_ZERO;
    $4D, $5A, $50, $45: Result := COLOR_HEX_HEADER; { M, Z, P, E headers diprioritaskan }
    $EB, $E8, $E9, $90: Result := COLOR_HEX_DANGER; { Common x86 jumps/NOPs (Shellcode) }
  else
    { Pengecekan rentang ASCII dipindah ke kondisi Else untuk menghindari duplicate case label }
    if AByte in [$20..$7E] then
      Result := COLOR_HEX_STRING           { Printable ASCII }
    else
      Result := COLOR_TEXT_PRIMARY;
  end;
end;

function THexViewerComponent.GetPrintableChar(AByte: Byte): Char;
begin
  if AByte in [$20..$7E] then
    Result := Chr(AByte)
  else
    Result := '.';
end;

procedure THexViewerComponent.LoadBuffer(ABuffer: PByte; ASize: Integer; AOffset: QWord);
begin
  FData := ABuffer;
  FDataSize := ASize;
  FBaseOffset := AOffset;
  RenderDataToBuffer;
  Invalidate;
end;

procedure THexViewerComponent.RenderDataToBuffer;
var
  C: TCanvas;
  I, J, DataIdx: Integer;
  LineOffset: QWord;
  HexStr, AsciiStr: String;
  X, Y: Integer;
  B: Byte;
  ByteColor: TColor;
begin
  if not Assigned(FRenderer) then Exit;

  FRenderer.Clear(COLOR_BG_TERMINAL);

  if (FData = nil) or (FDataSize <= 0) then Exit;

  C := FRenderer.Buffer.Canvas;
  C.Font.Assign(Self.Font);
  C.Brush.Style := bsClear;

  Y := 2;
  DataIdx := 0;

  for I := 0 to FVisibleLines - 1 do
  begin
    if DataIdx >= FDataSize then Break;

    LineOffset := FBaseOffset + QWord(DataIdx);

    { 1. Draw Offset Column }
    C.Font.Color := COLOR_HEX_OFFSET;
    C.TextOut(4, Y, IntToHex(LineOffset, 8));

    X := 4 + (9 * FCharWidth); { Offset after '00000000 ' }
    AsciiStr := '';

    { 2. Draw 16 Bytes of Hex Data }
    for J := 0 to 15 do
    begin
      if DataIdx < FDataSize then
      begin
        B := FData[DataIdx];
        HexStr := IntToHex(B, 2);

        { Adaptive Coloring }
        ByteColor := GetByteColor(B);
        C.Font.Color := ByteColor;
        C.TextOut(X, Y, HexStr);

        AsciiStr := AsciiStr + GetPrintableChar(B);
        Inc(DataIdx);
      end
      else
      begin
        { Pad empty space if end of buffer reached }
        C.Font.Color := COLOR_HEX_ZERO;
        C.TextOut(X, Y, '  ');
        AsciiStr := AsciiStr + ' ';
      end;

      Inc(X, FCharWidth * 3); { 'FF ' is 3 chars wide }

      { Add extra spacing in the middle (8th byte) }
      if J = 7 then
        Inc(X, FCharWidth);
    end;

    { 3. Draw ASCII Column }
    Inc(X, FCharWidth * 2);
    C.Font.Color := COLOR_TEXT_MUTED;
    C.TextOut(X, Y, AsciiStr);

    Inc(Y, FLineHeight);
  end;
end;

procedure THexViewerComponent.Paint;
begin
  inherited Paint;
  if Assigned(FRenderer) then
    FRenderer.RenderToCanvas(Canvas, 0, 0);
end;

end.
