program smallpt;
{$MODE objfpc}{$H+}
{$INLINE ON}
{$modeswitch advancedrecords}
{$codepage utf8}

uses SysUtils, Classes, Math, getopts, uBMP, uVect;

type
   RefType = (DIFF, SPEC, REFR); // material types, used in radiance()
   {
    DIFFUSE,    // 完全拡散面。いわゆるLambertian面。
    SPECULAR,   // 理想的な鏡面。
    REFRACTION, // 理想的なガラス的物質。
   }

   InterRecord = record
      isHit: boolean;
      t: real;
      id: integer;
   end;

type 
  SphereClass = class
    rad: real;        // radius
    p, e, c: Vec3;    // position, emission, color
    refl: RefType;
    constructor Create(rad_: real; p_, e_, c_: Vec3; refl_: RefType);
    function intersect(const r: RayRecord): real;
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
var
   p, c, e: Vec3;
begin
  sph := TList.Create;
  sph.add( SphereClass.Create(1e5, Vec3.new( 1e5+1,40.8,81.6),  ZeroVec, Vec3.new(0.75,0.25,0.25), DIFF) ); // Left
  sph.add( SphereClass.Create(1e5, Vec3.new(-1e5+99,40.8,81.6), ZeroVec, Vec3.new(0.25,0.25,0.75), DIFF) ); // Right
  sph.add( SphereClass.Create(1e5, Vec3.new(50,40.8, 1e5),      ZeroVec, Vec3.new(0.75,0.75,0.75), DIFF) ); // Back
  sph.add( SphereClass.Create(1e5, Vec3.new(50,40.8,-1e5+170),  ZeroVec, Vec3.new(0,0,0),          DIFF) ); // Front
  sph.add( SphereClass.Create(1e5, Vec3.new(50, 1e5, 81.6),     ZeroVec, Vec3.new(0.75,0.75,0.75), DIFF) ); // Bottom
  sph.add( SphereClass.Create(1e5, Vec3.new(50,-1e5+81.6,81.6), ZeroVec, Vec3.new(0.75,0.75,0.75), DIFF) ); // Top
  sph.add( SphereClass.Create(16.5,Vec3.new(27,16.5,47),        ZeroVec, Vec3.new(1,1,1)*0.999,    SPEC) ); // Mirror
  sph.add( SphereClass.Create(16.5,Vec3.new(73,16.5,88),        ZeroVec, Vec3.new(1,1,1)*0.999,    REFR) ); // Glass
  sph.add( SphereClass.Create(600, Vec3.new(50,681.6-0.27,81.6),Vec3.new(12,12,12), ZeroVec,     DIFF) ); // Light
end;

procedure InitNEScene;
var
   p, c, e: Vec3;
begin
  sph := TList.Create;
  sph.add( SphereClass.Create(1e5, Vec3.new( 1e5+1,40.8,81.6),   ZeroVec, Vec3.new(0.75,0.25,0.25), DIFF) ); // Left
  sph.add( SphereClass.Create(1e5, Vec3.new(-1e5+99,40.8,81.6),  ZeroVec, Vec3.new(0.25,0.25,0.75), DIFF) ); // Right
  sph.add( SphereClass.Create(1e5, Vec3.new(50,40.8, 1e5),       ZeroVec, Vec3.new(0.75,0.75,0.75), DIFF) ); // Back
  sph.add( SphereClass.Create(1e5, Vec3.new(50,40.8,-1e5+170+eps),ZeroVec, ZeroVec,               DIFF) ); // Front
  sph.add( SphereClass.Create(1e5, Vec3.new(50, 1e5, 81.6),      ZeroVec, Vec3.new(0.75,0.75,0.75), DIFF) ); // Bottom
  sph.add( SphereClass.Create(1e5, Vec3.new(50,-1e5+81.6,81.6),  ZeroVec, Vec3.new(0.75,0.75,0.75), DIFF) ); // Top
  sph.add( SphereClass.Create(16.5,Vec3.new(27,16.5,47),         ZeroVec, Vec3.new(1,1,1)*0.999,    SPEC) ); // Mirror
  sph.add( SphereClass.Create(16.5,Vec3.new(73,16.5,88),         ZeroVec, Vec3.new(1,1,1)*0.999,    REFR) ); // Glass
  sph.add( SphereClass.Create( 1.5,Vec3.new(50,81.6-16.5,81.6),  Vec3.new(4,4,4)*100, ZeroVec,      DIFF) ); // Light
end;

procedure SkyScene;
var
   Cen, p, e, c: Vec3;
