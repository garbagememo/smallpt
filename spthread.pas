program smallpt;
{$MODE objfpc}{$H+}
{$INLINE ON}
{$modeswitch advancedrecords}
{$codepage utf8}

uses
   {$ifdef unix}
   cthreads,cmem,
   cwstring,
   {$endif}
   SysUtils, Classes, Math, getopts, uBMP, uVect;

const
   MaxThread=32;

var
   BMP:BMPrecord;

type
   LineArray=array[0..255*255] of rgbColor;

type
  RandomRecord = record
  private
    const
      N = 624;
      M = 397;
      MATRIX_A = $9908B0DF;
      UPPER_MASK = $80000000;
      LOWER_MASK = $7FFFFFFF;
    var
      FState: array[0..N - 1] of Cardinal;
      FIndex: Integer;

      procedure Twist;
  public
    constructor Create(seed_: Cardinal);
    function Random: real;
  end;


TMyThread = class(TThread)
      wide,height,samps:integer;
      y,yInc:integer;
      Line:LineArray;
      cam:CamRecord;
      RandState: RandomRecord; // スレッド固有の乱数シード状態
      procedure Execute; override;
      procedure AddAxis;
   end;

   RefType = (DIFF, SPEC, REFR);

   InterRecord = record
      isHit: boolean;
      t: real;
      id: integer;
   end;

   SphereClass = class
      rad: real;
      p, e, c: Vec3;
      refl: RefType;
      constructor Create(rad_: real; p_, e_, c_: Vec3; refl_: RefType);
      function intersect(const r: RayRecord): real;
   end;

constructor RandomRecord.Create(seed_: Cardinal);
var
  i: Integer;
begin
  FState[0] := seed_ and $FFFFFFFF;
  for i := 1 to N - 1 do
  begin
    FState[i] := 1812433253 * (FState[i - 1] xor (FState[i - 1] shr 30)) + i;
    FState[i] := FState[i] and $FFFFFFFF;
  end;
  FIndex := N;
end;

procedure RandomRecord.Twist;
var
  i: Integer;
  y: Cardinal;
begin
  for i := 0 to N - 1 do  begin
    y := (FState[i] and UPPER_MASK) or (FState[(i + 1) mod N] and LOWER_MASK);
    FState[i] := FState[(i + 156) mod N] xor (y shr 1);
    if (y and 1) <> 0 then FState[i] := FState[i] xor MATRIX_A;
  end;
  FIndex := 0;
end;

function RandomRecord.Random: real;
var
  y: Cardinal;
begin
  if FIndex >= N then Twist;

  y := FState[FIndex];
  Inc(FIndex);

  // 攪拌（Tempering）処理
  y := y xor (y shr 11);
  y := y xor ((y shl 7) and $9D2C5680);
  y := y xor ((y shl 15) and $EFC60000);
  y := y xor (y shr 18);

  // [0, 1) の範囲の浮動小数点数に変換
  Result := y / 4294967296.0;
end;

   
constructor SphereClass.Create(rad_: real; p_, e_, c_: Vec3; refl_: RefType);
begin
   rad := rad_; p := p_; e := e_; c := c_; refl := refl_;
end;

function SphereClass.intersect(const r: RayRecord): real;
var
   op: Vec3;
   t, b, det: real;
begin
   op := p - r.o;
   t := eps; b := op * r.d; det := b * b - op * op + rad * rad;
   if det < 0 then 
      result := INF
   else begin
      det := sqrt(det);
      t := b - det;
      if t > eps then 
         result := t
      else begin
         t := b + det;
         if t > eps then 
            result := t
         else
            result := INF;
      end;
   end;
end;

var
   sph: TList;

