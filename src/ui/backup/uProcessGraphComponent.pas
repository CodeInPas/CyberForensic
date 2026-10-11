unit uProcessGraphComponent;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, Controls, Graphics, Math, Types,
  uColorThemeConstants, uGenericsModels, uBgraOffScreenRenderer,
  BGRABitmap, BGRABitmapTypes;

type
  { Deklarasi event custom untuk menangkap node yang diklik }
  TProcessNodeClickEvent = procedure(Sender: TObject; ANode: TProcessNode) of object;

  { Stores calculated bounds for hit-testing (mouse interactions) }
  TNodeRenderData = record
    Node: TProcessNode;
    Bounds: TRect;
    CenterX: Integer;
    CenterY: Integer;
  end;

  { TProcessGraphComponent: Renders a node-based process tree visualization
    using efficient off-screen rendering and spatial layout calculation. }
  TProcessGraphComponent = class(TCustomControl)
  private
    FRenderer: TOffScreenRenderer;
    FProcessDict: TProcessDictionary;
    FNodeDataList: array of TNodeRenderData;
    FNeedsLayout: Boolean;

    FOffsetX: Integer;
    FOffsetY: Integer;

    FSelectedPID: Cardinal;
    FOnNodeClick: TProcessNodeClickEvent;

    procedure CalculateLayout;
    procedure DrawGraphToBuffer;
    function GetNodeColor(ANode: TProcessNode): TColor;
    function FindRenderData(APID: Cardinal; out AData: TNodeRenderData): Boolean;
  protected
    procedure Paint; override;
    procedure Resize; override;
    procedure MouseDown(Button: TMouseButton; Shift: TShiftState; X, Y: Integer); override;
  public
    constructor Create(AOwner: TComponent); override;
    destructor Destroy; override;

    { Binds the live simulation data to the visualizer }
    procedure LoadData(AProcessDict: TProcessDictionary);

    { Forces a layout recalculation and redraw (e.g., when new anomalies spawn) }
    procedure RefreshGraph;

    property OnNodeClick: TProcessNodeClickEvent read FOnNodeClick write FOnNodeClick;
    property SelectedPID: Cardinal read FSelectedPID write FSelectedPID;
  end;

implementation

{ TProcessGraphComponent }

constructor TProcessGraphComponent.Create(AOwner: TComponent);
begin
  inherited Create(AOwner);
  ControlStyle := ControlStyle + [csOpaque, csDoubleClicks];
  DoubleBuffered := True;

  FRenderer := TOffScreenRenderer.Create(Width, Height);
  FProcessDict := nil;
  SetLength(FNodeDataList, 0);

  FNeedsLayout := True;
  FOffsetX := 20;
  FOffsetY := 20;
  FSelectedPID := 0;

  Font.Name := 'Consolas';
  Font.Size := 9;
  Font.Color := COLOR_TEXT_PRIMARY;
end;

destructor TProcessGraphComponent.Destroy;
begin
  SetLength(FNodeDataList, 0);
  FRenderer.Free;
  inherited Destroy;
end;

procedure TProcessGraphComponent.Resize;
begin
  inherited Resize;
  if Assigned(FRenderer) then
  begin
    FRenderer.Resize(Width, Height);
    FNeedsLayout := True;
    Invalidate;
  end;
end;

procedure TProcessGraphComponent.LoadData(AProcessDict: TProcessDictionary);
begin
  FProcessDict := AProcessDict;
  RefreshGraph;
end;

procedure TProcessGraphComponent.RefreshGraph;
begin
  FNeedsLayout := True;
  Invalidate;
end;

procedure TProcessGraphComponent.MouseDown(Button: TMouseButton; Shift: TShiftState; X, Y: Integer);
var
  I: Integer;
  ClickPos: TPoint;
begin
  inherited MouseDown(Button, Shift, X, Y);

  if Button = mbLeft then
  begin
    ClickPos := Point(X, Y);

    { Lakukan Hit-Testing: Periksa apakah kordinat klik berada di dalam batas (Bounds) kotak proses }
    for I := 0 to High(FNodeDataList) do
    begin
      if PtInRect(FNodeDataList[I].Bounds, ClickPos) then
      begin
        { Simpan PID yang sedang dipilih agar bisa disorot (highlight) }
        FSelectedPID := FNodeDataList[I].Node.PID;
        Invalidate;

        { Picu Event OnNodeClick untuk dikirim ke MainForm }
        if Assigned(FOnNodeClick) then
          FOnNodeClick(Self, FNodeDataList[I].Node);

        Exit; { Hentikan pencarian setelah menemukan 1 node }
      end;
    end;

    { Jika klik di luar node, hapus seleksi }
    FSelectedPID := 0;
    Invalidate;
  end;
end;

function TProcessGraphComponent.FindRenderData(APID: Cardinal; out AData: TNodeRenderData): Boolean;
var
  I: Integer;
begin
  Result := False;
  for I := 0 to High(FNodeDataList) do
  begin
    if FNodeDataList[I].Node.PID = APID then
    begin
      AData := FNodeDataList[I];
      Result := True;
      Exit;
    end;
  end;
end;

function TProcessGraphComponent.GetNodeColor(ANode: TProcessNode): TColor;
begin
  if ANode.IsOrphaned then Exit(COLOR_NODE_ORPHAN);

  case ANode.ThreatLevel of
    tlSafe: Result := COLOR_NODE_NORMAL;
    tlSuspicious: Result := COLOR_NODE_SUSPECT;
    tlMalicious, tlCritical: Result := COLOR_NODE_MALWARE;
  else
    Result := COLOR_NODE_NORMAL;
  end;
