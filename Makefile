POWERSHELL ?= powershell
SCRIPT := ./scripts/helm-charts.ps1

.PHONY: help lint template test package verify clean

help:
	@$(POWERSHELL) -NoProfile -ExecutionPolicy Bypass -File $(SCRIPT) help

lint:
	@$(POWERSHELL) -NoProfile -ExecutionPolicy Bypass -File $(SCRIPT) lint

template:
	@$(POWERSHELL) -NoProfile -ExecutionPolicy Bypass -File $(SCRIPT) template

test:
	@$(POWERSHELL) -NoProfile -ExecutionPolicy Bypass -File $(SCRIPT) test

package:
	@$(POWERSHELL) -NoProfile -ExecutionPolicy Bypass -File $(SCRIPT) package

verify:
	@$(POWERSHELL) -NoProfile -ExecutionPolicy Bypass -File $(SCRIPT) verify

clean:
	@$(POWERSHELL) -NoProfile -ExecutionPolicy Bypass -File $(SCRIPT) clean
