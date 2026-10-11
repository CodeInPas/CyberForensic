unit uThreatSpectrumComponent;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, Controls, Graphics, Types,
  uColorThemeConstants, uGenericsModels, uBgraOffScreenRenderer,
  BGRABitmap, BGRABitmapTypes;

type
  { TThreatSpectrumComponent: Renders a real-time spectrum chart
    showing the distribution of threat levels in memory. }
  TThreatSpectrumComponent = class(TCustomControl)
  private
    FRenderer: TOffScreenRenderer;
    FProcessDict: TProcessDictionary;

    FSafeCount, FSuspectCount, FMalwareCount, FCriticalCount: Integer;

    procedure CalculateSpectrum;
    procedure DrawSpectrumToBuffer;
  protected
    procedure Paint; override;
    procedure Resize; override;
  public
    constructor Create(AOwner: TComponent); override;
    destructor Destroy; override;

    { Updates the chart with current live data }
    procedure UpdateSpectrum(AProcessDict: TProcessDictionary);
  end;

implementation

{ TThreatSpectrumComponent }

constructor TThreatSpectrumComponent.Create(AOwner: TComponent);
begin
  inherited Create(AOwner);
  ControlStyle := ControlStyle + [csOpaque];
  DoubleBuffered := True;

  FRenderer := TOffScreenRenderer.Create(Width, Height);
  FProcessDict := nil;

  FSafeCount := 0;
  FSuspectCount := 0;
  FMalwareCount := 0;
  FCriticalCount := 0;

  Font.Name := 'Consolas';
  Font.Size := 9;
  Font.Color := COLOR_TEXT_PRIMARY;
end;

destructor TThreatSpectrumComponent.Destroy;
begin
  FRenderer.Free;
  inherited Destroy;
end;

procedure TThreatSpectrumComponent.Resize;
begin
  inherited Resize;
  if Assigned(FRenderer) then
  begin
    FRenderer.Resize(Width, Height);
    Invalidate;
  end;
end;

procedure TThreatSpectrumComponent.UpdateSpectrum(AProcessDict: TProcessDictionary);
begin
  FProcessDict := AProcessDict;
  CalculateSpectrum;
  Invalidate;
end;

procedure TThreatSpectrumComponent.CalculateSpectrum;
var
  Node: TProcessNode;
begin
  FSafeCount := 0;
  FSuspectCount := 0;
  FMalwareCount := 0;
  FCriticalCount := 0;

  if not Assigned(FProcessDict) then Exit;

  { Hitung distribusi jenis ancaman dari proses yang masih hidup }
  for Node in FProcessDict.Values do
  begin
    if Node.IsTerminated then Continue;

    case Node.ThreatLevel of
      tlSafe: Inc(FSafeCount);
      tlSuspicious: Inc(FSuspectCount);
      tlMalicious: Inc(FMalwareCount);
      tlCritical: Inc(FCriticalCount);
    end;
  end;
end;

procedure TThreatSpectrumComponent.DrawSpectrumToBuffer;
var
  C: TCanvas;
  TotalActive, TotalWidth, StartX: Integer;
  SafeW, SuspectW, MalwareW, CriticalW: Integer;
  BarHeight, BarTop: Integer;
  BgColor, FillColor: TBGRAPixel;
begin
  if not Assigned(FRenderer) then Exit;

  FRenderer.Clear(COLOR_BG_MAIN);
  C := FRenderer.Buffer.Canvas;

  TotalActive := FSafeCount + FSuspectCount + FMalwareCount + FCriticalCount;
  if TotalActive = 0 then TotalActive := 1; { Hindari Div By Zero }

  { Gambar Judul Panel }
  C.Font.Assign(Self.Font);
  C.Font.Color := $00E2B75A; { Cyan / Tema utama }
  C.Font.Style := [fsBold];
  C.Brush.Style := bsClear;
  C.TextOut(16, 12, 'LIVE THREAT SPECTRUM');

  { --- Rendering Horizontal Bar Chart (Spectrum) --- }
  TotalWidth := Width - 32;
  BarTop := 40;
  BarHeight := 25;
  StartX := 16;

  { Latar Belakang Bar (Track) }
  BgColor := ColorToBGRA(ColorToRGB($00252525));
  FRenderer.Buffer.FillRect(StartX, BarTop, StartX + TotalWidth, BarTop + BarHeight, BgColor, dmSet);

  { Hitung Proporsi Lebar masing-masing kategori }
  SafeW := Round((FSafeCount / TotalActive) * TotalWidth);
  SuspectW := Round((FSuspectCount / TotalActive) * TotalWidth);
  MalwareW := Round((FMalwareCount / TotalActive) * TotalWidth);
  CriticalW := TotalWidth - (SafeW + SuspectW + MalwareW); { Sisanya }

  { Gambar Segmen Safe (Cyan) }
  if SafeW > 0 then
  begin
    FillColor := ColorToBGRA(ColorToRGB(COLOR_NODE_NORMAL));
    FRenderer.Buffer.FillRect(StartX, BarTop, StartX + SafeW, BarTop + BarHeight, FillColor, dmSet);
    StartX := StartX + SafeW;
  end;

  { Gambar Segmen Suspicious (Kuning/Orange) }
  if SuspectW > 0 then
  begin
    FillColor := ColorToBGRA(ColorToRGB(COLOR_NODE_SUSPECT));
    FRenderer.Buffer.FillRect(StartX, BarTop, StartX + SuspectW, BarTop + BarHeight, FillColor, dmSet);
    StartX := StartX + SuspectW;
  end;

  { Gambar Segmen Malicious (Merah Muda) }
  if MalwareW > 0 then
  begin
    FillColor := ColorToBGRA(ColorToRGB(COLOR_NODE_MALWARE));
    FRenderer.Buffer.FillRect(StartX, BarTop, StartX + MalwareW, BarTop + BarHeight, FillColor, dmSet);
    StartX := StartX + MalwareW;
  end;

  { Gambar Segmen Critical (Merah Darah Gelap / Glow) }
  if CriticalW > 0 then
  begin
    FillColor := ColorToBGRA(ColorToRGB($000000FF)); { Solid Red }
    FRenderer.Buffer.FillRect(StartX, BarTop, StartX + CriticalW, BarTop + BarHeight, FillColor, dmSet);
  end;

  { --- Rendering Legenda / Keterangan Teks --- }
  C.Font.Style := [];
  C.Font.Size := 8;

  C.Font.Color := COLOR_NODE_NORMAL;
  C.TextOut(16, 75, Format('Safe: %d', [FSafeCount]));

  C.Font.Color := COLOR_NODE_SUSPECT;
  C.TextOut(85, 75, Format('Suspect: %d', [FSuspectCount]));

  C.Font.Color := COLOR_NODE_MALWARE;
  C.TextOut(175, 75, Format('Malware: %d', [FMalwareCount]));

  C.Font.Color := $004444FF; { Merah Terang }
  C.TextOut(265, 75, Format('Critical: %d', [FCriticalCount]));
end;

procedure TThreatSpectrumComponent.Paint;
begin
  inherited Paint;
  DrawSpectrumToBuffer;
  if Assigned(FRenderer) then
    FRenderer.RenderToCanvas(Canvas, 0, 0);
end;

end.
