all : deploy

OUTPNG:=/var/www/html/cnsky/os.png

RPREFIX:=riscv64-unknown-elf-
RVCFLAGS:=-fno-stack-protector -I/usr/lib/gcc/riscv64-unknown-elf/12.2.0/include -I/usr/include/newlib
RVCFLAGS+=-static-libgcc -fdata-sections -ffunction-sections
RVCFLAGS+=-g -Os -march=rv32ima_zicsr -mabi=ilp32 -static
RVLDFLAGS:= -T flatfile.lds -nostdlib -Wl,--gc-sections -Wl,--no-warn-rwx-segments

imagegen : imagegen.c
	gcc -o $@ $^

image.elf : gamecode/main.c gamecode/main.S
	$(RPREFIX)gcc -o $@ $^ $(RVCFLAGS) $(RVLDFLAGS)

image.bin : image.elf
	$(RPREFIX)objcopy $^ -O binary $@
	$(RPREFIX)objdump -S $^ > image.lst

deploy : image.bin imagegen
	./imagegen 1024 $(OUTPNG) image.bin

clean :
	rm -rf  *.o *~ image.bin imagegen image.lst image.elf # $(OUTPNG)
