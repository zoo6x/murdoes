as mur.asm -n -g -O0 --64 -am -amhls=mur.lst -o mur.o
ld mur.o -N -o mur
mv mur moor

as mur.asm --defsym DEBUG=1 -n -g -O0 --64 -am -amhls=mur.lst -o mur.o
ld mur.o -N -o mur
mv mur moord

