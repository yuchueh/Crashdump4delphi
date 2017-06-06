program crashtest;

uses
  Vcl.Forms,
  Vcl.Dialogs,
  System.SysUtils,
  Winapi.Windows,
  untBugReportIntf in '..\untBugReportIntf.pas';

{$R *.res}


procedure artifical_crash;
var
  x: PInteger;
begin
  Sleep(5000);
  x := nil;
  ShowMessage(IntToStr(x^));
end;


begin
  Application.Initialize;
  init_sentinel('');
  artifical_crash;
  Application.MainFormOnTaskbar := True;
  Application.Run;
end.
