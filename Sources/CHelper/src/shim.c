#include <math.h>
#include "shim.h"


/// Fast winddirection approximtation based on fma approximaled atan2
/// See: https://mazzo.li/posts/vectorized-atan2.html
/// Caveat: if x and y is `0`, also `0` is returned
void windirectionFast(const size_t num_points, const float* ys, const float* xs, float* out) {
  float pi = M_PI;
  float pi_2 = M_PI_2;

  for (size_t i = 0; i < num_points; i++) {
    // Ensure input is in [-1, +1]
    float y = ys[i];
    float x = xs[i];
    int swap = fabs(x) < fabs(y);
    float atan_input = (swap ? x : y) / (swap ? y : x);

    // Approximate atan
    float a1  =  0.99997726f;
    float a3  = -0.33262347f;
    float a5  =  0.19354346f;
    float a7  = -0.11643287f;
    float a9  =  0.05265332f;
    float a11 = -0.01172120f;

    // Compute approximation using Horner's method
    float x_sq = atan_input*atan_input;
    float res =
      atan_input * fmaf(x_sq, fmaf(x_sq, fmaf(x_sq, fmaf(x_sq, fmaf(x_sq, a11, a9), a7), a5), a3), a1);

    // If swapped, adjust atan output
    res = swap ? copysignf(pi_2, atan_input) - res : res;
    // Adjust the result depending on the input quadrant
    if (x < 0.0f) {
      res = copysignf(pi, y) + res;
    }

    // Store result
    out[i] = res * (180 / pi) + 180;
  }
}


#include <stdio.h>
#include <stdlib.h>
#include <string.h>

#if __APPLE__
void display_mallinfo2(void) {
    printf("display_mallinfo2 not supported for macOS\n");
}
#else
#include <malloc.h>


void display_mallinfo2(void) {
   struct mallinfo2 mi;

   mi = mallinfo2();

   printf("Total non-mmapped bytes (arena):       %zu\n", mi.arena);
   printf("# of free chunks (ordblks):            %zu\n", mi.ordblks);
   printf("# of free fastbin blocks (smblks):     %zu\n", mi.smblks);
   printf("# of mapped regions (hblks):           %zu\n", mi.hblks);
   printf("Bytes in mapped regions (hblkhd):      %zu\n", mi.hblkhd);
   printf("Max. total allocated space (usmblks):  %zu\n", mi.usmblks);
   printf("Free bytes held in fastbins (fsmblks): %zu\n", mi.fsmblks);
   printf("Total allocated space (uordblks):      %zu\n", mi.uordblks);
   printf("Total free space (fordblks):           %zu\n", mi.fordblks);
   printf("Topmost releasable block (keepcost):   %zu\n", mi.keepcost);
}
#endif



/*int
main(int argc, char *argv[])
{
#define MAX_ALLOCS 2000000
   char *alloc[MAX_ALLOCS];
   int numBlocks, freeBegin, freeEnd, freeStep;
   size_t blockSize;

   if (argc < 3 || strcmp(argv[1], "--help") == 0) {
       fprintf(stderr, "%s num-blocks block-size [free-step "
               "[start-free [end-free]]]\n", argv[0]);
       exit(EXIT_FAILURE);
   }

   numBlocks = atoi(argv[1]);
   blockSize = atoi(argv[2]);
   freeStep = (argc > 3) ? atoi(argv[3]) : 1;
   freeBegin = (argc > 4) ? atoi(argv[4]) : 0;
   freeEnd = (argc > 5) ? atoi(argv[5]) : numBlocks;

   printf("============== Before allocating blocks ==============\n");
   display_mallinfo2();

   for (int j = 0; j < numBlocks; j++) {
       if (numBlocks >= MAX_ALLOCS) {
           fprintf(stderr, "Too many allocations\n");
           exit(EXIT_FAILURE);
       }

       alloc[j] = malloc(blockSize);
       if (alloc[j] == NULL) {
           perror("malloc");
           exit(EXIT_FAILURE);
       }
   }

   printf("\n============== After allocating blocks ==============\n");
   display_mallinfo2();

   for (int j = freeBegin; j < freeEnd; j += freeStep)
       free(alloc[j]);

   printf("\n============== After freeing blocks ==============\n");
   display_mallinfo2();

   exit(EXIT_SUCCESS);
}
*/
