NITC=../../../bin/nitg

all: nitcc calc

nitcc_parser_gen: nitcc_parser_gen.nit
	@echo "*** Compile the nitcc bootstrap parser generator -- level 0"
	${NITC} nitcc_parser_gen.nit -v

nitcc0: nitcc.nit nitcc_parser_gen
	@echo "*** Compile the primitive nitcc --- bootstrap level 0"
	./nitcc_parser_gen
	${NITC} nitcc.nit -v -o nitcc0

nitcc1: nitcc0 nitcc.nit nitcc.sablecc
	@echo "*** Compile the intermediate nitcc --- bootstrap level 1"
	./nitcc0 nitcc.sablecc
	${NITC} nitcc.nit -v -o nitcc1

nitcc: nitcc1 nitcc.nit nitcc.sablecc
	@echo "*** Compile the final nitcc --- bootstrap level 2"
	./nitcc1 nitcc.sablecc
	${NITC} nitcc.nit -v

calc: nitcc ../examples/calc.sablecc ../examples/calc.nit
	@echo "*** Example program, calc"
	cd ../examples && ../src/nitcc calc.sablecc
	${NITC} ../examples/calc.nit -v
	./calc -e "1+2*3-40/5+9------1"

minilang: nitcc ../examples/minilang.sablecc ../examples/minilang.nit
	@echo "*** Example program, minilang"
	cd ../examples && ../src/nitcc minilang.sablecc
	${NITC} ../examples/minilang.nit -v
	printf "10\n42\n" | ./minilang ../examples/minilang.minilang

tests:
	cd ../tests && ./run

.PHONY: tests
