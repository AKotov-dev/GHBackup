unit Unit1;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, Forms, Controls, Graphics, Dialogs, StdCtrls, Buttons,
  ComCtrls, IniPropStorage, Process, DefaultTranslator, LCLType, Spin, ExtCtrls;

type

  { TMainForm }

  TMainForm = class(TForm)
    CheckBox1: TCheckBox;
    Image1: TImage;
    Label5: TLabel;
    SelDirBtn: TBitBtn;
    Edit1: TEdit;
    Edit3: TEdit;
    IniPropStorage1: TIniPropStorage;
    Label1: TLabel;
    Label3: TLabel;
    Label4: TLabel;
    LogMemo: TMemo;
    ProgressBar1: TProgressBar;
    SelectDirectoryDialog1: TSelectDirectoryDialog;
    BackupBtn: TSpeedButton;
    CancelBtn: TSpeedButton;
    SpinEdit1: TSpinEdit;
    StaticText1: TStaticText;
    procedure CheckBox1Change(Sender: TObject);
    procedure Edit3Change(Sender: TObject);
    procedure FormCloseQuery(Sender: TObject; var CanClose: boolean);
    procedure FormKeyUp(Sender: TObject; var Key: word; Shift: TShiftState);
    procedure FormShow(Sender: TObject);
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
  SWarningClose = 'Backup is running! Cancel?';
  SCompleted = 'Backup completed...';

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
  if (Trim(Edit1.Text) = '') or (not DirectoryExists(Edit3.Text)) then
  begin
    MessageDlg(SWarningMsg, mtWarning, [mbOK], 0);
    Exit;
  end;

  //Глубина бэкапа (по умолчанию = 1 - только новейшие исходники без истории)

  if CheckBox1.Checked then depth := '--depth=' + SpinEdit1.Text
  else
    depth := '';

  //Создаём однострочную команду (~/.config/ghbackup/start - флаг для выхода из цикла)
  command := '';
  command := '> ~/.config/ghbackup/start; cd "' + Edit3.Text +
    '"; mkdir -p ./1-BACKUP; find . -not -name "1-BACKUP" -delete; ' +
    'page=1; while :; do repos=$(curl -fsS -H "User-Agent: ghbackup" "https://api.github.com/users/'
    + Edit1.Text + '/repos?per_page=100&page=$page" | grep -o ' +
    '''' + 'https://github.com/[^"]*\.git' + '''' + ');' +
    '[ -z "$repos" ] && break;  for repo in $repos; do git clone ' +
    depth + ' "$repo"; ' +
    '[[ -f ~/.config/ghbackup/start ]] || break 2; done; page=$((page+1)); done; ' +
    '[[ -f ~/.config/ghbackup/start ]] || exit; tar --exclude="./1-BACKUP" -zcvf ./1-BACKUP/GitHub.tar.gz .';

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

procedure TMainForm.CheckBox1Change(Sender: TObject);
begin
  SpinEdit1.Enabled := CheckBox1.Checked;
end;

procedure TMainForm.FormCloseQuery(Sender: TObject; var CanClose: boolean);
begin
  //Если идёт Бэкап...
  if not BackupBtn.Enabled then
    if MessageDlg(SWarningClose, mtWarning, [mbYes, mbNo], 0) = mrYes then
    begin
      CancelBtn.Click;
      CanClose := True;
    end
    else
      Canclose := False;
end;

//ESCAPE - Отмена
procedure TMainForm.FormKeyUp(Sender: TObject; var Key: word; Shift: TShiftState);
begin
  if (Key = VK_RETURN) and (BackupBtn.Enabled) then BackupBtn.Click;
  if Key = VK_ESCAPE then CancelBtn.Click;
end;

procedure TMainForm.FormShow(Sender: TObject);
begin
  IniPropStorage1.Restore;
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
var
  bmp: TBitmap;
begin
  if not DirectoryExists(GetUserDir + '.config/ghbackup') then
    ForceDirectories(GetUserDir + '.config/ghbackup');

  IniPropStorage1.IniFileName := GetUserDir + '.config/ghbackup/ghbackup.ini';

  // Устраняем баг иконки приложения
  bmp := TBitmap.Create;
  try
    bmp.PixelFormat := pf32bit;
    bmp.Assign(Image1.Picture.Graphic);
    Application.Icon.Assign(bmp);
  finally
    bmp.Free;
  end;

  SelDirBtn.Width := SelDirBtn.Height;
  MainForm.Caption := Application.Title;
end;


end.
