#ifndef _CVODE_H
#define _CVODE_H

#include <stdio.h>
#include <sundials/sundials_nvector.h>
#include <sundials/sundials_nonlinearsolver.h>
#include <cvode/cvode_ls.h>

typedef int (*CVRhsFn)(realtype t, N_Vector y,
                       N_Vector ydot, void *user_data);

typedef int (*CVRootFn)(realtype t, N_Vector y, realtype *gout,
                        void *user_data);

typedef int (*CVEwtFn)(N_Vector y, N_Vector ewt, void *user_data);

typedef void (*CVErrHandlerFn)(int error_code,
                               const char *module, const char *function,
                               char *msg, void *user_data);
							   
#endif