begin
  sph := TList.Create;
  Cen := Vec3.new(50, 40.8, -860);

  sph.add(SphereClass.Create(1600,   Vec3.new(1,0,2)*3000, Vec3.new(1,0.9,0.8)*1.2e1*1.56*2, ZeroVec, DIFF)); // sun
  sph.add(SphereClass.Create(1560,   Vec3.new(1,0,2)*3500, Vec3.new(1,0.5,0.05)*4.8e1*1.56*2, ZeroVec, DIFF)); // horizon sun2
  sph.add(SphereClass.Create(10000,  Cen + Vec3.new(0,0,-200), Vec3.new(0.00063842, 0.02001478, 0.28923243)*6e-2*8, Vec3.new(0.7,0.7,1)*0.25, DIFF)); // sky

  sph.add(SphereClass.Create(100000, Vec3.new(50, -100000, 0), ZeroVec, Vec3.new(0.3,0.3,0.3), DIFF)); // grnd
  sph.add(SphereClass.Create(110000, Vec3.new(50, -110048.5, 0), Vec3.new(0.9,0.5,0.05)*4, ZeroVec, DIFF)); // horizon brightener
  sph.add(SphereClass.Create(4e4,    Vec3.new(50, -4e4-30, -3000), ZeroVec, Vec3.new(0.2,0.2,0.2), DIFF)); // mountains

  sph.add(SphereClass.Create(26.5, Vec3.new(22,26.5,42), ZeroVec, Vec3.new(1,1,1)*0.596, SPEC)); // white Mirr
  sph.add(SphereClass.Create(13,   Vec3.new(75,13,82),    ZeroVec, Vec3.new(0.96,0.96,0.96)*0.96, REFR)); // Glas
  sph.add(SphereClass.Create(22,   Vec3.new(87,22,24),    ZeroVec, Vec3.new(0.6,0.6,0.6)*0.696, REFR)); // Glas2
end;

function intersect(const r: RayRecord; var t: real; var id: integer): boolean;
var 
  d: real;
  i: integer;
begin
  t := INF;
  for i := 0 to sph.Count - 1 do begin
    d := SphereClass(sph[i]).intersect(r);
    if d < t then begin
      t := d;
      id := i;
    end;
  end;
  result := (t < INF);
end;

function radiance(const r: RayRecord; depth: integer): Vec3;
var
  id: integer;
  obj: SphereClass;
  x, n, f, nl, u, v, w, d: Vec3;
  p, r1, r2, r2s, t: real;
  into: boolean;
  ray2, RefRay: RayRecord;
  nc, nt, nnt, ddn, cos2t, q, a, b, c, R0, Re, RP, Tr, TP: real;
  tDir: Vec3;
begin
  id := 0; depth := depth + 1;
  if not intersect(r, t, id) then begin
    result := ZeroVec; exit;
  end;
  obj := SphereClass(sph[id]);
  x := r.o + r.d * t; n := (x - obj.p).Norm; f := obj.c;
  if n.Dot(r.d) < 0 then nl := n else nl := n * -1;
  if (f.x > f.y) and (f.x > f.z) then
    p := f.x
  else if f.y > f.z then 
    p := f.y
  else
    p := f.z;

  if (depth > 5) then begin
    if random < p then 
      f := f / p 
    else begin
      result := obj.e;
      exit;
    end;
  end;

  case obj.refl of
    DIFF: begin
      r1 := 2 * Pi * random; r2 := random; r2s := sqrt(r2);
      w := nl;
      if abs(w.x) > 0.1 then
        u := (Vec3.new(0,1,0) / w).Norm 
      else
        u := (Vec3.new(1,0,0) / w).Norm;
      v := w / u;
      d := (u * cos(r1) * r2s + v * sin(r1) * r2s + w * sqrt(1 - r2)).Norm;
      result := obj.e + f.Mult(radiance(RayRecord.new(x, d), depth));
    end; (* DIFF *)
    SPEC: begin
      result := obj.e + f.Mult(radiance(RayRecord.new(x, r.d - n * 2 * (n * r.d)), depth));
    end; (* SPEC *)
    REFR: begin
      RefRay := RayRecord.new(x, r.d - n * 2 * (n * r.d));
      into := (n * nl > 0);
      nc := 1; nt := 1.5; if into then nnt := nc / nt else nnt := nt / nc; ddn := r.d * nl; 
      cos2t := 1 - nnt * nnt * (1 - ddn * ddn);
      if cos2t < 0 then begin // Total internal reflection
        result := obj.e + f.Mult(radiance(RefRay, depth));
        exit;
      end;
      if into then q := 1 else q := -1;
      tDir := (r.d * nnt - n * (q * (ddn * nnt + sqrt(cos2t)))).Norm;
      if into then Q := -ddn else Q := tDir * n;
      a := nt - nc; b := nt + nc; R0 := a * a / (b * b); c := 1 - Q;
      Re := R0 + (1 - R0) * c * c * c * c * c; Tr := 1 - Re; P := 0.25 + 0.5 * Re; RP := Re / P; TP := Tr / (1 - P);
      if depth > 2 then begin
        if random < p then // 反射
          result := obj.e + f.Mult(radiance(RefRay, depth) * RP)
        else // 屈折
          result := obj.e + f.Mult(radiance(RayRecord.new(x, tDir), depth) * TP);
      end
      else begin // 屈折と反射の両方を追跡
        result := obj.e + f.Mult(radiance(RefRay, depth) * Re + radiance(RayRecord.new(x, tDir), depth) * Tr);
      end;
    end; (* REFR *)
  end; (* CASE *)
