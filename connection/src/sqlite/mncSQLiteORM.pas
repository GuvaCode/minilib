unit mncSQLiteORM;
{**
 *  This file is part of the "Mini Connections"
 *
 * @license   modifiedLGPL modified of http://www.gnu.org/licenses/lgpl.html
 *            See the file COPYING.MLGPL, included in this distribution,
 * @author    Zaher Dirkey <zaher at parmaja dot com>
 *}
{
  TODO:
    use foUnique
}
{$IFDEF FPC}
{$mode delphi}
{$ENDIF}
{$H+}{$M+}

interface

uses
  SysUtils, Classes, mnUtils, Variants, mncORM;

type

  { TmncORMSQLite }

  TmncORMSQLite = class(TmncORM)
  protected
    type

      { TDatabaseSQLite }

      TDatabaseSQLite = class(TormHelper)
      public
        function CreateSQL(AObject: TormSQLObject; SQL: TCallbackObject; vLevel: Integer): Boolean; override;
      end;

      { TSchemaSQLite }

      TSchemaSQLite = class(TormHelper)
      public
        function CreateSQL(AObject: TormSQLObject; SQL: TCallbackObject; vLevel: Integer): Boolean; override;
      end;

      { TTableSQLite }

      TTableSQLite = class(TormTableHelper)
      public
        function CreateSQL(AObject: TormSQLObject; SQL: TCallbackObject; vLevel: Integer): Boolean; override;
      end;

      { TFieldsSQLite }

      TFieldsSQLite = class(TormHelper)
      public
        function CreateSQL(AObject: TormSQLObject; SQL: TCallbackObject; vLevel: Integer): Boolean; override;
      end;

      { TFieldSQLite }

      TFieldSQLite = class(TormHelper)
      public
        function CreateSQL(AObject: TormSQLObject; SQL: TCallbackObject; vLevel: Integer): Boolean; override;
      end;

      { TInsertDataSQLite }

      TInsertDataSQLite = class(TormHelper)
      public
        function CreateSQL(AObject: TormSQLObject; SQL: TCallbackObject; vLevel: Integer): Boolean; override;
      end;
  protected
    class function FieldTypeToString(FieldType:TormFieldType; FieldSize: Integer): String;
    procedure Created; override;
  public
  end;

implementation

{ TmncORMSQLite.TInsertDataSQLite }

function TmncORMSQLite.TInsertDataSQLite.CreateSQL(AObject: TormSQLObject; SQL: TCallbackObject; vLevel: Integer): Boolean;
var
  o: TormObject;
  i: Integer;
begin
  i := 0;
  with AObject as TInsertData do
  begin
    SQL.Add('insert into ' + Table.QuotedSQLName + '(' );
    for o in this do
    begin
      if i > 0 then
        SQL.Add(',', []);
      SQL.Add(Table.Prefix + (o as TFieldValue).Name); //todo need to use genname
      Inc(i);
    end;
    SQL.Add(') values (');

    i := 0;
    for o in this do
    begin
      if i > 0 then
        SQL.Add(',', []);
      SQL.Add(ValueToStr((o as TFieldValue).Value));
      Inc(i);
    end;
    SQL.Add(')', [cboEndChunk, cboEndLine]);
  end;
  Result := True;
end;

{ TmncORMSQLite.TFieldsSQLite }

function TmncORMSQLite.TFieldsSQLite.CreateSQL(AObject: TormSQLObject; SQL: TCallbackObject; vLevel: Integer): Boolean;
var
  o: TormObject;
  i: Integer;
begin
  i := 0;
  for o in AObject do
  begin
    if i > 0 then //not first line
      SQL.Add(',', [cboEndLine]);
    (o as TormSQLObject).GenerateSQL(SQL, vLevel);
    Inc(i);
  end;
  Result := True;
end;

{ TmncORMSQLite.TFieldSQLite }

function TmncORMSQLite.TFieldSQLite.CreateSQL(AObject: TormSQLObject; SQL: TCallbackObject; vLevel: Integer): Boolean;
var
  fs: Integer;
