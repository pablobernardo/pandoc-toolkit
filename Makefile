.PHONY: bootstrap bootstrap-dry bootstrap-yes bootstrap-ci install-release install-local install-local-dev package-release doctor validate render test epubcheck

bootstrap:
	bash scripts/delivery/bootstrap.sh

bootstrap-dry:
	bash scripts/delivery/bootstrap.sh --dry-run

bootstrap-yes:
	bash scripts/delivery/bootstrap.sh --yes

bootstrap-ci:
	bash scripts/delivery/bootstrap.sh --ci

install-release:
	bash scripts/delivery/install.sh

install-local:
	bash scripts/delivery/install-local.sh

install-local-dev:
	bash scripts/delivery/install-local.sh dev

package-release:
	bash scripts/delivery/package-release.sh dist

doctor:
	bin/skelepress doctor

validate:
	@if [ -z "$(CONFIG)" ]; then \
		echo "Usage: make validate CONFIG=skelepress.config.yaml"; \
		exit 1; \
	fi
	bin/skelepress validate-config -c "$(CONFIG)"

render:
	@if [ -z "$(CONFIG)" ]; then \
		echo "Usage: make render CONFIG=skelepress.config.yaml"; \
		exit 1; \
	fi
	bin/skelepress render -c "$(CONFIG)"

test:
	bash tests/run.sh

# Everything a pull request is verified with, runnable without CI.
gate:
	bash tests/run.sh
	python3 scripts/dev/check-i18n.py
	python3 scripts/dev/check-docs.py
	python3 scripts/dev/check-plan-conformance.py

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
