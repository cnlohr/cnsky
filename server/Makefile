all : tle2image

tle2image : tle2image.c
	gcc -o $@ $^ -O2 -lm -g

download :
	wget -O active_satellites.tle "https://celestrak.org/NORAD/elements/gp.php?GROUP=active&FORMAT=tle"

update : download tle2image
	./tle2image active_satellites.tle /var/www/html/cnsky/lastsat.png

clean :
	rm -rf tle2image
