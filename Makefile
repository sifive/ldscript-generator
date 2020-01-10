
run: ldscript_generator.py virtualenv
	. venv/bin/activate && ./$< -d e31.dts -l metal.default.lds
	. venv/bin/activate && ./$< -d e31.dts -l metal.ramrodata.lds --ramrodata
	. venv/bin/activate && ./$< -d e31.dts -l metal.scratchpad.lds --scratchpad

.PHONY: virtualenv
virtualenv: venv/.stamp

venv/.stamp: venv/bin/activate requirements.txt
	source venv/bin/activate && pip install --upgrade pip
	source venv/bin/activate && pip install -r requirements.txt
	@echo "Remember to source venv/bin/activate!"
	touch $@

venv/bin/activate:
	python3 -m venv venv

.PHONY: lint
lint: virtualenv
	. venv/bin/activate && pylint *.py

.PHONY: test
test: lint

clean:
	-rm -rf venv __pycache__
	-rm metal.*.lds