end;

function radiance_ne(r: RayRecord; depth: integer; E: integer): Vec3;
var
  id, i, tid: integer;
  obj, s: SphereClass;
  x, n, f, nl, u, v, w, d: Vec3;
  p, r1, r2, r2s, t, m1, ss, cc: real;
  into: boolean;
  Ray2, RefRay: RayRecord;
  nc, nt, nnt, ddn, cos2t, q, a, b, c, R0, Re, RP, Tr, TP: real;
  tDir: Vec3;
  EL, sw, su, sv, l, tw, tu, tv: Vec3;
  cos_a_max, eps1, eps2, eps2s, cos_a, sin_a, phi, omega, tr_val: real;
  cl, cf: Vec3;
begin
  depth := 0;
  id := 0; cl := ZeroVec; cf := Vec3.new(1,1,1); E := 1;
  while (TRUE) do begin
    Inc(depth);
    if not intersect(r, t, id) then begin
      result := cl;
      exit;
    end;
    obj := SphereClass(sph[id]);
    x := r.o + r.d * t; n := (x - obj.p).Norm; f := obj.c;
    if n * r.d < 0 then nl := n else nl := n * -1;
    if (f.x > f.y) and (f.x > f.z) then
      p := f.x
    else if f.y > f.z then
      p := f.y
    else
      p := f.z;
    tw := obj.e * E;
    cl := cl + cf.Mult(tw);

    if (depth > 5) or (p = 0) then
       if (random < p) then begin
         f := f / p;
       end
       else begin
         result := cl;
         exit;
       end;

    cf := f.Mult(cf);
    case obj.refl of
      DIFF: begin
        r1  := 2 * Pi * random;
        r2  := random;
        r2s := sqrt(r2);
        w   := nl;

        if (abs(w.x) > 0.1) then begin
          m1 := 1 / sqrt(w.z * w.z + w.x * w.x);
          u := Vec3.new(w.z * m1, 0, -w.x * m1);
          v := Vec3.new(w.y * u.z, w.z * u.x - w.x * u.z, -w.y * u.x);
        end
        else begin
          m1 := 1 / sqrt(w.z * w.z + w.y * w.y);
          u := Vec3.new(0, -w.z * m1, w.y * m1);
          v := Vec3.new(w.y * u.z - w.z * u.y, -w.x * u.z, w.x * u.y);
        end;
        sincos(r1, ss, cc);

        u := u * (cc * r2s);
        v := v * (ss * r2s);
        w := w * (sqrt(1 - r2));

        d := VecAdd3(u, v, w); d := d.Norm;
        // Loop over any lights
        EL := ZeroVec;
        tid := id;
        for i := 0 to sph.Count - 1 do begin
          s := SphereClass(sph[i]);
          if (i = tid) then continue;
          if (s.e.x <= 0) and (s.e.y <= 0) and (s.e.z <= 0) then continue; // skip non-lights
          
          if (s.p - x).len < s.rad then begin
            eps1 := 2 * Pi * random; eps2 := random; eps2s := sqrt(eps2);
            sincos(eps1, ss, cc);
            l := (u * (cc * eps2s) + v * (ss * eps2s) + w * sqrt(1 - eps2)).Norm;
            if intersect(RayRecord.new(x, l), t, id) then begin
                if id = i then begin
                   tr_val := l * nl;
                   if tr_val < 0 then tr_val := 0;
                   EL := EL + f.Mult(s.e * tr_val);
                end;
             end;
          end
          else begin // 半球外部の場合
            sw := (s.p - x).Norm;
            if abs(sw.x) > 0.1 then 
              su := (Vec3.new(0,1,0) / sw).Norm 
            else 
              su := (Vec3.new(1,0,0) / sw).Norm;
            sv := sw / su;
            cos_a_max := sqrt(1 - s.rad * s.rad / (s.p - x).Dot(s.p - x));
            eps1 := random; eps2 := random;
            cos_a := 1 - eps1 + eps1 * cos_a_max;
            sin_a := sqrt(1 - cos_a * cos_a);
            if (1 - 2 * random) < 0 then sin_a := -sin_a; 
            phi := 2 * Pi * eps2;
            l := (sw * (cos(phi) * sin_a) + sv * (sin(phi) * sin_a) + sw * cos_a).Norm;
            if (intersect(RayRecord.new(x, l), t, id)) then begin 
              if id = i then begin // shadow ray
                omega := 2 * Pi * (1 - cos_a_max);
                tr_val := l * nl;
                if tr_val < 0 then tr_val := 0;
                tw := s.e * tr_val * omega; tw := f.Mult(tw) * (1 / Pi);
                EL := EL + tw;
              end;
            end;
          end;
        end; (* for *)
        tw := obj.e * E + EL;
        cl := cl + cf.Mult(tw);
        E := 0;
        r := RayRecord.new(x, d);
      end; (* DIFF *)
      SPEC: begin
        cl := cl + cf.Mult(obj.e * E);
        E := 1; tv := n * 2 * (n * r.d); tv := r.d - tv;
        r := RayRecord.new(x, tv);
      end; (* SPEC *)
      REFR: begin
        tv := n * 2 * (n * r.d); tv := r.d - tv;
        RefRay := RayRecord.new(x, tv);
        into := (n * nl > 0);
        nc := 1; nt := 1.5; if into then nnt := nc / nt else nnt := nt / nc; ddn := r.d * nl;
        cos2t := 1 - nnt * nnt * (1 - ddn * ddn);
        if cos2t < 0 then begin // Total internal reflection
          cl := cl + cf.Mult(obj.e * E);
          E := 1;
          r := RefRay;
          continue;
        end;
        if into then q := 1 else q := -1;
        tDir := (r.d * nnt - n * (q * (ddn * nnt + sqrt(cos2t)))).Norm;
        if into then Q := -ddn else Q := tDir * n;
        a := nt - nc; b := nt + nc; R0 := a * a / (b * b); c := 1 - Q;
        Re := R0 + (1 - R0) * c * c * c * c * c; Tr := 1 - Re; P := 0.25 + 0.5 * Re; RP := Re / P; TP := Tr / (1 - P);
        if random < p then begin // 反射
          cf := cf * RP;
          cl := cl + cf.Mult(obj.e * E);
          E := 1;
          r := RefRay;
        end
        else begin // 屈折
          cf := cf * TP;
          cl := cl + cf.Mult(obj.e * E);
          E := 1;
          r := RayRecord.new(x, tDir);
        end;
      end; (* REFR *)
    end; (* CASE *)
  end; (* WHILE LOOP *)
