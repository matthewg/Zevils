APP=lwatest
LIB=lwalib.a
OBJS=graphics.o math.o

all: $(LIB)

$(LIB): $(OBJS)
	$(MKLIB)

app: $(APP)

$(APP): $(APP).o

include ../Makefile.inc
