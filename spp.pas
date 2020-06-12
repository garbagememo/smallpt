program smallpt;
{$MODE objfpc}{$H+}
{$INLINE ON}

uses SysUtils,Classes,uVect,uLib,WriteBMP,Math;

const 
  eps=1e-4;
  INF=1e20;
type 
  SphereClass=CLASS
    rad:real;       //radius
    p,e,c:VecRecord;// position. emission,color
    refl:RefType;
    constructor Create(rad_:real;p_,e_,c_:VecRecord;refl_:RefType);
    function intersect(const r:RayRecord):real;
  END;

constructor SphereClass.Create(rad_:real;p_,e_,c_:VecRecord;refl_:RefType);
begin
  rad:=rad_;p:=p_;e:=e_;c:=c_;refl:=refl_;
end;
function SphereClass.intersect(const r:RayRecord):real;
var
  op:VecRecord;
  t,b,det:real;
begin
  op:=p-r.o;
  t:=eps;b:=op*r.d;det:=b*b-op*op+rad*rad;
  IF det<0 THEN 
    result:=INF
  ELSE BEGIN
    det:=sqrt(det);
    t:=b-det;
    IF t>eps then 
      result:=t
    ELSE BEGIN
      t:=b+det;
      if t>eps then 
        result:=t
      else
        result:=INF;
    END;
  END;
end;

var
  sph:TList;
procedure InitScene;
begin
  sph:=TList.Create;
  sph.add( SphereClass.Create(1e5, CreateVec( 1e5+1,40.8,81.6),  ZeroVec,CreateVec(0.75,0.25,0.25),DIFF) );//Left
  sph.add( SphereClass.Create(1e5, CreateVec(-1e5+99,40.8,81.6), ZeroVec,CreateVec(0.25,0.25,0.75),DIFF) );//Right
  sph.add( SphereClass.Create(1e5, CreateVec(50,40.8, 1e5),      ZeroVec,CreateVec(0.75,0.75,0.75),DIFF) );//Back
  sph.add( SphereClass.Create(1e5, CreateVec(50,40.8,-1e5+170),  ZeroVec,CreateVec(0,0,0),      DIFF) );//Front
  sph.add( SphereClass.Create(1e5, CreateVec(50, 1e5, 81.6),     ZeroVec,CreateVec(0.75,0.75,0.75),DIFF) );//Bottomm
  sph.add( SphereClass.Create(1e5, CreateVec(50,-1e5+81.6,81.6), ZeroVec,CreateVec(0.75,0.75,0.75),DIFF) );//Top
  sph.add( SphereClass.Create(16.5,CreateVec(27,16.5,47),        ZeroVec,CreateVec(1,1,1)*0.999, SPEC) );//Mirror
  sph.add( SphereClass.Create(16.5,CreateVec(73,16.5,88),        ZeroVec,CreateVec(1,1,1)*0.999, REFR) );//Glass
  sph.add( SphereClass.Create(600, CreateVec(50,681.6-0.27,81.6),CreateVec(12,12,12),    ZeroVec,DIFF) );//Ligth
end;

function intersect(const r:RayRecord;var t:real; var id:integer):boolean;
var 
  n,d:real;
  i:integer;
begin
  t:=INF;
  for i:=0 to sph.count-1 do begin
    d:=SphereClass(sph[i]).intersect(r);
    if d<t THEN BEGIN
      t:=d;
      id:=i;
    END;
  end;
  result:=(t<inf);
END;

function radiance(const r:RayRecord;depth:integer;var Xi:ErandArray):VecRecord;
var
  id:integer;
  obj:SphereClass;
  x,n,f,nl,u,v,w,d:VecRecord;
  p,r1,r2,r2s,t:real;
  into:boolean;
  RefRay:RayRecord;
  nc,nt,nnt,ddn,cos2t,q,a,b,c,R0,Re,RP,Tr,TP:real;
  tDir:VecRecord;
