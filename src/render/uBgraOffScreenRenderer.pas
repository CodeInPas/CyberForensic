unit uBgraOffScreenRenderer;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, Graphics, BGRABitmap, BGRABitmapTypes;

type
  { TOffScreenRenderer: Manages double-buffering using BGRABitmap
    to ensure tear-free and flicker-free drawing in LCL applications. }
  TOffScreenRenderer = class
  private
    FBuffer: TBGRABitmap;
    FWidth: Integer;
    FHeight: Integer;
  public
    constructor Create(AWidth, AHeight: Integer);
    destructor Destroy; override;

    { Resizes the internal buffer only if dimensions change, minimizing allocations }
    procedure Resize(AWidth, AHeight: Integer);

    { Clears the buffer with a specific background color }
    procedure Clear(ABackgroundColor: TColor); overload;
    procedure Clear(ABackgroundColor: TBGRAPixel); overload;

    { Blits the off-screen buffer to the target LCL Canvas (e.g., TPaintBox) }
    procedure RenderToCanvas(ATargetCanvas: TCanvas; X, Y: Integer);

    { Direct access to the BGRABitmap for drawing operations }
    property Buffer: TBGRABitmap read FBuffer;
    property Width: Integer read FWidth;
    property Height: Integer read FHeight;
  end;

implementation

{ TOffScreenRenderer }

constructor TOffScreenRenderer.Create(AWidth, AHeight: Integer);
begin
  FWidth := AWidth;
  FHeight := AHeight;
  FBuffer := TBGRABitmap.Create(FWidth, FHeight);
end;

destructor TOffScreenRenderer.Destroy;
begin
  if Assigned(FBuffer) then
    FBuffer.Free;
  inherited Destroy;
end;

procedure TOffScreenRenderer.Resize(AWidth, AHeight: Integer);
begin
  if (FWidth <> AWidth) or (FHeight <> AHeight) then
  begin
    FWidth := AWidth;
    FHeight := AHeight;
    if Assigned(FBuffer) then
      FBuffer.SetSize(FWidth, FHeight);
  end;
end;

procedure TOffScreenRenderer.Clear(ABackgroundColor: TColor);
begin
  if Assigned(FBuffer) then
    FBuffer.Fill(ColorToBGRA(ColorToRGB(ABackgroundColor)));
end;

procedure TOffScreenRenderer.Clear(ABackgroundColor: TBGRAPixel);
begin
  if Assigned(FBuffer) then
    FBuffer.Fill(ABackgroundColor);
end;

procedure TOffScreenRenderer.RenderToCanvas(ATargetCanvas: TCanvas; X, Y: Integer);
begin
  if Assigned(FBuffer) and Assigned(ATargetCanvas) then
  begin
    { False = Opaque draw, which is significantly faster than AlphaBlend }
    FBuffer.Draw(ATargetCanvas, X, Y, False);
  end;
end;

end.

