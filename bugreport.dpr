program bugreport;

uses
  Vcl.Forms,
  Vcl.Dialogs,
  Winapi.Windows,
  System.SysUtils,
  untBugReport in 'untBugReport.pas' {frmBugReport},
  untDbgHlp in 'untDbgHlp.pas';

{%R *.res}

const BUF_SIZE = 256;

type

  PCrash_data = ^TCrash_data;
  TCrash_data = record
    excp_ptrs: PEXCEPTION_POINTERS;
    thread_id: Cardinal;
    proc_id: Cardinal;
  end;

var
  event_name: string;
  mmf_name: string;
  map_file: Cardinal;
  mmf: Pointer;
  crash_event: Cardinal;
  data: PCrash_data;
  dumplevel: string = 'normal';

function make_minidump(d: Pcrash_data): Boolean;
var
  dump_file: Cardinal;
  name: string;
  proc_handle: Cardinal;
  thread_handle: Cardinal;
  mdt: MINIDUMP_TYPE;
  exceptionInfo: PMINIDUMP_EXCEPTION_INFORMATION;
begin
  Result := False;
  name := 'crash_dump_' + FormatDateTime('yyyymmdd_hhMMss', Now) + '.dmp';
  dump_file := CreateFile(PWideChar(name), GENERIC_WRITE, FILE_SHARE_READ, nil,
                               CREATE_ALWAYS, FILE_ATTRIBUTE_NORMAL, 0);
  if dump_file = INVALID_HANDLE_VALUE then
  begin
    MessageDlg('CreateFile:' + name + ' invalid handle', mtError, [mbOK], 0);
    Exit;
  end;
  try
    proc_handle := OpenProcess(PROCESS_ALL_ACCESS, TRUE, d.proc_id);
    thread_handle := OpenThread(THREAD_ALL_ACCESS, TRUE, d.thread_id);

    if SameText(dumplevel, 'normal') then
      mdt := MiniDumpNormal
    else
      mdt := MiniDumpWithFullMemory or MiniDumpWithFullMemoryInfo or
                        MiniDumpWithHandleData or MiniDumpWithThreadInfo or
                        MiniDumpWithUnloadedModules;

    New(exceptionInfo);
    try
      exceptionInfo.ThreadId := d.thread_id;
      exceptionInfo.ExceptionPointers := d.excp_ptrs;
      exceptionInfo.ClientPointers := TRUE;

      Result := MiniDumpWriteDump(proc_handle, d.proc_id, dump_file, mdt, exceptionInfo, nil, nil);
    finally
      Dispose(exceptionInfo);
    end;
  finally
    CloseHandle(dump_file);
  end;
end;

var
  bMakeSucc: Boolean = False;

begin
  Application.Initialize;

  if ParamCount <> 3 then
  begin
    MessageDlg('USAGE: ' + ExtractFileName(ParamStr(0)) + ' [name of the event] [name of the MMF] [dumpLevel default normal]',
      mtError, [mbOK], 0);
    Exit;
  end;

  event_name := ParamStr(1);
  mmf_name := ParamStr(2);
  dumplevel := ParamStr(3);
  // open shared memory
  map_file := OpenFileMappingW(FILE_MAP_ALL_ACCESS, FALSE, PWideChar(mmf_name));
  if map_file = 0 then
  begin
    MessageDlg('Could not open MMF (' + mmf_name + ').', mtError, [mbOK], 0);
    Exit;
  end;

  mmf := MapViewOfFile(map_file, FILE_MAP_ALL_ACCESS, 0, 0, BUF_SIZE);

  // open crash event
  crash_event := OpenEventW(EVENT_ALL_ACCESS, FALSE, PWideChar(event_name));
  try
    if crash_event = 0 then
    begin
      MessageDlg('Could not open named event (' + event_name + ').', mtError, [mbOK], 0);
      Exit;
    end;
    // ... and wait
    WaitForSingleObject(crash_event, INFINITE);

    // if we are here, we got the crash signal from the other process
    // (which also means that the MMF contains the crash info we
    // need)
    data := PCrash_data(mmf);
    bMakeSucc := make_minidump(data);
  finally
    // signal that writing the crash dump was finished.
    SetEvent(crash_event);
  end;

  if bMakeSucc then
  begin
    //Application.MainFormOnTaskbar := True;
    //Application.CreateForm(TfrmBugReport, frmBugReport);
  end else
  begin
    MessageDlg('Could not make_minidump ', mtError, [mbOK], 0);
  end;
  Application.Run;
end.
