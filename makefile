mySnake.tap: mySnake.asm loader.bas bas2tap
	./bas2tap -smySnake -a=0 loader.bas mySnake.tap
	sjasmplus --syntax=aFs mySnake.asm

bas2tap: bas2tap.c
	gcc bas2tap.c -o bas2tap -lm

run:
	fuse mySnake.tap

clean:
	rm mySnake.tap bas2tap