begin
//  vSQL.Add(LevelStr(vLevel) + Name + ' as Integer'); bug in fpc needs to reproduce but i can
  with AObject as TField do
  begin
    fs := FieldSize;
    if fs = 0 then
      fs := 60;
    SQL.Add(LevelStr(vLevel) + QuotedSQLName + ' '+ FieldTypeToString(FieldType, fs));
    if (foNotNull in Options) or (foPrimary in Options) then
      SQL.Add(' not null');
    if Root.Impact then
    begin
      if (foPrimary in Options) then
        SQL.Add(' primary key');
      if (foSequenced in Options) then
        SQL.Add(' autoincrement');
    end;
    if not VarIsEmpty(DefaultValue) then
    begin
      if VarType(DefaultValue) = varString then
        SQL.Add(' default ''' + DefaultValue + '''')
      else
        SQL.Add(' default ' + VarToStr(DefaultValue));
    end;
  end;
  Result := True;
end;

{ TmncORMSQLite.TTableSQLite }

function TmncORMSQLite.TTableSQLite.CreateSQL(AObject: TormSQLObject; SQL: TCallbackObject; vLevel: Integer): Boolean;
var
  i: integer;
  o: TormObject;
  Field: TField;
  Keys: string;
  IndexList: TStringList;
  IndexName, IndexFields: string;
  S: string;
begin
  Result := True;
  with AObject as TTable do
  begin

    SQL.Add(LevelStr(vLevel) + 'create table ' + QuotedSQLName);
    SQL.Add('(', [cboEndLine]);
    SQL.Params.Values['Table'] := SQLName;
    Fields.GenerateSQL(SQL, vLevel + 1);

    IndexList := TStringList.Create;
    try
      //collect primary keys and indexes
      Keys := '';
      for o in Fields do
      begin
        Field := o as TField;
        if Field.Primary then
        begin
          if Keys <> '' then
            Keys := Keys + ', ';
          Keys := Keys + Field.QuotedSQLName;
        end
        else if (Field.Indexed) or (Field.Index <> '') then
        begin
          if (Field.Index <> '') then
            IndexName := Field.Index
          else
            if not Root.UsePrefexes then //Yes, if not using prefix we will force use it here
              IndexName :=  'Idx_' + Prefix + Field.SQLName
            else
              IndexName :=  'Idx_' + Field.SQLName;

          IndexFields := IndexList.Values[IndexName];
          if IndexFields <> '' then
            IndexFields := IndexFields + ' ,';
          IndexFields := IndexFields + Field.SQLName;
          IndexList.Values[IndexName] := IndexFields;
        end;
      end;

      if Keys <> '' then
      begin
        SQL.Add(',', [cboEndLine]);
        SQL.Add(LevelStr(vLevel + 1) + 'primary key (' + Keys + ')', []);
      end;

      for o in Fields do
      begin
        Field := o as TField;
        if Field.ReferenceInfo.Table <> nil then
        begin
          SQL.Add(',', [cboEndLine]);
          S := 'foreign key Ref_' + SQLName + Field.ReferenceInfo.Table.Name + Field.ReferenceInfo.Field.Name + '(' + Field.QuotedSQLName + ')'
                  +' references ' + Field.ReferenceInfo.Table.QuotedSQLName + '(' + Field.ReferenceInfo.Field.QuotedSQLName + ')';

          if rfoRestrict = Field.ReferenceInfo.DeleteOptions then
            S := S + ' on delete restrict'
          else if rfoCascade = Field.ReferenceInfo.DeleteOptions then
            S := S + ' on delete cascade'
          else if rfoSetNull = Field.ReferenceInfo.DeleteOptions then
            S := S + ' on delete set null';

          if rfoRestrict = Field.ReferenceInfo.UpdateOptions then
            S := S + ' on update restrict'
          else if rfoCascade = Field.ReferenceInfo.UpdateOptions then
            S := S + ' on update cascade'
          else if rfoSetNull = Field.ReferenceInfo.UpdateOptions then
            S := S + ' on update set null';

          SQL.Add(LevelStr(vLevel + 1) + S , []);
        end;
      end;

      SQL.Add('', [cboEndLine]);
      SQL.Add(')', [cboEndLine]);
      SQL.Add('', [cboEndChunk]);
      SQL.Params.Values['Table'] := '';


      if IndexList.Count > 0 then
      begin
        for i := 0 to IndexList.Count -1 do
        begin
          IndexName := IndexList.Names[i];
          IndexFields := IndexList.ValueFromIndex[i];
          SQL.Add(LevelStr(vLevel) + 'create index ' + IndexName + ' on ' + SQLName + '(' + IndexFields + ')');
  //        SQL.Add('', [cboEndLine]);
          SQL.Add('', [cboEndChunk]);
        end;
      end;
    finally
      FreeAndNil(IndexList);
    end;
  end;
end;

{ TmncORMSQLite.TDatabaseSQLite }

function TmncORMSQLite.TDatabaseSQLite.CreateSQL(AObject: TormSQLObject; SQL: TCallbackObject; vLevel: Integer): Boolean;
begin
  GenerateObjects(AObject, SQL, vLevel);
  Result := True;
end;

{ TmncORMSQLite.SchemaSQLite }

function TmncORMSQLite.TSchemaSQLite.CreateSQL(AObject: TormSQLObject; SQL: TCallbackObject; vLevel: Integer): Boolean;
begin
  GenerateObjects(AObject, SQL, vLevel);
  Result := True;
end;

{ TmncORMSQLite }

class function TmncORMSQLite.FieldTypeToString(FieldType: TormFieldType; FieldSize: Integer): String;
begin
  case FieldType of
    ftString: Result := 'varchar('+IntToStr(FieldSize)+')';
    ftBoolean: Result := 'boolean';
    ftSmallInteger: Result := 'smllint';
    ftInteger: Result := 'integer';
    ftBigInteger: Result := 'bigint';
    ftCurrency: Result := 'decimal(12, 4)';
    ftFloat: Result := 'float';
    ftDate: Result := 'date';
    ftTime: Result := 'time';
    ftDateTime: Result := 'datetime';
    ftText: Result := 'text';
    ftBlob: Result := 'text';
  end;
end;

procedure TmncORMSQLite.Created;
begin
  inherited Created;
  Register(TDatabase ,TDatabaseSQLite);
  Register(TSchema, TSchemaSQLite);
  Register(TTable, TTableSQLite);
  Register(TFields, TFieldsSQLite);
  Register(TField, TFieldSQLite);
  Register(TInsertData, TInsertDataSQLite);
end;

end.

