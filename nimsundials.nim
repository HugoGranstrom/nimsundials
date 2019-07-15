import os

import nimterop/[cimport, paths]

const srcDir = currentSourcePath().parentDir()

static:
    cDebug()
    cDisableCaching()

cIncludeDir(srcDir/"include")
cIncludeDir(srcDir/"lib")




cPlugin:
    import strutils
    proc onSymbol*(sym: var Symbol) {.exportc, dynlib.} =
        if sym.kind == nskType:
            if sym.name == "_N_VectorContent_Serial":
                sym.name = "N_VectorContent_Serial_Base"
        if sym.name == "ModifiedGS":
            sym.name = "cModifiedGS"
        if sym.name == "ClassicalGS":
            sym.name = "cClassicalGS"
        if sym.name == "_SpgmrMemRec":
            sym.name = "cSpgmrMemRec"
        sym.name = sym.name.strip(chars = {'_'})

        

const
    libsundials_nvecserial = srcDir/"lib/libsundials_nvecserial.dll"
    libsundials_cvode = srcDir/"lib/libsundials_cvode.dll"
    libsundials_sunlinsolspgmr = srcDir/"lib/libsundials_sunlinsolspgmr.dll"
    libsundials_sunmatrixdense = srcDir/"lib/libsundials_sunmatrixdense.dll"

cImport(srcDir/"include/sundials/sundials_config.h")
cImport(srcDir/"include/sundials/sundials_types.h")
cImport(srcDir/"include/sundials/sundials_math.h")

cImport(srcDir/"include/sundials/sundials_nvector.h")
cImport(srcDir/"include/nvector/nvector_serial2.h")
cImport(srcDir/"include/nvector/nvector_serial.h", dynlib = "libsundials_nvecserial")

cImport(srcDir/"include/sundials/sundials_nonlinearsolver.h")
cImport(srcDir/"include/sundials/sundials_direct.h")
cImport(srcDir/"include/sundials/sundials_iterative.h")
cImport(srcDir/"include/sundials/sundials_matrix.h", dynlib="libsundials_cvode")
cImport(srcDir/"include/sundials/sundials_linearsolver.h", dynlib="libsundials_cvode")

cImport(srcDir/"include/sundials/sundials_spgmr.h")
cImport(srcDir/"include/sunlinsol/sunlinsol_spgmr.h", dynlib="libsundials_sunlinsolspgmr")

cImport(srcDir/"include/sunmatrix/sunmatrix_dense.h", dynlib = "libsundials_sunmatrixdense")

cImport(srcDir/"include/cvode/cvode_ls.h", dynlib="libsundials_cvode")
cImport(srcDir/"include/cvode/cvode2.h")
cImport(srcDir/"include/cvode/cvode.h", dynlib="libsundials_cvode")




template ptr2Array[T](p: pointer): auto = cast[ptr UncheckedArray[T]](p)
template array2Ptr[T](arr: openArray[T]): auto = addr(arr[0])

template `->`(a, b: untyped): untyped =
    a[].b

template NV_CONTENT_S(v: untyped): untyped = cast[N_VectorContent_Serial](v->content)
template NV_LENGTH_S(v: untyped): untyped = NV_CONTENT_S(v) -> length
template NV_OWN_DATA_S(v: untyped): untyped = NV_CONTENT_S(v) -> own_data
template NV_DATA_S(v: untyped): untyped = NV_CONTENT_S(v) -> data
template NV_Ith_S(v: untyped, i: sunindextype): untyped = ptr2Array[realtype](NV_DATA_S(v))[i]



type
    NVectorType* = object
        length*: int
        rawVector*: ref[N_Vector]

proc newNVector*(length: int): NVectorType =
    if length <= 0:
        raise newException(ValueError, "NVector length must be greater than 0")
    result.length = length
    result.rawVector = new N_Vector
    result.rawVector[] = N_VNew_Serial(result.length)

# create newNVector(length) and for over arr, NV_Ith_S(result, i) = arr[i] to keep it in memory.
proc newNVector*(arr: openArray[realtype]): NVectorType =
    if arr.len <= 0:
        raise newException(ValueError, "NVector length must be greater than 0")
    result.length = arr.len
    result.rawVector = new N_Vector
    result.rawVector[] = N_VNew_Serial(result.length)
    for i in 0 ..< result.length:
        NV_Ith_S(result.rawVector[], i) = arr[i]

proc clone*(v: NVectorType): NVectorType =
    result = newNVector(v.length)
    N_VScale_Serial(1.0, v.rawVector[], result.rawVector[])


proc `[]`*(v: NVectorType, i: int): realtype =
    if v.length <= i:
        raise newException(ValueError, "index i is out of range. `[]`")
    NV_Ith_S(v.rawVector[], i)

proc `[]=`*(v: NVectorType, i: int, c: realtype) =
    if v.length <= i:
        raise newException(ValueError, "index i is out of range. `[]`")
    NV_Ith_S(v.rawVector[], i) = c

proc `$`*(v: NVectorType): string =
    result = "NVector("
    for i in 0 ..< v.length:
        result = result & $v[i] & ", "
    result = result & ")"


proc `==`*(a, b: NVectorType): bool =
    let length = a.length
    if length != b.length:
        raise newException(ValueError, "NVectors must have same lengths for `==`")
    let aData = ptr2Array[realtype](NV_DATA_S(a.rawVector[]))
    let bData = ptr2Array[realtype](NV_DATA_S(b.rawVector[]))
    for i in 0 ..< length:
        if aData[i] != bData[i]:
            return false
    return true

