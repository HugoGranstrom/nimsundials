# nimsundials
Nim wrapper for Sundials 

# WORK IN PROGRESS
If you have a 64-bit Windows machine, you should be able to run it without any modifications (you may need to use Nim with MinGW compiler).
If you have Linux or Mac you have to compile [Sundials](https://github.com/LLNL/sundials) yourself and copy the `lib/` folder in the installation dir and replace the one I have.

# Progress
- NVector - partial support
- CVode - basic example works, most is not implemented yet.
- The rest - Not Implemented

## How to define a ODE
You define a ODE of the form `y' = f(t, y)` with the `CVodeProc` template:
```nim
CVodeProc f:
  cdot = 0.1 * y
```
```nim
CVodeProc f2:
  cdot[0] = y[0] + 2 * y[1]
  cdot[1] = -0.5 * y[0] - 5.4 * y[1]
```
`cdot` is the result variable that you should assign `y'` to. `cdot`, `y`, `t` are implicitly defined. `cdot` and `y` are `NVectorType` and `t` is `realtype`. Do __not__ use `result`.

# Contributions
are happily welcomed :-)
