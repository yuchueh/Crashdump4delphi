unit untBugReport;

interface

uses
  Winapi.Windows, Winapi.Messages, System.SysUtils, System.Variants, System.Classes, Vcl.Graphics,
  Vcl.Controls, Vcl.Forms, Vcl.Dialogs;

type
  TfrmBugReport = class(TForm)
    procedure FormCreate(Sender: TObject);
  private
    { Private declarations }
  public
    { Public declarations }
  end;

var
  frmBugReport: TfrmBugReport;

implementation

{$R *.dfm}

procedure TfrmBugReport.FormCreate(Sender: TObject);
var
 a: THandle;
begin

end;

end.
