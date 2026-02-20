VERSION  := $(shell grep '^version:' galaxy.yml | awk '{print $$2}')
TARBALL  := maglo-qemu-$(VERSION).tar.gz

.PHONY: build clean release help

build: ## Build the collection tarball
	ansible-galaxy collection build --force

clean: ## Remove built tarballs
	rm -f maglo-qemu-*.tar.gz

# Usage: make release VERSION=x.y.z
release: ## Compile changelog and prepare a release. Usage: make release VERSION=x.y.z
	@test -n "$(VERSION)" || { echo "Usage: make release VERSION=x.y.z"; exit 1; }
	antsibull-changelog release --version $(VERSION)
	sed -i.bak "s/^version:.*/version: $(VERSION)/" galaxy.yml && rm -f galaxy.yml.bak
	ansible-galaxy collection build --force
	@echo ""
	@echo "Release $(VERSION) prepared. Next steps:"
	@echo "  1. Review: git diff"
	@echo "  2. Commit: git add CHANGELOG.rst changelogs/changelog.yaml galaxy.yml"
	@echo "             git commit -m 'Release v$(VERSION)'"
	@echo "  3. Open PR, get it merged to main, then tag:"
	@echo "       git tag -a v$(VERSION) -m 'Release v$(VERSION)'"
	@echo "       git push origin v$(VERSION)"
	@echo "     The GitHub Actions release workflow will create a GitHub Release"
	@echo "     and attach $(TARBALL) automatically."

# Uncomment to publish to Ansible Galaxy.
# Requires GALAXY_API_KEY to be set in the environment.
# publish: build ## Publish to Ansible Galaxy (requires GALAXY_API_KEY)
# 	ansible-galaxy collection publish $(TARBALL) --api-key $(GALAXY_API_KEY)

help: ## Show available targets
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | \
		awk 'BEGIN {FS = ":.*?## "}; {printf "  %-10s %s\n", $$1, $$2}'
