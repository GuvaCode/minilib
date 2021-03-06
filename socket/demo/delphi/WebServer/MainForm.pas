unit MainForm;
{**
 *  This file is part of the "Mini Library"
 *
 * @license   modifiedLGPL (modified of http://www.gnu.org/licenses/lgpl.html)
 *            See the file COPYING.MLGPL, included in this distribution,
 * @author    Zaher Dirkey <zaher, zaherdirkey>
 *}
interface

uses
  Windows, Messages, SysUtils, StrUtils, Classes, Graphics, Controls, Forms, Dialogs,
  Registry, IniFiles, StdCtrls, ExtCtrls, mnConnections, mnSockets, mnServers, mnWebModules;

type
  TMain = class(TForm)
    Memo: TMemo;
    StartBtn: TButton;
    RootEdit: TEdit;
    Label1: TLabel;
    StopBtn: TButton;
    Label2: TLabel;
    PortEdit: TEdit;
    StayOnTopChk: TCheckBox;
    Panel3: TPanel;
    LastIDLabel: TLabel;
    Label4: TLabel;
    Label3: TLabel;
    MaxOfThreadsLabel: TLabel;
    NumberOfThreads: TLabel;
    NumberOfThreadsLbl: TLabel;
    procedure StartBtnClick(Sender: TObject);
    procedure StopBtnClick(Sender: TObject);
    procedure StayOnTopChkClick(Sender: TObject);
    procedure FormCreate(Sender: TObject);
    procedure FormDestroy(Sender: TObject);
  private
    FMax:Integer;
    Server: TmodWebServer;
    procedure UpdateStatus;
    procedure ModuleServerBeforeOpen(Sender: TObject);
    procedure ModuleServerAfterClose(Sender: TObject);
    procedure ModuleServerChanged(Listener: TmnListener);
    procedure ModuleServerLog(const S: string);
  public
  end;

var
  Main: TMain;

implementation

{$R *.DFM}

procedure TMain.StartBtnClick(Sender: TObject);
begin
  Server.Start;
end;

procedure TMain.StopBtnClick(Sender: TObject);
begin
  Server.Stop;
  StartBtn.Enabled := true;
end;

procedure TMain.UpdateStatus;
begin
  NumberOfThreads.Caption := IntToStr(Server.Listener.Count);
  LastIDLabel.Caption := IntToStr(Server.Listener.LastID);
end;

procedure TMain.ModuleServerBeforeOpen(Sender: TObject);
var
  aRoot:string;
begin
  StartBtn.Enabled := False;
  StopBtn.Enabled := True;
  aRoot := RootEdit.Text;
  if (LeftStr(aRoot, 2)='.\') or (LeftStr(aRoot, 2)='./') then
    aRoot := ExtractFilePath(Application.ExeName) + Copy(aRoot, 3, MaxInt);
  Server.WebModule.DocumentRoot := aRoot;
  Server.Port := PortEdit.Text;
end;

function FindCmdLineValue(Switch: string; var Value: string; const Chars: TSysCharSet = ['/', '-']; Seprator: Char = ' '; IgnoreCase: Boolean = true): Boolean;
var
  I: Integer;
  S: string;
begin
  Switch := Switch + Seprator;
  for I := 1 to ParamCount do
  begin
    S := ParamStr(I);
    if (Chars = []) or (S[1] in Chars) then
      if IgnoreCase then
      begin
        if (AnsiCompareText(Copy(S, 2, Length(Switch)), Switch) = 0) then
        begin
          Result := True;
          Value := Copy(S, Length(Switch) + 2, Maxint);
          Exit;
        end;
      end
      else
      begin
        if (AnsiCompareStr(Copy(S, 2, Length(Switch)), Switch) = 0) then
        begin
          Result := True;
          Value := Copy(S, Length(Switch) + 2, Maxint);
          Exit;
        end;
      end;
  end;
  Result := False;
end;

procedure TMain.FormCreate(Sender: TObject);
var
  aIni: TIniFile;
  function GetOption(AName, ADefault:string):string;
  var
    s:string;
  begin
    s := '';
    if FindCmdLineValue(AName, s) then
      Result :=AnsiDequotedStr(s, '"')
    else
      Result := aIni.ReadString('options', AName, ADefault);
  end;

  function GetSwitch(AName, ADefault:string):string;//if found in cmd mean it is true
  var
    s:string;
  begin
    s := '';
    if FindCmdLineValue(AName, s) then
      Result := 'True'
    else
      Result := aIni.ReadString('options',AName, ADefault);
  end;

var
  aAutoRun:Boolean;
begin
  Server := TmodWebServer.Create;
  Server.OnBeforeOpen := ModuleServerBeforeOpen;
  Server.OnAfterClose := ModuleServerAfterClose;
  Server.OnChanged :=  ModuleServerChanged;
  Server.OnLog := ModuleServerLog;
  Server.Logging := True;

  aIni := TIniFile.Create(ExtractFilePath(Application.ExeName) + 'config.ini');
  try
    RootEdit.Text := GetOption('root', '.\html');
    PortEdit.Text := GetOption('port', '81');
    aAutoRun := StrToBoolDef(GetSwitch('run', ''), False);
  finally
    aIni.Free;
  end;
  if aAutoRun then
     Server.Start;
end;

procedure TMain.StayOnTopChkClick(Sender: TObject);
begin
  if StayOnTopChk.Checked then
    SetWindowPos(Handle, HWND_TOPMOST, 0, 0, 0, 0, SWP_NOMOVE or
      SWP_NOSIZE or SWP_NOACTIVATE)
  else
    SetWindowPos(Handle, HWND_NOTOPMOST, 0, 0, 0, 0, SWP_NOMOVE or
      SWP_NOSIZE or SWP_NOACTIVATE);
end;

procedure TMain.FormDestroy(Sender: TObject);
var
  aReg: TRegistry;
begin
  if ParamCount = 0 then
  begin
    aReg := TRegistry.Create;
    aReg.OpenKey('software\miniWebServer\Options', True);
    aReg.WriteString('DocumentRoot', RootEdit.Text);
    aReg.WriteString('Port', PortEdit.Text);
    aReg.Free;
  end
end;

procedure TMain.ModuleServerAfterClose(Sender: TObject);
begin
  StartBtn.Enabled := True;
  StopBtn.Enabled := False;
end;

procedure TMain.ModuleServerChanged(Listener: TmnListener);
begin
  if FMax < Listener.Count then
    FMax := Listener.Count;
  MaxOfThreadsLabel.Caption:=IntToStr(FMax);
  UpdateStatus;
end;

procedure TMain.ModuleServerLog(const s: string);
begin
  Memo.Lines.Add(s);
end;

end.