proc `+`*(a, b: NVectorType): NVectorType =
    if a.length != b.length:
        raise newException(ValueError, "NVector must be of same length for addition")
    result = newNVector(a.length)
    N_VLinearSum_Serial(1.0, a.rawVector[], 1.0, b.rawVector[], result.rawVector[])

proc `+`*(v: NVectorType, c: realtype): NVectorType =
    result = newNVector(v.length)
    N_VAddConst_Serial(v.rawVector[], c, result.rawVector[])

proc `+`*(c: realtype, v: NVectorType): NVectorType =
    result = newNVector(v.length)
    N_VAddConst_Serial(v.rawVector[], c, result.rawVector[])

proc `+=`*(a: var NVectorType, b: NVectorType) =
    if a.length != b.length:
        raise newException(ValueError, "NVector must be of same length for addition")
    N_VLinearSum_Serial(1.0, a.rawVector[], 1.0, b.rawVector[], a.rawVector[])

proc `+=`*(v: var NVectorType, c: realtype) =
    N_VAddConst_Serial(v.rawVector[], c, v.rawVector[])


proc `-`*(a, b: NVectorType): NVectorType =
    if a.length != b.length:
        raise newException(ValueError, "NVector must be of same length for addition")
    result = newNVector(a.length)
    N_VLinearSum_Serial(1.0, a.rawVector[], -1.0, b.rawVector[], result.rawVector[])

proc `-`*(v: NVectorType, c: realtype): NVectorType =
    result = newNVector(v.length)
    N_VAddConst_Serial(v.rawVector[], -c, result.rawVector[])

# TODO
#[ 
proc `-`*(c: realtype, v: NVectorType): NVectorType =
    result = newNVector(v.length)
    N_VAddConst_Serial(v.rawVector[], c, result.rawVector[])
]#

proc `-=`*(a: var NVectorType, b: NVectorType) =
    if a.length != b.length:
        raise newException(ValueError, "NVector must be of same length for addition")
    N_VLinearSum_Serial(1.0, a.rawVector[], -1.0, b.rawVector[], a.rawVector[])

proc `-=`*(v: var NVectorType, c: realtype) =
    N_VAddConst_Serial(v.rawVector[], -c, v.rawVector[])

proc `*`*(v: NVectorType, c: realtype): NVectorType =
    result = newNVector(v.length)
    N_VScale_Serial(c, v.rawVector[], result.rawVector[])
proc `*`*(c: realtype, v: NVectorType): NVectorType =
    result = newNVector(v.length)
    N_VScale_Serial(c, v.rawVector[], result.rawVector[])


template CVodeProc*(name, body: untyped): untyped {.dirty.} =
    proc `name`(t: realtype, y_raw: N_Vector, ydot_raw: N_Vector, user_data: pointer): cint {.cdecl.} =
        let y = newNVector(y_raw)
        var ydot = newNVector(ydot_raw)
        body
        NV_DATA_S(ydot_raw) = NV_DATA_S(ydot.rawVector[])
    proc `name`(t: realtype, y: NVectorType): NVectorType =
        var ydot = newNVector(y.length)
        body
        result = ydot


echo "\n\n\n\nLet the real testing begin:"
echo "Addition:"
var v1 = newNVector([1.0, 2.0, 3.0])
var v2 = newNVector([4.0, 5.0, 6.0])
var vsum = v1 + v2
N_VPrint_Serial(vsum.rawVector[])
N_VPrint_Serial((1.0 + v1 + 1.0).rawVector[])
echo "Inplace Addition:"
v2 += v1
N_VPrint_Serial(v2.rawVector[])
v2 += 2.2
N_VPrint_Serial(v2.rawVector[])
echo v2 == v1

echo v2
echo v2[2]
echo -1.0 * v2


proc f(t: realtype, y: N_Vector, ydot: N_Vector, user_data: pointer): cint {.cdecl.} =
    NV_Ith_S(ydot, 0) = NV_Ith_S(y, 0)
    NV_Ith_S(ydot, 1) = NV_Ith_S(y, 1)
    NV_Ith_S(ydot, 2) = NV_Ith_S(y, 2)

var cvode_mem: pointer = nil
cvode_mem = CVodeCreate(CV_ADAMS)
var t0 = 0.0
var y0 = newNVector([1.0, 1.0, 1.0])
var A = SUNDenseMatrix(3, 3)
let reltol = 1e-8
let abstol = 1e-8
var flag = CVodeInit(cvode_mem, f, t0, y0.rawVector[])
flag = CVodeSStolerances(cvode_mem, reltol, abstol)
var LS = SUNLinSol_SPGMR(y0.rawVector[], 0, 0)
flag = CVodeSetLinearSolver(cvode_mem, LS, A)
var t: realtype = 0.0
var tout = 1.0
flag = CVode(cvode_mem, tout, y0.rawVector[], addr(t), CV_NORMAL)

import math
var correct = newNVector(@[exp(1.0), exp(1.0), exp(1.0)])
echo y0
echo "Error: ", correct - y0

CVodeFree(addr(cvode_mem))
flag = SUNLinSolFree(LS)
SUNMatDestroy(A)


