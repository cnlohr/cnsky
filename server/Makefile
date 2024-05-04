all : tle2image

tle2image : tle2image.c
	g++ -o $@ $^ -O2 -lm -g -I. -lz

download :
	wget -O active_satellites.tle "https://celestrak.org/NORAD/elements/gp.php?GROUP=active&FORMAT=tle"

update : download tle2image
	./tle2image active_satellites.tle /var/www/html/cnsky/lastsat.png

validate : validate.c
	g++ -o $@ $^ -O2 -lm -g -lz

clean :
	rm -rf tle2image