procedure InitScene;
begin
   sph := TList.Create;
   sph.add(SphereClass.Create(1e5,  Vec3.new(1e5 + 1, 40.8, 81.6),  ZeroVec, Vec3.new(0.75, 0.25, 0.25), DIFF));
   sph.add(SphereClass.Create(1e5,  Vec3.new(-1e5 + 99, 40.8, 81.6), ZeroVec, Vec3.new(0.25, 0.25, 0.75), DIFF));
   sph.add(SphereClass.Create(1e5,  Vec3.new(50, 40.8, 1e5),       ZeroVec, Vec3.new(0.75, 0.75, 0.75), DIFF));
   sph.add(SphereClass.Create(1e5,  Vec3.new(50, 40.8, -1e5 + 170), ZeroVec, Vec3.new(0, 0, 0),          DIFF));
   sph.add(SphereClass.Create(1e5,  Vec3.new(50, 1e5, 81.6),      ZeroVec, Vec3.new(0.75, 0.75, 0.75), DIFF));
   sph.add(SphereClass.Create(1e5,  Vec3.new(50, -1e5 + 81.6, 81.6),ZeroVec, Vec3.new(0.75, 0.75, 0.75), DIFF));
   sph.add(SphereClass.Create(16.5, Vec3.new(27, 16.5, 47),         ZeroVec, Vec3.new(1, 1, 1) * 0.999,  SPEC));
   sph.add(SphereClass.Create(16.5, Vec3.new(73, 16.5, 88),         ZeroVec, Vec3.new(1, 1, 1) * 0.999,  REFR));
   sph.add(SphereClass.Create(600,  Vec3.new(50, 681.6 - 0.27, 81.6),Vec3.new(12, 12, 12), ZeroVec,      DIFF));
end;

function intersect(const r: RayRecord; var t: real; var id: integer): boolean;
var 
   d: real;
   i: integer;
begin
   t := INF;
   for i := 0 to sph.count - 1 do begin
      d := SphereClass(sph[i]).intersect(r);
      if d < t then begin
         t := d;
         id := i;
      end;
   end;
   result := (t < INF);
end;

// radiance 関数にスレッド固有の RandState を参照引数(var)で渡す
function radiance(const r: RayRecord; depth: integer; var state: RandomRecord): Vec3;
var
   id: integer;
   obj: SphereClass;
   x, n, f, nl, u, v, w, d: Vec3;
   r1, r2, r2s, t: real;
   into: boolean;
   RefRay: RayRecord;
   nc, nt, nnt, ddn, cos2t, q, a, b, c, R0, Re, Tr, P, RP, TP: real;
   tDir: Vec3;
begin
   id := 0; depth := depth + 1;
   if not intersect(r, t, id) then begin
      result := ZeroVec;
      exit;
   end;
   
   obj := SphereClass(sph[id]);
   x := r.o + r.d * t; 
   n := (x - obj.p).Norm; 
   f := obj.c;
   
   if n.Dot(r.d) < 0 then nl := n else nl := n * -1;
   p := Max(f.x, Max(f.y, f.z));
   
   if depth > 5 then begin
      if state.random < p then 
         f := f / p 
      else 
         exit(obj.e);
   end;
   
   case obj.refl of
      DIFF: begin
         r1 := 2 * PI * state.random; 
         r2 := state.random; 
         r2s := sqrt(r2);
         w := nl;
         if abs(w.x) > 0.1 then
            u := (Vec3.new(0, 1, 0) / w).Norm 
         else
            u := (Vec3.new(1, 0, 0) / w).Norm;
         v := w / u;
         d := (u * cos(r1) * r2s + v * sin(r1) * r2s + w * sqrt(1 - r2)).Norm;
         result := obj.e + f.Mult(radiance(RayRecord.new(x, d), depth, state));
      end;
      
      SPEC: begin
         result := obj.e + f.Mult(radiance(RayRecord.new(x, r.d - n * 2 * (n * r.d)), depth, state));
      end;
      
      REFR: begin
         RefRay := RayRecord.new(x, r.d - n * 2 * (n * r.d));
         into := (n * nl > 0);
         nc := 1; nt := 1.5; 
         if into then nnt := nc / nt else nnt := nt / nc; 
         ddn := r.d * nl; 
         cos2t := 1 - nnt * nnt * (1 - ddn * ddn);
         
         if cos2t < 0 then begin
            result := obj.e + f.Mult(radiance(RefRay, depth, state));
            exit;
         end;
         
         if into then q := 1 else q := -1;
         tDir := (r.d * nnt - n * (q * (ddn * nnt + sqrt(cos2t)))).Norm;
         if into then q := -ddn else q := tDir * n;
         
         a := nt - nc; b := nt + nc; R0 := a * a / (b * b); c := 1 - q;
         Re := R0 + (1 - R0) * c * c * c * c * c; 
         Tr := 1 - Re; 
         P := 0.25 + 0.5 * Re; 
         RP := Re / P; 
         TP := Tr / (1 - P);
         
         if depth > 2 then begin
            if state.Random < p then
               result := obj.e + f.Mult(radiance(RefRay, depth, state) * RP)
            else
               result := obj.e + f.Mult(radiance(RayRecord.new(x, tDir), depth, state) * TP);
         end
         else begin
            result := obj.e + f.Mult(radiance(RefRay, depth, state) * Re + radiance(RayRecord.new(x, tDir), depth, state) * Tr);
         end;
      end;
   end;
