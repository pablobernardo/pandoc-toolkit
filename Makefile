.PHONY: bootstrap bootstrap-dry bootstrap-yes bootstrap-ci install-release install-local install-local-dev package-release doctor validate render test

bootstrap:
	bash scripts/bootstrap.sh

bootstrap-dry:
	bash scripts/bootstrap.sh --dry-run

bootstrap-yes:
	bash scripts/bootstrap.sh --yes

bootstrap-ci:
	bash scripts/bootstrap.sh --ci

install-release:
	bash scripts/install.sh

install-local:
	bash scripts/install-local.sh

install-local-dev:
	bash scripts/install-local.sh dev

package-release:
	bash scripts/package-release.sh dist

doctor:
	bin/pandoc-pdf doctor

validate:
	@if [ -z "$(CONFIG)" ]; then \
		echo "Usage: make validate CONFIG=pdf.config.yaml"; \
		exit 1; \
	fi
	bin/pandoc-pdf validate-config -c "$(CONFIG)"

render:
	@if [ -z "$(CONFIG)" ]; then \
		echo "Usage: make render CONFIG=pdf.config.yaml"; \
		exit 1; \
	fi
	bin/pandoc-pdf render -c "$(CONFIG)"

test:
	bash tests/run.sh

# Everything a pull request is verified with, runnable without CI.
gate:
	bash tests/run.sh
	python3 scripts/check-i18n.py
	python3 scripts/check-docs.py
	python3 scripts/check-plan-conformance.py
