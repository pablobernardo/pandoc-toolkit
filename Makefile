.PHONY: bootstrap bootstrap-dry bootstrap-yes bootstrap-ci install-release install-local install-local-dev package-release doctor validate render test epubcheck

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

# Validating a finished publication is an acceptance step, not a runtime
# dependency: EPUBCheck needs a JVM, and `make gate` must stay runnable without
# one. Install it as documented in docs/dependency-policy.md.
epubcheck:
	@if [ -z "$(FILE)" ]; then \
		echo "Usage: make epubcheck FILE=path/to/publication.epub"; \
		echo "Install EPUBCheck first: see docs/dependency-policy.md."; \
		exit 1; \
	fi
	@command -v epubcheck >/dev/null 2>&1 || { \
		echo "epubcheck is not installed: see docs/dependency-policy.md"; \
		echo "  macOS with an existing JDK: unpack the official release and put a wrapper on PATH"; \
		echo "  macOS without one: brew install epubcheck (it installs its own openjdk)"; \
		exit 1; \
	}
	epubcheck "$(FILE)" --locale en