end;

procedure TProcessGraphComponent.CalculateLayout;
const
  NODE_WIDTH = 140;
  NODE_HEIGHT = 45;
  X_SPACING = 160;
  Y_SPACING = 80;
var
  NodeCount, CurrentRow, CurrentCol: Integer;
  Node: TProcessNode;
begin
  if not Assigned(FProcessDict) then Exit;

  NodeCount := FProcessDict.Count;
  SetLength(FNodeDataList, NodeCount);

  CurrentRow := 0;
  CurrentCol := 0;
  NodeCount := 0;

  for Node in FProcessDict.Values do
  begin
    FNodeDataList[NodeCount].Node := Node;

    FNodeDataList[NodeCount].Bounds := Rect(
      FOffsetX + (CurrentCol * X_SPACING),
      FOffsetY + (CurrentRow * Y_SPACING),
      FOffsetX + (CurrentCol * X_SPACING) + NODE_WIDTH,
      FOffsetY + (CurrentRow * Y_SPACING) + NODE_HEIGHT
    );

    FNodeDataList[NodeCount].CenterX := FNodeDataList[NodeCount].Bounds.Left + (NODE_WIDTH div 2);
    FNodeDataList[NodeCount].CenterY := FNodeDataList[NodeCount].Bounds.Top + (NODE_HEIGHT div 2);

    Inc(CurrentCol);
    if (FOffsetX + (CurrentCol * X_SPACING) + NODE_WIDTH) > Width then
    begin
      CurrentCol := 0;
      Inc(CurrentRow);
    end;

    Inc(NodeCount);
  end;

  FNeedsLayout := False;
end;

procedure TProcessGraphComponent.DrawGraphToBuffer;
var
  I: Integer;
  ParentData, ChildData: TNodeRenderData;
  C: TCanvas;
  NodeColor: TColor;
  BgraColor, BgraEdgeColor, BgraHighlight: TBGRAPixel;
  NodeText: String;
begin
  if not Assigned(FRenderer) then Exit;

  FRenderer.Clear(COLOR_BG_MAIN);

  if Length(FNodeDataList) = 0 then Exit;

  { Draw Edges (Connections) first so they appear behind nodes }
  for I := 0 to High(FNodeDataList) do
  begin
    ChildData := FNodeDataList[I];

    if (ChildData.Node.ParentPID > 0) and FindRenderData(ChildData.Node.ParentPID, ParentData) then
    begin
      if ChildData.Node.IsOrphaned or (ChildData.Node.ThreatLevel > tlSafe) then
        BgraEdgeColor := ColorToBGRA(ColorToRGB(COLOR_EDGE_ALERT))
      else
        BgraEdgeColor := ColorToBGRA(ColorToRGB(COLOR_EDGE_NORMAL));

      FRenderer.Buffer.DrawLineAntialias(
        ParentData.CenterX, ParentData.Bounds.Bottom,
        ChildData.CenterX, ChildData.Bounds.Top,
        BgraEdgeColor, 2.0
      );
    end;
  end;

  C := FRenderer.Buffer.Canvas;
  C.Font.Assign(Self.Font);
  C.Brush.Style := bsClear;

  { Draw Nodes }
  for I := 0 to High(FNodeDataList) do
  begin
    ChildData := FNodeDataList[I];
    NodeColor := GetNodeColor(ChildData.Node);
    BgraColor := ColorToBGRA(ColorToRGB(NodeColor));

    { Draw Node Body (Rounded Rectangle with opacity) }
    BgraColor.alpha := 200;

    FRenderer.Buffer.FillRoundRectAntialias(
      ChildData.Bounds.Left, ChildData.Bounds.Top,
      ChildData.Bounds.Right, ChildData.Bounds.Bottom,
      5.0, 5.0, BgraColor
    );

    { Draw Node Border (Gunakan Border Putih Tebal jika Node sedang dipilih) }
    if ChildData.Node.PID = FSelectedPID then
    begin
      BgraHighlight := ColorToBGRA(clWhite);
      FRenderer.Buffer.RoundRectAntialias(
        ChildData.Bounds.Left, ChildData.Bounds.Top,
        ChildData.Bounds.Right, ChildData.Bounds.Bottom,
        5.0, 5.0, BgraHighlight, 2.5
      );
    end
    else
    begin
      BgraColor.alpha := 255;
      FRenderer.Buffer.RoundRectAntialias(
        ChildData.Bounds.Left, ChildData.Bounds.Top,
        ChildData.Bounds.Right, ChildData.Bounds.Bottom,
        5.0, 5.0, BgraColor, 1.5
      );
    end;

    { Draw Text }
    C.Font.Color := COLOR_TEXT_PRIMARY;
    C.Font.Style := [fsBold];
    NodeText := ChildData.Node.ProcessName;
    C.TextOut(ChildData.Bounds.Left + 8, ChildData.Bounds.Top + 6, NodeText);

    C.Font.Color := COLOR_TEXT_MUTED;
    C.Font.Style := [];
    NodeText := 'PID: ' + IntToStr(ChildData.Node.PID);
    C.TextOut(ChildData.Bounds.Left + 8, ChildData.Bounds.Top + 22, NodeText);
  end;
end;

procedure TProcessGraphComponent.Paint;
begin
  inherited Paint;

  if FNeedsLayout then
    CalculateLayout;

  DrawGraphToBuffer;

  if Assigned(FRenderer) then
    FRenderer.RenderToCanvas(Canvas, 0, 0);
end;

end.
