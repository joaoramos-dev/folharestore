unit Unit2;

interface
uses
  Winapi.Windows, Winapi.Messages, System.SysUtils, System.Variants, System.Classes, System.IOUtils,
  Vcl.Graphics, Vcl.Controls, Vcl.Forms, Vcl.Dialogs, Vcl.StdCtrls, Vcl.ExtCtrls,
  Vcl.CheckLst, ShellAPI, Vcl.Imaging.pngimage, FireDAC.Stan.Intf,
  FireDAC.Stan.Option, FireDAC.Stan.Error, FireDAC.UI.Intf, FireDAC.Phys.Intf,
  FireDAC.Stan.Def, FireDAC.Stan.Pool, FireDAC.Stan.Async, FireDAC.Phys,
  FireDAC.Phys.PG, FireDAC.Phys.PGDef, FireDAC.VCLUI.Wait, Data.DB,
  FireDAC.Comp.Client, Vcl.DBCtrls, FireDAC.Stan.Param, FireDAC.DatS,
  FireDAC.DApt.Intf, FireDAC.DApt, FireDAC.Comp.DataSet;
type
  TForm2 = class(TForm)
    Edservidor: TEdit;
    Edusuario: TEdit;
    Edsenha: TEdit;
    Lservidor: TLabel;
    Lusuariopg: TLabel;
    lsenhapg: TLabel;
    odcaminho: TOpenDialog;
    Button1: TButton;
    Lnmbase: TLabel;
    Edporta: TEdit;
    LPortapg: TLabel;
    CheckListBox1: TCheckListBox;
    Button2: TButton;
    Edcaminhobkp: TEdit;
    Ltitulocaminhobkp: TLabel;
    Button3: TButton;
    Image1: TImage;
    Shape1: TShape;
    FDConnection1: TFDConnection;
    Button4: TButton;
    ComboBox1: TComboBox;
    FDQuery1: TFDQuery;
    FDPhysPgDriverLink1: TFDPhysPgDriverLink;
    procedure Button1Click(Sender: TObject);
    procedure Button3Click(Sender: TObject);
    procedure Button2Click(Sender: TObject);
    procedure Image1Click(Sender: TObject);
    procedure Button4Click(Sender: TObject);
  private
    { Private declarations }
    procedure CriarDatabase;
    procedure ExecutarRestore;
    procedure ListarDatabases;
  public
    { Public declarations }
  end;
var
  Form2: TForm2;