begin
  id:=0;depth:=depth+1;
  if intersect(r,t,id)=FALSE then begin
    result:=ZeroVec;exit;
  end;
  obj:=SphereClass(sph[id]);
  x:=r.o+r.d*t; n:=VecNorm(x-obj.p); f:=obj.c;
  IF VecDot(n,r.d)<0 THEN nl:=n else nl:=n*-1;
  IF (f.x>f.y)and(f.x>f.z) THEN
    p:=f.x
  ELSE IF f.y>f.z THEN 
    p:=f.y
  ELSE
    p:=f.z;
  if (depth>5) then begin
    if erand48(xi)<p then 
      f:=f/p 
    else begin
      result:=obj.e;
      exit;
    end;
  end;
  CASE obj.refl OF
    DIFF:BEGIN
      r1:=2*PI*erand48(xi);r2:=erand48(xi);r2s:=sqrt(r2);
      w:=nl;
      IF abs(w.x)>0.1 THEN
        u:=CreateVec(0,1,0) 
      ELSE BEGIN
        u:=VecNorm(CreateVec(1,0,0)/w );
      END;
      v:=w/u;
      d := VecNorm(u*cos(r1)*r2s + v*sin(r1)*r2s + w*sqrt(1-r2));
      result:=obj.e+VecMul(f,radiance(CreateRay(x,d),depth,Xi) );
    END;(*DIFF*)
    SPEC:BEGIN
      result:=obj.e+VecMul(f,(radiance(CreateRay(x,r.d-n*2*(n*r.d) ),depth,Xi)));
    END;(*SPEC*)
    REFR:BEGIN
      RefRay:=CreateRay(x,r.d-n*2*(n*r.d) );
      into:= (n*nl>0);
      nc:=1;nt:=1.5; if into then nnt:=nc/nt else nnt:=nt/nc; ddn:=r.d*nl; 
      cos2t:=1-nnt*nnt*(1-ddn*ddn);
      if cos2t<0 then begin   // Total internal reflection
        result:=obj.e + VecMul(f,radiance(RefRay,depth,Xi));
        exit;
      end;
      if into then q:=1 else q:=-1;
      tdir := VecNorm(r.d*nnt - n*(q*(ddn*nnt+sqrt(cos2t))));
      IF into then Q:=-ddn else Q:=tdir*n;
      a:=nt-nc; b:=nt+nc; R0:=a*a/(b*b); c := 1-Q;
      Re:=R0+(1-R0)*c*c*c*c*c;Tr:=1-Re;P:=0.25+0.5*Re;RP:=Re/P;TP:=Tr/(1-P);
      IF depth>2 THEN BEGIN
        IF erand48(xi)<p then // 反射
          result:=obj.e+VecMul(f,radiance(RefRay,depth,Xi)*RP)
        ELSE //屈折
          result:=obj.e+VecMul(f,radiance(CreateRay(x,tdir),depth,Xi)*TP);
      END
      ELSE BEGIN// 屈折と反射の両方を追跡
        result:=obj.e+VecMul(f,radiance(RefRay,depth,Xi)*Re+radiance(CreateRay(x,tdir),depth,Xi)*Tr);
      END;
    END;(*REFR*)
  END;(*CASE*)
end;


VAR
  x,y,sx,sy,i,s: INTEGER;
  w,h,samps,height    : INTEGER;
  temp,d       : VecRecord;
  r1,r2,dx,dy  : real;
  cam,tempRay  : RayRecord;
  cx,cy: VecRecord;
  tColor,r,camPosition,camDirection : VecRecord;

  BMPClass:BMPIOClass;
  ScrWidth,ScrHeight:integer;
  vColor:rgbColor;
  FN:string;
  Xi:ErandArray;

BEGIN
  FN:='temp.bmp';
  w:=320 ;h:=240;  samps := 64;
  height:=h;
  BMPClass:=BMPIOClass.Create(w,h);
  InitScene;

  camPosition:=CreateVec(50, 52, 295.6);
  camDirection:=CreateVec(0, -0.042612, -1);
  camDirection:=VecNorm( camDirection);
  cam:=CreateRay(camPosition, camDirection);
  cx:=CreateVec(w * 0.5135 / h, 0, 0);
  cy:= cx/ cam.d;
  cy:=VecNorm(cy);
  cy:= cy* 0.5135;

  ScrWidth:=0;
  ScrHeight:=0;
  Writeln ('The time is : ',TimeToStr(Time));

  FOR y := 0 to h-1 DO BEGIN
    Xi[0] := 0; Xi[1] := 0;  Xi[2] := y * y * y;
    IF y mod 10 =0 then writeln('y=',y);
    FOR x := 0 TO w - 1 DO BEGIN
      FOR sy := 0 TO 1 DO BEGIN
        r:=CreateVec(0, 0, 0);
        tColor:=ZeroVec;
        FOR sx := 0 TO 1 DO BEGIN
          FOR s := 0 TO samps - 1 DO BEGIN
            r1 := 2 * erand48(Xi);
            IF (r1 < 1) THEN
              dx := sqrt(r1) - 1
            ELSE
              dx := 1 - sqrt(2 - r1);

            r2 := 2 * erand48(Xi);
            IF (r2 < 1) THEN
              dy := sqrt(r2) - 1
            ELSE
              dy := 1 - sqrt(2 - r2);

            temp:= cx* (((sx + 0.5 + dx) / 2 + x) / w - 0.5);
            d:= cy* (((sy + 0.5 + dy) / 2 + (h - y - 1)) / h - 0.5);
            d:= d +temp;
            d:= d +cam.d;

            d:=VecNorm(d);
            tempRay.o:= d* 140;
            tempRay.o:= tempRay.o+ cam.o;
            tempRay.d := d;
            temp:=Radiance(tempRay, 0,Xi);
            temp:= temp/ samps;
            r:= r+temp;
          END;(*samps*)
          temp:= r* 0.24;
          tColor:=tColor+ temp;
          r:=CreateVec(0, 0, 0);
        END;(*sx*)
      END;(*sy*)
      vColor:=ColToRGB(tColor);
      BMPClass.SetPixel(x,height-y,vColor);
    END;(* for x *)
  END;(*for y*)
  Writeln ('The time is : ',TimeToStr(Time));
  BMPClass.WriteBMPFile(FN);
END.
