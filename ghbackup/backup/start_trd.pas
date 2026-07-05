unit start_trd;

{$mode objfpc}{$H+}

interface

uses
  Classes, Process, SysUtils, ComCtrls, Forms;

type
  StartBackup = class(TThread)
  private

    { Private declarations }
  protected
  var
    Result: TStringList;

    procedure Execute; override;

    procedure ShowLog;
    procedure StartProgress;
    procedure StopProgress;

  end;

implementation

uses Unit1;

{ TRD }

procedure StartBackup.Execute;
var
  ExProcess: TProcess;
begin
  try //Вывод лога и прогресса
    Synchronize(@StartProgress);

    FreeOnTerminate := True; //Уничтожить по завершении
    Result := TStringList.Create;

    //Рабочий процесс
    ExProcess := TProcess.Create(nil);

    //Создаём раздел ${usb}1
    ExProcess.Executable := 'bash';
    ExProcess.Parameters.Add('-c');
    //Группа команд (parted)
    ExProcess.Parameters.Add(command);

    ExProcess.Options := [poUsePipes, poStderrToOutPut];
    //, poWaitOnExit (синхронный вывод)

    ExProcess.Execute;

    //Выводим лог динамически
    while ExProcess.Running do
    begin
      Result.LoadFromStream(ExProcess.Output);

      //Выводим лог
      if Result.Count <> 0 then
        Synchronize(@ShowLog);
    end;

  finally
    Synchronize(@StopProgress);
    Result.Free;
    ExProcess.Free;
    Terminate;
  end;
end;

{ БЛОК ОТОБРАЖЕНИЯ ЛОГА }

//Старт индикатора
procedure StartBackup.StartProgress;
begin
  with MainForm do
  begin
    LogMemo.Text := SStartCloning + ' https://github.com/' + Edit1.Text;
    Application.ProcessMessages;
    ProgressBar1.Style := pbstMarquee;
    ProgressBar1.Refresh;

    Edit1.Enabled := False;
    Edit3.Enabled := False;
    SelDirBtn.Enabled := False;
    CheckBox1.Enabled := False;
    SpinEdit1.Enabled := False;
    BackupBtn.Enabled := False;
  end;
end;

//Стоп индикатора
procedure StartBackup.StopProgress;
begin
  with MainForm do
  begin
    LogMemo.Append('');
    LogMemo.Lines.Append(SCompleted);
    Application.ProcessMessages;
    ProgressBar1.Style := pbstNormal;
    ProgressBar1.Refresh;

    Edit1.Enabled := True;
    Edit3.Enabled := True;
    SelDirBtn.Enabled := True;
    CheckBox1.Enabled := True;
    SpinEdit1.Enabled := True;
    BackupBtn.Enabled := True;
  end;
end;

//Вывод лога
procedure StartBackup.ShowLog;
var
  i: integer;
begin
  //Вывод построчно
  for i := 0 to Result.Count - 1 do
    MainForm.LogMemo.Lines.Append(Result[i]);

  //Промотать список вниз
  MainForm.LogMemo.SelStart := Length(MainForm.LogMemo.Text);
  MainForm.LogMemo.SelLength := 0;

  //Вывод пачками
  //MainForm.LogMemo.Lines.Assign(Result);
end;

end.
