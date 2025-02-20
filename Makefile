PIP_COMPILE = pip-compile --upgrade --verbose

.SILENT: help
.PHONY: help
help:
	echo Available recipes:
	cat $(MAKEFILE_LIST) | grep -E '^[a-zA-Z0-9_-]+:.*?## .*$$' | awk 'BEGIN { FS = ":.*?## " } { cnt++; a[cnt] = $$1; b[cnt] = $$2; if (length($$1) > max) max = length($$1) } END { for (i = 1; i <= cnt; i++) printf "  $(shell tput setaf 6)%-*s$(shell tput setaf 0) %s\n", max, a[i], b[i] }'
	tput sgr0

.PHONY: install-piptools
install-piptools:
	pip install -U pip-tools

.PHONY: setup
setup: install-piptools ## Install requirements
	pip-sync requirements.txt dev-requirements.txt

.PHONY: setup-spark2
setup-spark2: install-piptools ## Install requirements
	pip-sync requirements-spark2.txt dev-requirements.txt

.PHONY: fmt
fmt: ## Format code with black and isort
	black .
	isort .

.PHONY: lint
lint: ## Run linters
	mypy flytekit/core || true
	mypy flytekit/types || true
	mypy tests/flytekit/unit/core || true
	mypy plugins || true
	flake8 .

.PHONY: test
test: lint ## Run tests
	pytest tests/flytekit/unit
	pytest tests/scripts
	pytest plugins/tests
	shellcheck **/*.sh

.PHONY: unit_test
unit_test:
	pytest tests/flytekit/unit
	pytest tests/scripts
	pytest plugins/tests

requirements-spark2.txt: export CUSTOM_COMPILE_COMMAND := make requirements-spark2.txt
requirements-spark2.txt: requirements-spark2.in install-piptools
	$(PIP_COMPILE) $<

requirements.txt: export CUSTOM_COMPILE_COMMAND := make requirements.txt
requirements.txt: requirements.in install-piptools
	$(PIP_COMPILE) $<

dev-requirements.txt: export CUSTOM_COMPILE_COMMAND := make dev-requirements.txt
dev-requirements.txt: dev-requirements.in requirements.txt install-piptools
	$(PIP_COMPILE) $<

doc-requirements.txt: export CUSTOM_COMPILE_COMMAND := make doc-requirements.txt
doc-requirements.txt: doc-requirements.in install-piptools
	$(PIP_COMPILE) $<

.PHONY: requirements
requirements: requirements.txt dev-requirements.txt requirements-spark2.txt doc-requirements.txt ## Compile requirements

# TODO: Change this in the future to be all of flytekit
.PHONY: coverage
coverage:
	coverage run -m pytest tests/flytekit/unit/core flytekit/types plugins/tests
	coverage report -m --include="flytekit/core/*,flytekit/types/*,plugins/*"

PLACEHOLDER := "__version__\ =\ \"0.0.0+develop\""

.PHONY: update_version
update_version:
	# ensure the placeholder is there. If grep doesn't find the placeholder
	# it exits with exit code 1 and github actions aborts the build. 
	grep "$(PLACEHOLDER)" "flytekit/__init__.py"
	sed -i "s/$(PLACEHOLDER)/__version__ = \"${VERSION}\"/g" "flytekit/__init__.py"

	grep "$(PLACEHOLDER)" "setup.py"
	sed -i "s/$(PLACEHOLDER)/__version__ = \"${VERSION}\"/g" "setup.py"
