unit uSQLiteManager;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, sqldb, sqlite3conn;

type
  { TSQLiteManager: Handles both In-Memory and persistent SQLite connections }
  TSQLiteManager = class
  private
    FConnection: TSQLite3Connection;
    FTransaction: TSQLTransaction;
  public
    constructor Create;
    destructor Destroy; override;

    { Use ':memory:' for real-time simulation metrics, or filepath for persistent saves }
    function Connect(const ADatabaseName: String = ':memory:'): Boolean;
    procedure Disconnect;

    { Transaction controls for high-speed bulk inserts }
    procedure BeginTransaction;
    procedure CommitTransaction;
    procedure RollbackTransaction;

    { Query Execution }
    function ExecuteDirect(const ASQL: String): Boolean;
    function FetchData(const ASQL: String): TSQLQuery;
  end;

implementation

{ TSQLiteManager }

constructor TSQLiteManager.Create;
begin
  FConnection := TSQLite3Connection.Create(nil);
  FTransaction := TSQLTransaction.Create(nil);

  FConnection.Transaction := FTransaction;

  { Menggunakan KeepConnection untuk menghindari overhead buka/tutup koneksi
    berulang-ulang pada game loop }
  FConnection.KeepConnection := True;
end;

destructor TSQLiteManager.Destroy;
begin
  Disconnect;
  FTransaction.Free;
  FConnection.Free;
  inherited Destroy;
end;

function TSQLiteManager.Connect(const ADatabaseName: String): Boolean;
var
  DBDir: String;
begin
  Result := False;
  try
    Disconnect;

    { Jika menggunakan database fisik, pastikan foldernya terbentuk otomatis }
    if ADatabaseName <> ':memory:' then
    begin
      DBDir := ExtractFilePath(ADatabaseName);
      if (DBDir <> '') and not DirectoryExists(DBDir) then
        ForceDirectories(DBDir);
    end;

    FConnection.DatabaseName := ADatabaseName;
    FConnection.Open;

    { Execute PRAGMAs for maximum SQLite performance }
    ExecuteDirect('PRAGMA synchronous = NORMAL;');
    //ExecuteDirect('PRAGMA journal_mode = WAL;');
    //ExecuteDirect('PRAGMA temp_store = MEMORY;');
    ExecuteDirect('PRAGMA cache_size = -64000;'); { 64MB cache }

    Result := FConnection.Connected;
  except
    on E: Exception do
      Result := False;
  end;
end;

procedure TSQLiteManager.Disconnect;
begin
  if FConnection.Connected then
  begin
    if FTransaction.Active then
      FTransaction.Commit;
    FConnection.Close;
  end;
end;

procedure TSQLiteManager.BeginTransaction;
begin
  if not FTransaction.Active then
    FTransaction.StartTransaction;
end;

procedure TSQLiteManager.CommitTransaction;
begin
  if FTransaction.Active then
    FTransaction.Commit;
end;

procedure TSQLiteManager.RollbackTransaction;
begin
  if FTransaction.Active then
    FTransaction.Rollback;
end;

function TSQLiteManager.ExecuteDirect(const ASQL: String): Boolean;
begin
  Result := False;
  if not FConnection.Connected then Exit;

  try
    FConnection.ExecuteDirect(ASQL);
    Result := True;
  except
    Result := False;
  end;
end;

function TSQLiteManager.FetchData(const ASQL: String): TSQLQuery;
begin
  Result := nil;
  if not FConnection.Connected then Exit;

  Result := TSQLQuery.Create(nil);
  try
    Result.DataBase := FConnection;
    Result.Transaction := FTransaction;
    Result.SQL.Text := ASQL;

    { Untuk TSQLQuery, kita bisa menambahkan opsi AutoCommit jika diperlukan }
    Result.Options := Result.Options + [sqoKeepOpenOnCommit, sqoAutoCommit];

    Result.Open;
  except
    Result.Free;
    Result := nil;
  end;
end;

end.
