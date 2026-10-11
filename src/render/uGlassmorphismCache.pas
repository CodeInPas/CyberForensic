unit uGlassmorphismCache;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, Graphics, BGRABitmap, BGRABitmapTypes;

type
  { TGlassmorphismCache: Caches a blurred version of the background to provide
    high-performance frosted glass effects without re-calculating blur per frame. }
  TGlassmorphismCache = class
  private
    FSourceImage: TBGRABitmap;
    FBlurredCache: TBGRABitmap;
    FBlurRadius: Integer;
    FTintColor: TBGRAPixel;
    FIsDirty: Boolean;
    procedure RebuildCache;
  public
    constructor Create;
    destructor Destroy; override;

    { Updates the source background image. Triggers a cache rebuild on next fetch. }
    procedure SetSource(ASource: TBGRABitmap);

    { Configures the glass effect parameters. }
    procedure SetParameters(ABlurRadius: Integer; ATint: TBGRAPixel);

    { Returns the cached blurred image. Only recalculates mathematically if marked dirty. }
    function GetGlassBackground: TBGRABitmap;
  end;

implementation

{ TGlassmorphismCache }

constructor TGlassmorphismCache.Create;
begin
  FSourceImage := nil;
  FBlurredCache := TBGRABitmap.Create;
  FBlurRadius := 15; { Default optimal blur for readability and performance }
  FTintColor := BGRA(20, 20, 25, 120); { Default dark frosted tint }
  FIsDirty := True;
end;

destructor TGlassmorphismCache.Destroy;
begin
  if Assigned(FSourceImage) then
    FSourceImage.Free;
  FBlurredCache.Free;
  inherited Destroy;
end;

procedure TGlassmorphismCache.SetSource(ASource: TBGRABitmap);
begin
  if not Assigned(ASource) then Exit;

  if not Assigned(FSourceImage) then
    FSourceImage := TBGRABitmap.Create;

  FSourceImage.SetSize(ASource.Width, ASource.Height);
  FSourceImage.PutImage(0, 0, ASource, dmSet);

  FIsDirty := True;
end;

procedure TGlassmorphismCache.SetParameters(ABlurRadius: Integer; ATint: TBGRAPixel);
begin
  { Avoid unnecessary invalidation if parameters haven't actually changed }
  if (FBlurRadius <> ABlurRadius) or (FTintColor <> ATint) then
  begin
    FBlurRadius := ABlurRadius;
    FTintColor := ATint;
    FIsDirty := True;
  end;
end;

procedure TGlassmorphismCache.RebuildCache;
begin
  if not Assigned(FSourceImage) then Exit;

  { Duplicate source directly into cache buffer }
  FBlurredCache.SetSize(FSourceImage.Width, FSourceImage.Height);
  FBlurredCache.PutImage(0, 0, FSourceImage, dmSet);

  { Apply BGRABitmap's heavily optimized FastBlur.
    BGRAReplace safely swaps the pointer of the newly filtered bitmap. }
  if FBlurRadius > 0 then
    BGRAReplace(FBlurredCache, FBlurredCache.FilterFastBlur(FBlurRadius, rbFast));

  { Blend the tint overlay (Noise/Opacity) for the frosted effect }
  if FTintColor.alpha > 0 then
    FBlurredCache.FillRect(0, 0, FBlurredCache.Width, FBlurredCache.Height, FTintColor, dmDrawWithTransparency);

  FIsDirty := False;
end;

function TGlassmorphismCache.GetGlassBackground: TBGRABitmap;
begin
  if FIsDirty and Assigned(FSourceImage) then
    RebuildCache;
  Result := FBlurredCache;
end;

end.

