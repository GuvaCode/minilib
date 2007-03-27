unit mnXMLReader;
{**
 *  This file is part of the "Mini Library"
 *
 * @license   modifiedLGPL (modified of http://www.gnu.org/licenses/lgpl.html)
 *            See the file COPYING.MLGPL, included in this distribution,
 * @author    Zaher Dirkey <zaher at parmaja dot com>
 *}
interface

uses
  Classes, SysUtils, mnXMLScanner;

type
  TmnXMLReadState = record
    Name: string;
    Attributes: string; //must be a list object and take the default attributes from DTD
    Empty: Boolean; //with out a content
  end;

  TmnXMLReader = class(TmnXMLScanner)
  private
    procedure ParseStream;
  protected
    procedure DoStart; override;
    procedure DoStop; override;
    procedure DoReadState(ReadState: TmnXMLReadState); virtual;
  end;

implementation

{ TmnXMLReader }

procedure TmnXMLReader.DoStart;
begin
  inherited;
  if Stream <> nil then
  begin
    ParseStream;
  end;
end;

procedure TmnXMLReader.DoStop;
begin
  inherited;

end;

procedure TmnXMLReader.ParseStream;
var
  Text: string;
  Line: Integer;
begin
  Line := 1;
  while not Stream.EOF do
  begin
    Stream.ReadLn(Text);
    ParseLine(Text, Line);
    Line := Line + 1;
  end;
end;

procedure TmnXMLReader.DoReadState(ReadState: TmnXMLReadState);
begin

end;

end.

