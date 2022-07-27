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
