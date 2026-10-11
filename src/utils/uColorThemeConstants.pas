unit uColorThemeConstants;

{$mode objfpc}{$H+}

interface

uses
  Graphics;

const
  { === Base Theme Colors (TColor Format: $00BBGGRR) === }

  { Backgrounds }
  COLOR_BG_MAIN       = $001A1410; { Dark Blue/Grey (App Background) }
  COLOR_BG_PANEL      = $002A241F; { Frosted Glass Panel Base }
  COLOR_BG_TERMINAL   = $00120D0A; { Deep Dark Terminal Background }

  { Glassmorphism Opacity Config (0-255) }
  ALPHA_GLASS_PANEL   = 180;
  ALPHA_GLASS_MODAL   = 200;
  ALPHA_GLASS_SELECT  = 60;

  { Typography }
  COLOR_TEXT_PRIMARY  = $00E6E6E6; { Off-White for main UI labels }
  COLOR_TEXT_MUTED    = $007A7A7A; { Dimmed Text for placeholders }
  COLOR_TEXT_TERMINAL = $00E0E0E0; { Terminal Output }

  { === Hex Viewer Adaptive Colors === }
  COLOR_HEX_ZERO      = $004A4A4A; { Dim Gray    : Empty memory (00 00 00) }
  COLOR_HEX_HEADER    = $00FFFF00; { Cyan        : File Headers (MZ, PE) }
  COLOR_HEX_STRING    = $0000A5FF; { Orange      : ASCII/URLs/Strings }
  COLOR_HEX_ENTROPY   = $00FF00FF; { Magenta     : High Entropy/Encrypted blocks }
  COLOR_HEX_DANGER    = $000000FF; { Bright Red  : Reflective DLL/Payloads }
  COLOR_HEX_OFFSET    = $00808000; { Teal        : Memory Offset Column }
  COLOR_HEX_SELECT    = $00444444; { Highlight   : Block selection }

  { === Process Tree Graph Colors === }
  COLOR_NODE_NORMAL   = $00D4AA33; { Soft Blue   : Legitimate OS Process }
  COLOR_NODE_SUSPECT  = $0000CCFF; { Dark Orange : Suspicious Process }
  COLOR_NODE_MALWARE  = $000000FF; { Bright Red  : Confirmed Malware/Rootkit }
  COLOR_NODE_ORPHAN   = $00808080; { Gray        : Process without Parent }

  COLOR_EDGE_NORMAL   = $00555555; { Gray Line   : Standard thread connection }
  COLOR_EDGE_ALERT    = $000000FF; { Red Line    : Injected/Anomalous connection }

  { === UI Elements & Threat Monitor === }
  COLOR_UI_BORDER     = $00333333; { Dark border for clean separation }
  COLOR_STAT_SAFE     = $0000CC00; { Green       : System OK }
  COLOR_STAT_WARN     = $0000A5FF; { Orange      : TTI Warning }
  COLOR_STAT_CRIT     = $000000FF; { Red         : Exfiltration/Critical Decay }

implementation

end.

