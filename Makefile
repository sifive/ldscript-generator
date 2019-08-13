
.PHONY: virtualenv
virtualenv: venv/bin/activate
	source venv/bin/activate && pip install -r requirements.txt
	@echo "Remember to source venv/bin/activate!"

venv/bin/activate:
	python3 -m venv venv