implementation
{$R *.dfm}
function RemoveTrailingSlash(const Path: string): string;
begin
  if (Length(Path) > 0) and (Path[Length(Path)] in ['\', '/']) then
    Result := Copy(Path, 1, Length(Path) - 1)
  else
    Result := Path;
end;
procedure TForm2.ListarDatabases;
begin
  try
    FDConnection1.Params.DriverID := 'PG';
    FDConnection1.Params.Database := 'postgres';
    FDConnection1.Params.UserName := Edusuario.Text;
    FDConnection1.Params.Password := Edsenha.Text;
    FDConnection1.Params.Add('Server=' + Edservidor.Text);
    FDConnection1.Params.Add('Port=' + Edporta.Text);
    FDConnection1.Connected := True;
    FDQuery1.SQL.Text := 'SELECT datname FROM pg_database WHERE datistemplate = false and datname <> ''postgres'';';
    FDQuery1.Open;
    ComboBox1.Items.Clear;
    while not FDQuery1.Eof do
    begin
      ComboBox1.Items.Add(FDQuery1.FieldByName('datname').AsString);
      FDQuery1.Next;
    end;
  finally
    FDQuery1.Close;
    FDConnection1.Connected := False;
  end;
end;
procedure TForm2.Button4Click(Sender: TObject);
begin
  try
    FDConnection1.Params.DriverID := 'PG';
    FDConnection1.Params.Database := ComboBox1.Text;
    FDConnection1.Params.UserName := Edusuario.Text;
    FDConnection1.Params.Password := Edsenha.Text;
    FDConnection1.Params.Add('Server=' + Edservidor.Text);
    FDConnection1.Params.Add('Port=' + Edporta.Text);
    FDConnection1.Connected := True;
      if FDConnection1.Connected then
    begin
      Button4.Caption := 'Conectado';
      Button4.Enabled := False;
    end;
  except
    on E: Exception do
    begin
      ShowMessage('Erro ao conectar ao banco: ' + E.Message);
    end;
  end;
end;
procedure TForm2.CriarDatabase;
var
  NewDatabase: string;
begin
  NewDatabase := ComboBox1.Text;
  try
    FDConnection1.Params.Database := 'postgres';
    FDConnection1.Connected := True;
    try
      FDQuery1.SQL.Text := 'DO $$ ' +
                           'BEGIN ' +
                           '   IF NOT EXISTS (SELECT FROM pg_catalog.pg_roles WHERE rolname = ''sageuser'') THEN ' +
                           '       CREATE ROLE sageuser LOGIN PASSWORD ''#abc123#''; ' +
                           '   END IF; ' +
                           'END $$;';
      FDQuery1.ExecSQL;
      ShowMessage('Usuário "sageuser" criado com sucesso ou já existente.');
    except
      on E: EFDDBEngineException do
        ShowMessage('Erro ao criar usuário "sageuser": ' + E.Message);
    end;
    try
      FDConnection1.ExecSQL('CREATE DATABASE "' + NewDatabase + '";');
      ComboBox1.Items.Add(NewDatabase);
      ShowMessage('Database "' + NewDatabase + '" criada com sucesso.');
    except
      on E: EFDDBEngineException do
      begin
        if E.Kind = ekUKViolated then
          ShowMessage('Database "' + NewDatabase + '" já existe.')
        else
          raise;
      end;
    end;
  finally
    FDConnection1.Connected := False;
  end;
end;
procedure TForm2.ExecutarRestore;
var
  i: Integer;
  comandoRestore: string;
  backupList: string;
begin
  backupList := '';
  for i := 0 to CheckListBox1.Items.Count - 1 do
  begin
    if CheckListBox1.Checked[i] then
    begin
      if backupList <> '' then
        backupList := backupList + ' ';
      backupList := backupList + '"' + Edcaminhobkp.Text + '\' + CheckListBox1.Items[i] + '"';
    end;
  end;
  if backupList = '' then
  begin
    ShowMessage('Nenhum backup selecionado para restaurar.');
    Exit;
  end;
  comandoRestore := '/K cd /d "C:\Program Files\PostgreSQL\11\bin" && ' +
    'for %a in (' + backupList + ') do ' +
    '"C:\Program Files\PostgreSQL\11\bin\pg_restore.exe" --host ' + Edservidor.Text +
    ' --port ' + Edporta.Text +
    ' --username ' + Edusuario.Text + ' --dbname "' + ComboBox1.Text + '"' +
    ' --verbose %a';
  if ShellExecute(Handle, 'open', 'cmd.exe', PChar(comandoRestore), nil, SW_SHOW) <= 32 then
    ShowMessage('Erro ao executar o comando de restauração.');
end;
procedure TForm2.Button1Click(Sender: TObject);
var
  i: Integer;
  CaminhoPasta: string;
begin
  odcaminho.Options := [ofAllowMultiSelect];
  odcaminho.Title := 'Selecione os arquivos de backup';
  odcaminho.Filter := 'Arquivos de Backup (*.backup)|*.backup|Todos os arquivos (*.*)|*.*';
  if odcaminho.Execute then
  begin
    CheckListBox1.Clear;
    if odcaminho.Files.Count > 0 then
    begin
      CaminhoPasta := ExtractFilePath(odcaminho.Files[0]);
      CaminhoPasta := RemoveTrailingSlash(CaminhoPasta);
      Edcaminhobkp.Text := CaminhoPasta;
      for i := 0 to odcaminho.Files.Count - 1 do
      begin
        CheckListBox1.Items.Add(ExtractFileName(odcaminho.Files[i]));
        CheckListBox1.Checked[CheckListBox1.Items.Count - 1] := True;
      end;
    end;
  end;
end;
procedure TForm2.Button2Click(Sender: TObject);
begin
  ExecutarRestore;
end;
procedure TForm2.Button3Click(Sender: TObject);
begin
  CriarDatabase;
end;

procedure TForm2.Image1Click(Sender: TObject);
begin
  ShowMessage('Passo a Passo:' + #13#10 + #13#10 +
  '1- Preencha primeiramente os campos de CONEXÃO DO SERVIDOR.' + #13#10 + #13#10 +
  '2- Caso não tenha criado a base de dados, dê um nome à sua base e, em seguida, clique em CRIAR DATABASE.' + #13#10 + #13#10 +
  '3- Clique em SELEÇÃO DE BACKUPS para que possa selecionar os backups do Folhamatic.' + #13#10 + #13#10 +
  '4- Clique em RESTAURAR para iniciar a restauração dos backups.' + #13#10 + #13#10 +
  '5- Verifique se o usuário SAGEUSER foi criado pela ferramenta, pois pode ocorrer de usuário POSTGRES não restaurar tudo.' + #13#10 + #13#10 +
  '6- Caso o usuário POSTGRES não restaure tudo, altere o usuário para o SAGEUSER.' + #13#10 + #13#10 +
  '7- Esta ferramenta somente funciona no PostgreSQL 11 devido ao backup do FolhaMatic ser feito nesta versão ou anterior.' + #13#10 + #13#10 +
  'Criado por Soares.imp.pack & Joaoramos.imp.pack :)');
end;

end.

