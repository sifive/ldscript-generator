
run: main.py virtualenv
	./$<

.PHONY: virtualenv
virtualenv: venv/.stamp

venv/.stamp: venv/bin/activate requirements.txt
	source venv/bin/activate && pip install -r requirements.txt
	@echo "Remember to source venv/bin/activate!"
	touch $@

venv/bin/activate:
	python3 -m venv venv

