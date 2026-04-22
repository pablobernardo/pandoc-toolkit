.PHONY: bootstrap bootstrap-dry bootstrap-yes doctor validate render test

bootstrap:
	bash scripts/bootstrap.sh

bootstrap-dry:
	bash scripts/bootstrap.sh --dry-run

bootstrap-yes:
	bash scripts/bootstrap.sh --yes

bootstrap-ci:
	bash scripts/bootstrap.sh --ci

doctor:
	bin/pandoc-pdf doctor

validate:
	@if [ -z "$(CONFIG)" ]; then \
		echo "Uso: make validate CONFIG=pdf.config.yaml"; \
		exit 1; \
	fi
	bin/pandoc-pdf validate-config -c "$(CONFIG)"

render:
	@if [ -z "$(CONFIG)" ]; then \
		echo "Uso: make render CONFIG=pdf.config.yaml"; \
		exit 1; \
	fi
	bin/pandoc-pdf render -c "$(CONFIG)"

test:
	bash tests/run.sh
