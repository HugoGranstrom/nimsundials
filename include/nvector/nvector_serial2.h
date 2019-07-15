#ifndef _NVECTOR_SERIAL_H
#define _NVECTOR_SERIAL_H

#include <stdio.h>
#include <sundials/sundials_nvector.h>

/*
 * -----------------------------------------------------------------
 * SERIAL implementation of N_Vector
 * -----------------------------------------------------------------
 */

struct _N_VectorContent_Serial {
  sunindextype length;   /* vector length       */
  booleantype own_data;  /* data ownership flag */
  realtype *data;        /* data array          */
};

typedef struct _N_VectorContent_Serial *N_VectorContent_Serial;

#endif