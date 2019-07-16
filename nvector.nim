import os, strformat

import nimterop/[cimport, paths]

const srcDir = currentSourcePath().parentDir()
const inclDir = srcDir/"include"
const libDir = srcDir/"lib"


static:
    cDebug()
    cDisableCaching()

cIncludeDir(srcDir/"include")
cIncludeDir(srcDir/"include/nvector")
cIncludeDir(srcDir/"include/sundials")
cIncludeDir(srcDir/"lib")

cPlugin:
    import strutils
    proc onSymbol*(sym: var Symbol) {.exportc, dynlib.} =
        if sym.kind == nskType:
            if sym.name == "_N_VectorContent_Serial":
                sym.name = "N_VectorContent_Serial_Base"
        sym.name = sym.name.strip(chars = {'_'})


const
    libsundials_nvecserial = libDir/"libsundials_nvecserial.dll"

cImport(inclDir/"sundials/sundials_config.h")
cImport(inclDir/"sundials/sundials_types.h")
cImport(inclDir/"sundials/sundials_nvector.h")

cImport(inclDir/"nvector/nvector_serial2.h")
cImport(srcDir/"include/nvector/nvector_serial.h", dynlib = "libsundials_nvecserial")

#[
template ptr2Array[T](p: pointer): auto = cast[ptr UncheckedArray[T]](p)
template array2Ptr[T](arr: openArray[T]): auto = addr(arr[0])

template `->`(a, b: untyped): untyped =
    a[].b

template NV_CONTENT_S(v: untyped): untyped = cast[N_VectorContent_Serial](v->content)
template NV_LENGTH_S(v: untyped): untyped = NV_CONTENT_S(v) -> length
template NV_OWN_DATA_S(v: untyped): untyped = NV_CONTENT_S(v) -> own_data
template NV_DATA_S(v: untyped): untyped = NV_CONTENT_S(v) -> data
template NV_Ith_S(v: untyped, i: sunindextype): untyped = ptr2Array[realtype](NV_DATA_S(v))[i]
]#


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

var v = newNVector(3)
#[
# create newNVector(length) and for over arr, NV_Ith_S(result, i) = arr[i] to keep it in memory.
# N_VClone_Serial and loop over it. 
# NVectorArray = ptr2Array[realtype](NV_DATA_S(v))
proc newNVector*(arr: openArray[realtype]): NVectorType =
    if arr.len <= 0:
        raise newException(ValueError, "NVector length must be greater than 0")
    result.length = arr.len
    result.rawVector = new N_Vector
    result.rawVector[] = N_VNew_Serial(result.length)
    for i in 0 ..< result.length:
        NV_Ith_S(result.rawVector[], i) = arr[i]

proc newNVector*(v: N_Vector): NVectorType =
    result = newNVector(NV_LENGTH_S(v).int)
    N_VScale_Serial(1.0, v, result.rawVector[])

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
]#