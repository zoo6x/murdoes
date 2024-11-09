as mur.asm -n -O0 --64 -am -amhls=mur.lst -o mur.o
ld mur.o --strip-all -o mur

