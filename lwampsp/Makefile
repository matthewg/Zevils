all: lwalib misc antimissile

clean:
	find -type d -path './*' -exec make -C \{\} clean \;

lwalib:
	$(MAKE) -C lwalib

misc:
	$(MAKE) -C misc

antimissile:
	$(MAKE) -C antimissile

.PHONY: clean lwalib misc antimissile
