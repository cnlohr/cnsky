# cnsky Reference Unity Project

## Setup

For VCC (Creator Companion)
 * Unity 2022.3.6f1
 * VRChat SDK - Worlds 3.5.2
 * VRChat Package Resolver Tool 0.1.28
 * VRChat SDK - Base 3.5.2
 * AudioLink 1.3.0
 * VideoTXL2.4.6

## Sort Term TODO
 * Fix earth
 * Back-port csgp4_simple.cginc
 * Remove unneeded parameters from csgp4_init.
 
... later

 * https://asteroid.lowell.edu/astorb/ << Asteroids!!
 *  https://www.adsb.lol/docs/feeders-only/beast-mlat-out/ 
 * Get rid of "optimization" flag on compute.
 * Fix hull of beziers.   DONE.
 * Try simplifying the bezier to cubic. DONE

 * Make sure the shader is not double rendering - this code looks dubious:
```
				uint operationID = pid;
				uint thisop = operationID;
				const uint totalsat = (511*85); // 85 satellites per line, 511 lines.
				const uint thissatno = (thisop%totalsat); 
```
 * Filtering + Color Coding (BEN)
  * Highlight interesting satellites, i.e. Hubble, ISS, etc.
 * Pick a satellite and show long-term orbit.
 * Interaction System?


 * Handle satellites based on launch time/day.


## Comments from first test.
 * Slider for adjusting tail length
 * Make tails start at nothing when loading and continue to expand with length in instance.
 * Slider to control tail intensity.
 * Representation of moon.
 * FIX THE STUPID BEZIERS BEING IN CLIP SPACE!!! Really eggaguarted 
 * Get data at specific day in history.


## Long Term TODO
 * Improve Bezier Curve Code.
 * Make earth technically correct using Julian YMD HMS
 
## Data Structures


### Management CRT

| Pixel | Description |
| --- | --- |
| 0,0 R |  Frame # (asuint)  |
| 0,0 G | JD Days |
| 0,0 B | JD Days (Fractional) |
| 0,0 A | If wallclock is real |
| 1,0 R | Year |
| 1,0 G | Month |
| 1,0 B | Days |
| 1,0 A | - |
| 2,0 R | Hours |
| 2,0 R | Minutes |
| 2,0 R | Seconds |
| 0,1 R | Minutes to advance per segment |
| 0,1 G | Minutes offset from initial segment |

### Compute CRT

 * Top Row: Unused
 * All data broken into rgoups of 2x6 pixels.
 * Top Row: Position,Time
 * Bottom Row: Velocity
 * Row goes:
 * -25 min, -15 min, -5min "now" +5 min, +15 min, +25 min
 
 
 
 
 