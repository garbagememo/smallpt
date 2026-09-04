program ppmconv;
{$mode objfpc}
{$modeswitch advancedrecords}
uses SysUtils,classes,uBMP;

var
  BMP:BMPRecord;
  st:String;

begin
  if paramcount<1 then exit;
  st:=ParamStr(1);
  if UpperCase(ExtractFileExt(st))='.PPM' then begin
    BMP.ReadFile(st);
    delete(st,length(st)-3,4);
    BMP.WriteFile(ExtractFileName(st)+'.png');
  end;
end.
  
  