end;

var
  x, y, sx, sy, s: integer;
  w, h, samps, height: integer;
  temp: Vec3;
  tColor, r: Vec3;
  cam: CamRecord;
  BMP: BMPRecord;
  vColor: rgbColor;
  ArgInt: integer;
  FN, ArgFN: string;
  c: char;

begin
  FN := 'temp.bmp';
  w := 1024; h := 768; samps := 16;
  c := #0;
  repeat
    c := getopt('o:s:w:');

    case c of
      'o': begin
         ArgFN := OptArg;
         if ArgFN <> '' then FN := ArgFN;
         writeln('Output FileName =', FN);
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
      '?', ':': begin
         writeln(' -o [filename] output filename');
         writeln(' -s [samps] sampling count');
         writeln(' -w [width] screen width pixel');
      end;
    end; { case }
  until c = endofoptions;

  height := h;
  BMP.new(w, h);
  InitNEScene;
  Randomize;

  cam := CamRecord.new(DefaultPosition, DefaultDirection, w, h, samps);
  writeln('The time is : ', TimeToStr(Time));

  for y := 0 to h - 1 do begin
    if y mod 10 = 0 then writeln('y=', y);
    for x := 0 to w - 1 do begin
      r := ZeroVec;
      tColor := ZeroVec;
      for sy := 0 to 1 do begin
        for sx := 0 to 1 do begin
          for s := 0 to samps - 1 do begin
            temp := radiance_ne(cam.GetRay(x, y, sx, sy), 0, 1);
            temp := temp / samps;
            r := r + temp;
          end; (* samps *)
          temp := ClampVector(r) * 0.25;
          tColor := tColor + temp;
          r := ZeroVec;
        end; (* sx *)
      end; (* sy *)
      vColor := ColToRGB(tColor);
      BMP.SetPixel(x, height - y - 1, vColor);
    end; (* for x *)
  end; (* for y *)
  
  writeln('The time is : ', TimeToStr(Time));
  BMP.WriteFile(FN);
end.