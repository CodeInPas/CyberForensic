unit uEntropyCalculator;

{$mode objfpc}{$H+}

interface

uses
  Math;

{ Calculate Shannon Entropy for a given memory block.
  Result ranges from 0.0 (completely uniform) to 8.0 (completely random/encrypted). }
function CalculateMemoryEntropy(Data: PByte; Size: PtrInt): Single;

implementation

function CalculateMemoryEntropy(Data: PByte; Size: PtrInt): Single;
var
  ByteCounts: array[0..255] of PtrUInt;
  I: Integer;
  P: PByte;
  Prob, InvSize: Single;
begin
  Result := 0.0;
  if (Data = nil) or (Size <= 0) then Exit;

  FillChar(ByteCounts, SizeOf(ByteCounts), 0);

  P := Data;
  for I := 1 to Size do
  begin
    Inc(ByteCounts[P^]);
    Inc(P);
  end;

  InvSize := 1.0 / Size;
  for I := 0 to 255 do
  begin
    if ByteCounts[I] > 0 then
    begin
      Prob := ByteCounts[I] * InvSize;
      Result := Result - (Prob * Log2(Prob));
    end;
  end;
end;

end.

