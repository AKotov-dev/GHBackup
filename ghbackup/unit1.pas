unit Unit1;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, Forms, Controls, Graphics, Dialogs, StdCtrls,
  Buttons, ComCtrls, IniPropStorage, Process, DefaultTranslator, LCLType;

type

  { TMainForm }

  TMainForm = class(TForm)
    CheckBox1: TCheckBox;
    Label5: TLabel;
    SelDirBtn: TBitBtn;
    Edit1: TEdit;
    Edit2: TEdit;
    Edit3: TEdit;
    IniPropStorage1: TIniPropStorage;
    Label1: TLabel;
    Label2: TLabel;
    Label3: TLabel;
    Label4: TLabel;
    LogMemo: TMemo;
    ProgressBar1: TProgressBar;
    SelectDirectoryDialog1: TSelectDirectoryDialog;
    BackupBtn: TSpeedButton;
    CancelBtn: TSpeedButton;
    StaticText1: TStaticText;
    UpDown1: TUpDown;
    procedure Edit3Change(Sender: TObject);
    procedure FormKeyUp(Sender: TObject; var Key: word; Shift: TShiftState);
    procedure SelDirBtnClick(Sender: TObject);
    procedure FormCreate(Sender: TObject);
    procedure BackupBtnClick(Sender: TObject);
    procedure CancelBtnClick(Sender: TObject);
    procedure StartProcess(command: string);
  private

  public

  end;

resourcestring
  SWarningMsg = 'Enter Login and Working directory!';
  SStartWarning = 'The working directory will be cleared! Continue?';
  SStartCloning = 'Start cloning';

var
  MainForm: TMainForm;
  command: string;

implementation

uses start_trd;

{$R *.lfm}

{ TMainForm }

//Общая процедура запуска команд (асинхронная)
procedure TMainForm.StartProcess(command: string);
var
  ExProcess: TProcess;
begin
  Application.ProcessMessages;
  ExProcess := TProcess.Create(nil);
  try
    ExProcess.Executable := '/bin/bash';
    ExProcess.Parameters.Add('-c');
    ExProcess.Parameters.Add(command);
    //  ExProcess.Options := ExProcess.Options + [poWaitOnExit];
    ExProcess.Execute;
  finally
    ExProcess.Free;
  end;
end;

//Бэкап
procedure TMainForm.BackupBtnClick(Sender: TObject);
var
  depth: string;
  FStartBackup: TThread;
begin
  //Проверка
  if (Trim(Edit1.Text) = '') or (Trim(Edit2.Text) = '') or
    (not DirectoryExists(Edit3.Text)) then
  begin
    MessageDlg(SWarningMsg, mtWarning, [mbOK], 0);
    Exit;
  end;

  //Глубина бэкапа (по умолчанию - только новейшие исходники без истории)
  if CheckBox1.Checked then depth := '--depth 1'
  else
    depth := '';

  //Создаём однострочную команду (~/.config/ghbackup/start - флаг для выхода из цикла)
  command := '';
  command := '> ~/.config/ghbackup/start; cd "' + Edit3.Text +
    '"; find . -not -name "1-BACKUP" -delete; ' +
    'for name in $(curl -s "https://api.github.com/users/' + Edit1.Text +
    '/repos?per_page=' + Edit2.Text + '" | grep -o ' + '''' + 'git@[^"]*' +
    '''' + ' | cut -f2 -d"/"); do git clone ' + depth + ' "https://github.com/' +
    Edit1.Text + '/$name' +
    '"; [[ -f ~/.config/ghbackup/start ]] || break; done; [[ -f ~/.config/ghbackup/start ]] || '
    + 'exit; tar --exclude="./1-BACKUP" -zcvf ./1-BACKUP/GitHub.tar.gz .';

  if MessageDlg(SStartWarning, mtConfirmation, [mbYes, mbNo], 0) = mrYes then
  begin
    FStartBackup := StartBackup.Create(False);
    FStartBackup.Priority := tpNormal;
  end;
end;

//Отмена клонирования/архивирования
procedure TMainForm.CancelBtnClick(Sender: TObject);
begin
  StartProcess('rm -f ~/.config/ghbackup/start; killall git tar');
end;

//Получить путь к файлу бэкапа
procedure TMainForm.Edit3Change(Sender: TObject);
begin
  Label5.Caption := Edit3.Text + '/1-BACKUP/GitHub.tar.gz';
end;

//ESCAPE - Отмена
procedure TMainForm.FormKeyUp(Sender: TObject; var Key: word; Shift: TShiftState);
begin
  if Key = VK_RETURN then BackupBtn.Click;
  if Key = VK_ESCAPE then CancelBtn.Click;
end;

//Выбор Рабочего каталога
procedure TMainForm.SelDirBtnClick(Sender: TObject);
begin
  if SelectDirectoryDialog1.Execute then
  begin
    Edit3.Text := SelectDirectoryDialog1.FileName;
    if not DirectoryExists(SelectDirectoryDialog1.FileName + '/1-BACKUP') then
      MkDir(SelectDirectoryDialog1.FileName + '/1-BACKUP');

    Label5.Caption := Edit3.Text + '/1-BACKUP/GitHUB.tar.gz';
  end;
end;

procedure TMainForm.FormCreate(Sender: TObject);
begin
  if not DirectoryExists(GetUserDir + '.config') then MkDir(GetUserDir + '.config');
  if not DirectoryExists(GetUserDir + '.config/ghbackup') then
    MkDir(GetUserDir + '.config/ghbackup');

  IniPropStorage1.IniFileName := GetUserDir + '.config/ghbackup/ghbackup.ini';

  SelDirBtn.Width := SelDirBtn.Height;
  MainForm.Caption := Application.Title;
end;


end.