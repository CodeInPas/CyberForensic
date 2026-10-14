program CyberForensic;

{$mode objfpc}{$H+}

uses
  {$IFDEF UNIX}
  cthreads,
  {$ENDIF}
  {$IFDEF HASAMIGA}
  athreads,
  {$ENDIF}
  Interfaces,
  Forms,
  ufrmMain, UnitAbout;

{$R *.res}

begin
  RequireDerivedFormResource := True;
  Application.Title:='CYBER-FORENSIC: Live Volatility';
  Application.Scaled:=True;
  Application.Initialize;
  Application.CreateForm(TfrmMain, frmMain);
  Application.CreateForm(TFormAbout, FormAbout);
  Application.Run;
end.

