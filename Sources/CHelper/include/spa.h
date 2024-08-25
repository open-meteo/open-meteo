/////////////////////////////////////////////
//          HEADER FILE for SPA.C          //
//                                         //
//      Solar Position Algorithm (SPA)     //
//                   for                   //
//        Solar Radiation Application      //
//                                         //
//               May 12, 2003              //
//                                         //
//   Filename: SPA.H                       //
//                                         //
//   Afshin Michael Andreas                //
//   afshin_andreas@nrel.gov (303)384-6383 //
//                                         //
//   Measurement & Instrumentation Team    //
//   Solar Radiation Research Laboratory   //
//   National Renewable Energy Laboratory  //
//   1617 Cole Blvd, Golden, CO 80401      //
/////////////////////////////////////////////

////////////////////////////////////////////////////////////////////////
//                                                                    //
// Usage:                                                             //
//                                                                    //
//   1) In calling program, include this header file,                 //
//      by adding this line to the top of file:                       //
//           #include "spa.h"                                         //
//                                                                    //
//   2) In calling program, declare the SPA structure:                //
//           spa_data spa;                                            //
//                                                                    //
//   3) Enter the required input values into SPA structure            //
//      (input values listed in comments below)                       //
//                                                                    //
//   4) Call the SPA calculate function and pass the SPA structure    //
//      (prototype is declared at the end of this header file):       //
//           spa_calculate(&spa);                                     //
//                                                                    //
//   Selected output values (listed in comments below) will be        //
//   computed and returned in the passed SPA structure.  Output       //
//   will based on function code selected from enumeration below.     //
//                                                                    //
//   Note: A non-zero return code from spa_calculate() indicates that //
//         one of the input values did not pass simple bounds tests.  //
//         The valid input ranges and return error codes are also     //
//         listed below.                                              //
//                                                                    //
////////////////////////////////////////////////////////////////////////
/*
#ifndef __solar_position_algorithm_header
#define __solar_position_algorithm_header


//enumeration for function codes to select desired final outputs from SPA
enum {
    SPA_ZA,           //calculate zenith and azimuth
    SPA_ZA_INC,       //calculate zenith, azimuth, and incidence
    SPA_ZA_RTS,       //calculate zenith, azimuth, and sun rise/transit/set values
    SPA_ALL,          //calculate all SPA output values
};

typedef struct
{
    //----------------------INPUT VALUES------------------------

    int year;            // 4-digit year,      valid range: -2000 to 6000, error code: 1
    int month;           // 2-digit month,         valid range: 1 to  12,  error code: 2
    int day;             // 2-digit day,           valid range: 1 to  31,  error code: 3
    int hour;            // Observer local hour,   valid range: 0 to  24,  error code: 4
    int minute;          // Observer local minute, valid range: 0 to  59,  error code: 5
    double second;       // Observer local second, valid range: 0 to <60,  error code: 6
    
    double delta_ut1;    // Fractional second difference between UTC and UT which is used
                         // to adjust UTC for earth's irregular rotation rate and is derived
                         // from observation only and is reported in this bulletin:
                         // http://maia.usno.navy.mil/ser7/ser7.dat,
                         // where delta_ut1 = DUT1
                         // valid range: -1 to 1 second (exclusive), error code 17

    double delta_t;      // Difference between earth rotation time and terrestrial time
                         // It is derived from observation only and is reported in this
                         // bulletin: http://maia.usno.navy.mil/ser7/ser7.dat,
                         // where delta_t = 32.184 + (TAI-UTC) - DUT1
                         // valid range: -8000 to 8000 seconds, error code: 7

    double timezone;     // Observer time zone (negative west of Greenwich)
                         // valid range: -18   to   18 hours,   error code: 8

    double longitude;    // Observer longitude (negative west of Greenwich)
                         // valid range: -180  to  180 degrees, error code: 9

    double latitude;     // Observer latitude (negative south of equator)
                         // valid range: -90   to   90 degrees, error code: 10

    double elevation;    // Observer elevation [meters]
                         // valid range: -6500000 or higher meters,    error code: 11

    double pressure;     // Annual average local pressure [millibars]
                         // valid range:    0 to 5000 millibars,       error code: 12

    double temperature;  // Annual average local temperature [degrees Celsius]
                         // valid range: -273 to 6000 degrees Celsius, error code; 13

    double slope;        // Surface slope (measured from the horizontal plane)
                         // valid range: -360 to 360 degrees, error code: 14

    double azm_rotation; // Surface azimuth rotation (measured from south to projection of
                         //     surface normal on horizontal plane, negative east)
                         // valid range: -360 to 360 degrees, error code: 15

    double atmos_refract;// Atmospheric refraction at sunrise and sunset (0.5667 deg is typical)
                         // valid range: -5   to   5 degrees, error code: 16

    int function;        // Switch to choose functions for desired output (from enumeration)

    //-----------------Intermediate OUTPUT VALUES--------------------

    double jd;          //Julian day
    double jc;          //Julian century

    double jde;         //Julian ephemeris day
    double jce;         //Julian ephemeris century
    double jme;         //Julian ephemeris millennium

    double l;           //earth heliocentric longitude [degrees]
    double b;           //earth heliocentric latitude [degrees]
    double r;           //earth radius vector [Astronomical Units, AU]

    double theta;       //geocentric longitude [degrees]
    double beta;        //geocentric latitude [degrees]

    double x0;          //mean elongation (moon-sun) [degrees]
    double x1;          //mean anomaly (sun) [degrees]
    double x2;          //mean anomaly (moon) [degrees]
    double x3;          //argument latitude (moon) [degrees]
    double x4;          //ascending longitude (moon) [degrees]

    double del_psi;     //nutation longitude [degrees]
    double del_epsilon; //nutation obliquity [degrees]
    double epsilon0;    //ecliptic mean obliquity [arc seconds]
    double epsilon;     //ecliptic true obliquity  [degrees]

    double del_tau;     //aberration correction [degrees]
    double lamda;       //apparent sun longitude [degrees]
    double nu0;         //Greenwich mean sidereal time [degrees]
    double nu;          //Greenwich sidereal time [degrees]

    double alpha;       //geocentric sun right ascension [degrees]
    double delta;       //geocentric sun declination [degrees]

    double h;           //observer hour angle [degrees]
    double xi;          //sun equatorial horizontal parallax [degrees]
    double del_alpha;   //sun right ascension parallax [degrees]
    double delta_prime; //topocentric sun declination [degrees]
    double alpha_prime; //topocentric sun right ascension [degrees]
    double h_prime;     //topocentric local hour angle [degrees]

    double e0;          //topocentric elevation angle (uncorrected) [degrees]
    double del_e;       //atmospheric refraction correction [degrees]
    double e;           //topocentric elevation angle (corrected) [degrees]

    double eot;         //equation of time [minutes]
    double srha;        //sunrise hour angle [degrees]
    double ssha;        //sunset hour angle [degrees]
    double sta;         //sun transit altitude [degrees]

    //---------------------Final OUTPUT VALUES------------------------

    double zenith;       //topocentric zenith angle [degrees]
    double azimuth_astro;//topocentric azimuth angle (westward from south) [for astronomers]
    double azimuth;      //topocentric azimuth angle (eastward from north) [for navigators and solar radiation]
    double incidence;    //surface incidence angle [degrees]

    double suntransit;   //local sun transit time (or solar noon) [fractional hour]
    double sunrise;      //local sunrise time (+/- 30 seconds) [fractional hour]
    double sunset;       //local sunset time (+/- 30 seconds) [fractional hour]

} spa_data;

//-------------- Utility functions for other applications (such as NREL's SAMPA) --------------
double deg2rad(double degrees);
double rad2deg(double radians);
double limit_degrees(double degrees);
double third_order_polynomial(double a, double b, double c, double d, double x);
double geocentric_right_ascension(double lamda, double epsilon, double beta);
double geocentric_declination(double beta, double epsilon, double lamda);
double observer_hour_angle(double nu, double longitude, double alpha_deg);
void   right_ascension_parallax_and_topocentric_dec(double latitude, double elevation,
             double xi, double h, double delta, double *delta_alpha, double *delta_prime);
double topocentric_right_ascension(double alpha_deg, double delta_alpha);
double topocentric_local_hour_angle(double h, double delta_alpha);
double topocentric_elevation_angle(double latitude, double delta_prime, double h_prime);
double atmospheric_refraction_correction(double pressure, double temperature,
                                         double atmos_refract, double e0);
double topocentric_elevation_angle_corrected(double e0, double delta_e);
double topocentric_zenith_angle(double e);
double topocentric_azimuth_angle_astro(double h_prime, double latitude, double delta_prime);
double topocentric_azimuth_angle(double azimuth_astro);


//Calculate SPA output values (in structure) based on input values passed in structure
int spa_calculate(spa_data *spa);

#endif
*/