end;

procedure TMyThread.Execute;
var
   x,sx,sy,s:integer;
   r,tColor:Vec3;
begin
   while y<height do begin
      if y mod 10 = 0 then writeln('y=',y);
      for x:= 0 to wide - 1 do begin
         tColor:=ZeroVec;
         for sy := 0 to 1 do begin
            for sx := 0 to 1 do begin
               r:=ZeroVec;
               for s := 0 to cam.samps - 1 do begin
                  // スレッドごとの RandState を引数として渡す
                  r:= r + Radiance(cam.GetRay(x,y,sx,sy), 0, RandState) / cam.samps;
               end;
               tColor:=tColor+ ClampVector(r)* 0.25;
            end;
         end;
         Line[x]:=ColToRGB(tColor);
      end;
      Synchronize(@AddAxis);
   end;
end;

procedure TMyThread.AddAxis;
var
   j:integer;
   yAxis:integer;
begin
   yAxis:=height-y-1;
   for j:=0 to wide-1 do BMP.SetPixel(j,yAxis,line[j]);
   y:=y+yInc;
end;

var
   i: integer;
   w, h, samps: integer;
   cam: CamRecord;
   ArgInt: integer;
   FN, ArgFN: string;
   c: char;
   StarTime:TDateTime;
   ThreadAry:array[0..MaxThread-1] of TMyThread;
   ThreadNum:integer;

begin
   ThreadNum:=8;
   FN := 'temp.bmp';
   w := 1024; h := 768; samps := 16;
   c := #0;
   
   repeat
      c := getopt('ho:s:w:');
      case c of
         'o': begin
            ArgFN := OptArg;
            if ArgFN <> '' then FN := ArgFN;
         end;
         's': begin
            ArgInt := StrToInt(OptArg);
            samps := ArgInt;
            writeln('samples =', ArgInt);
         end;
         'w': begin
            ArgInt := StrToInt(OptArg);
            w := ArgInt; h := w * 3 div 4;
            writeln('w=', w, ' ,h=', h);
         end;
         '?', 'h': begin
            writeln(' -o [filename] output filename');
            writeln(' -s [samps] sampling count');
            writeln(' -w [width] screen width pixel');
            halt;
         end;
      end;
   until c = endofoptions;

   writeln('sample=', samps);
   writeln('output file=', FN);
   
   BMP.new(w, h);
   InitScene;

   cam := CamRecord.new(DefaultPosition, DefaultDirection, w, h, samps);
   writeln('The time is : ', TimeToStr(Time));
   StarTime:=Time; 

   for i:=0 to ThreadNum-1 do begin
      ThreadAry[i]:=TMyThread.Create(true);
      ThreadAry[i].FreeOnTerminate:=false;
      ThreadAry[i].y:=i;
      ThreadAry[i].wide:=cam.w;
      ThreadAry[i].height:=cam.h;
      ThreadAry[i].cam:=cam;
      ThreadAry[i].samps:=cam.samps;
      ThreadAry[i].yInc:=ThreadNum;

      // ★ スレッドごとにユニークな初期シードを設定（0防止のため1を加算）
      ThreadAry[i].RandState.create( Cardinal((i + 1) * 123456789 + GetTickCount64) );
   end;
   writeln('Setup!');
   
   for i:=0 to ThreadNum-1 do begin
      ThreadAry[i].Start;
   end;

   for i:=0 to ThreadNum-1 do begin
      ThreadAry[i].WaitFor;
   end;

   writeln('The time is : ',TimeToStr(Time));
   writeln('Calcurate time is=',TimeToStr(Time-StarTime));
   
   BMP.WriteFile(FN);
end.
