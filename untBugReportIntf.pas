unit untBugReportIntf;

interface

uses
  Vcl.Dialogs, System.SysUtils, Winapi.Windows;

const crash_id = 'ca_crash';
const mmf_name = 'ca_crash_mmf';
const BUF_SIZE = 256;

type
  PEXCEPTION_POINTERS = ^EXCEPTION_POINTERS;

  PCrash_data = ^TCrash_data;
  TCrash_data = record
    excp_ptrs: PEXCEPTION_POINTERS;
    thread_id: Cardinal;
    proc_id: Cardinal;
  end;

var
  g_crash_event: Cardinal;
  map_file: Cardinal;
  g_mmf: Pointer;
  info: STARTUPINFOW;
  processInfo: PROCESS_INFORMATION;

  function init_sentinel(dumplevel: string = 'normal'): Boolean;

implementation

var
  bHasInited: Boolean = False;

function DebugHelpExceptionFilter(const ExceptionInfo: TExceptionPointers): Longint; stdcall;
var
  d: PCrash_data;
begin
  // collect the data for the sentinel
  New(d);
  try
    d.excp_ptrs := @ExceptionInfo;
    d.thread_id := GetCurrentThreadId();
    d.proc_id := GetCurrentProcessId();

    CopyMemory(g_mmf, d, SizeOf(TCrash_data));

    // signal to the sentinel that the mmf has data
    SetEvent(g_crash_event);
    // wait until the sentinel finishes
    WaitForSingleObject(g_crash_event, INFINITE);
  finally
    Dispose(d);
  end;
  Result := 1;  //1 = EXCEPTION_EXECUTE_HANDLER 表示我已经处理了异常,可以优雅地结束了
  //EXCEPTION_CONTINUE_SEARCH equ 0 表示我不处理,其他人来吧,于是windows调用默认的处理程序显示一个错误框,并结束
  //Result := -1;//EXCEPTION_CONTINUE_EXECUTION equ -1 表示错误已经被修复,请从异常发生处继续执行
end;

function init_sentinel(dumplevel: string = 'normal'): Boolean;
var
  sBgExe: string;
  sCmd: string;
begin
  Result := bHasInited;
  if Result then Exit;

  // create synchronization event
  g_crash_event := CreateEventW(nil, FALSE, FALSE, crash_id);
  if (g_crash_event = 0) then
  begin
    MessageDlg('Could not initialize crash event object.', mtError, [mbOK], 0);
    Exit;
  end;
  map_file := CreateFileMappingW(INVALID_HANDLE_VALUE, nil, PAGE_READWRITE, 0,
                         BUF_SIZE, mmf_name);
  if (map_file = 0) then
  begin
    MessageDlg('Could not open MMF (' + crash_id + ')', mtError, [mbOK], 0);
    Exit;
  end;

  g_mmf := MapViewOfFile(map_file, FILE_MAP_ALL_ACCESS, 0, 0, BUF_SIZE);
  // start s
  ZeroMemory(@info, SizeOf(STARTUPINFOW));
  sBgExe := ExtractFilePath(ParamStr(0)) + 'bugreport.exe';
  if Trim(dumplevel) = ''  then
    dumplevel := 'normal';

  sCmd := sBgExe + ' ' + crash_id + ' ' +  mmf_name + ' ' + dumplevel;
  if CreateProcess(PWideChar(sBgExe), PWideChar(sCmd), nil, nil,
                     TRUE, CREATE_NEW_CONSOLE, nil, nil, &info,
                     processInfo) then
  begin
    SetUnhandledExceptionFilter(@DebugHelpExceptionFilter);
    bHasInited := True;
    Result := bHasInited;
  end;
end;

end.
