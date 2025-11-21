/*
 *  author        : david vallado           davallado@gmail.com    1 mar 2001
 *  translated to c/hlsl: charles lohr 2024-04-28 to 2024-05-04
 *
 *  Unknown License
 */

#define CSGP4_HLSL 1

#include "csgp4_simple.cginc"

void days2mdhms
	(
	int year, float days, float dayfrac,
	out int mon, out int day, out int hr, out int minute, out float  second
	)
{
	int i, inttemp, dayofyr;
	float temp;
	const int lmonthNoLeap[] = { 0, 31, 28, 31, 30, 31, 30, 31, 31, 30, 31, 30, 31 };
	const int lmonthLeap[] = { 0, 31, 29, 31, 30, 31, 30, 31, 31, 30, 31, 30, 31 };
	dayofyr = (int)floor(days);
	dayofyr += floor( dayfrac  );
	dayfrac = frac( dayfrac );
	/* ----------------- find month and day of month ---------------- */
	i = 1;
	inttemp = 0;

	if ((year % 4) == 0)
	{
		while ((dayofyr > inttemp + lmonthLeap[i]) && (i < 12))
		{
			inttemp = inttemp + lmonthLeap[i];
			i = i + 1;
		}
	}
	else
	{
		while ((dayofyr > inttemp + lmonthNoLeap[i]) && (i < 12))
		{
			inttemp = inttemp + lmonthNoLeap[i];
			i = i + 1;
		}
	}

	mon = i;
	day = dayofyr - inttemp;
	/* ----------------- find hours minutes and seconds ------------- */
	temp = (days - dayofyr + dayfrac) * 24.0;
	hr = (int)(floor(temp));
	temp = (temp - hr) * 60.0;
	minute = (int)(floor(temp));
	second= (temp - minute) * 60.0;
}  //  days2mdhms


void invjday
	(
	float jd, float jdFrac,
	out int year, out int mon, out int day,
	out int hr, out int minute, out float second
	)
{
	int leapyrs;
	float dt, days, tu, temp;

	// check jdfrac for multiple days
	if (abs(jdFrac) >= 1.0)
	{
		jd = jd + floor(jdFrac);
		jdFrac = jdFrac - floor(jdFrac);
	}

	// check for fraction of a day included in the jd
	dt = jd - floor(jd) - 0.5;
	if (abs(dt) > 0.00000001)
	{
		jd = jd - dt;
		jdFrac = jdFrac + dt;
	}

	/* --------------- find year and days of the year --------------- */
	temp = jd - 2415019.5;
	tu = temp / 365.25;
	year = 1900 + (int)(floor(tu));
	leapyrs = (int)(floor((year - 1901) * 0.25));

	days = floor(temp - ((year - 1900) * 365.0 + leapyrs));

	/* ------------ check for case of beginning of a year ----------- */
	if (days + jdFrac < 1.0)
	{
		year = year - 1;
		leapyrs = (int)(floor((year - 1901) * 0.25));
		days = floor(temp - ((year - 1900) * 365.0 + leapyrs));
	}

	/* ----------------- find remaining data  ----------------------- */
	// now add the daily time in to preserve accuracy
	days2mdhms(year, days, jdFrac, mon, day, hr, minute, second);
}  // invjday



