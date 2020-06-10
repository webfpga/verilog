/*
 *  icebreaker examples - gamma pwm demo
 *
 *  Copyright (C) 2018 Piotr Esden-Tempski <piotr@esden.net>
 *
 *  Permission to use, copy, modify, and/or distribute this software for any
 *  purpose with or without fee is hereby granted, provided that the above
 *  copyright notice and this permission notice appear in all copies.
 *
 *  THE SOFTWARE IS PROVIDED "AS IS" AND THE AUTHOR DISCLAIMS ALL WARRANTIES
 *  WITH REGARD TO THIS SOFTWARE INCLUDING ALL IMPLIED WARRANTIES OF
 *  MERCHANTABILITY AND FITNESS. IN NO EVENT SHALL THE AUTHOR BE LIABLE FOR
 *  ANY SPECIAL, DIRECT, INDIRECT, OR CONSEQUENTIAL DAMAGES OR ANY DAMAGES
 *  WHATSOEVER RESULTING FROM LOSS OF USE, DATA OR PROFITS, WHETHER IN AN
 *  ACTION OF CONTRACT, NEGLIGENCE OR OTHER TORTIOUS ACTION, ARISING OUT OF
 *  OR IN CONNECTION WITH THE USE OR PERFORMANCE OF THIS SOFTWARE.
 *
 */

// This program generates a single-quadrant sinewave table set.
// The first table contains the values of sin(x) for the 256
// points in the quadrant.  The second table contains the differences
// between the values - these will be used to perform linear
// interpolation.

#include <stdio.h>
#include <math.h>

#define PI 3.14159265358

#define SLICES 8
#define INDICES (SLICES*256)

int main()
{
	fprintf(stderr, "Generating the sine table.\n");

	long values[INDICES+1];

	FILE *f1, *f2;

	for (int i = 0; i < INDICES+1 ; i++) {
	  double dvalue = sin((PI / 2 * i) / INDICES);
	  values[i] = 0x7FFEl * dvalue;
	}
	f1 = fopen("sine_integer.hex", "w");
	f2 = fopen("sine_fract.hex", "w");
	for (int i = 0; i < INDICES; i++) {

		if ((i % 8) == 0) {
		  fprintf(f1, "@%08x", i);
		  fprintf(f2, "@%08x", i);
		}
		fprintf(f1, " %04lX", values[i]);
		fprintf(f2, " %02lX", values[i+1] - values[i]);
		if ((i % 8) == 7) {
		  fprintf(f1, "\n");
		  fprintf(f2, "\n");
		}
	}
	fclose(f1);
	fclose(f2);
	return 0;
}
