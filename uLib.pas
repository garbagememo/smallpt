UNIT uLib;
{$MODE objfpc}

INTERFACE
USES MATH;
CONST
  M_PI2 =PI + PI;
  gamma2_2 = 1.0 / 2.2;

TYPE
  ErandType  = WORD;
  ERandArray = ARRAY[0..3] OF ErandType;

FUNCTION erand48(VAR xseed : ERandArray) : real;

IMPLEMENTATION


CONST
  RAND48_SEED_0 : ErandType = ($330e);
  RAND48_SEED_1 : ErandType = ($abcd);
  RAND48_SEED_2 : ErandType = ($1234);
  RAND48_MULT_0 : ErandType = ($e66d);
  RAND48_MULT_1 : ErandType = ($deec);
  RAND48_MULT_2 : ErandType = ($0005);
  RAND48_ADD    : ErandType = ($000b);

  sErandType8   : integer  = (sizeof(ErandType) * 8);

VAR
  _rand48_seed : ARRAY[0..2] OF ErandType;
  _rand48_mult : ARRAY[0..2] OF ErandType;
  _rand48_add  : ErandType;

procedure _dorand48(VAR xseed : ERandArray);
var
  accu : Longint;
  temp : ARRAY[0..1] OF ErandType;
begin
  accu     := longint(_rand48_mult[0]) * LongInt(xseed[0]) + LongInt(_rand48_add);
  temp[0]  := ErandType(accu);
  //accu     := accu SHR (sizeof(ErandType) * 8);
  accu     := accu SHR (sErandType8);
  accu     := accu + (LongInt(_rand48_mult[0]) * LongInt(xseed[1]) + LongInt(_rand48_mult[1]) * LongInt(xseed[0]));
  temp[1]  := ErandType(accu);
  //accu     := accu SHR (sizeof(ErandType) * 8);
  accu     := accu SHR (sErandType8);
  accu     := accu + (_rand48_mult[0] * xseed[2] + _rand48_mult[1] * xseed[1] + _rand48_mult[2] * xseed[0]);
  xseed[0] := temp[0];
  xseed[1] := temp[1];
  xseed[2] := ErandType(accu);
end;

function erand48(VAR xseed : ERandArray) : real;
begin
  _dorand48(xseed);
  result := ldexp((xseed[0]), -48) + ldexp((xseed[1]), -32) + ldexp(xseed[2], -16);
end;


BEGIN
  _rand48_seed[0] := RAND48_SEED_0;
  _rand48_seed[1] := RAND48_SEED_1;
  _rand48_seed[2] := RAND48_SEED_2;

  _rand48_mult[0] := RAND48_MULT_0;
  _rand48_mult[1] := RAND48_MULT_1;
  _rand48_mult[2] := RAND48_MULT_2;

  _rand48_add     := RAND48_ADD;
END.

