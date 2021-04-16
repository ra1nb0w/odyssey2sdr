## Quartus tools quartus_sh and quartus_cpf must be in your path

PROJECT = Angelia
TOP_LEVEL_ENTITY = Angelia

all: build/$(PROJECT).sof

build/$(PROJECT).sof:
	quartus_sh --flow compile $(PROJECT)

recompile:
	quartus_sh --flow recompile $(PROJECT)

clean:
	rm -rf build

cleanall:
	rm -rf build db incremental_db greybox_tmp

.PHONY: all recompile clean cleanall
