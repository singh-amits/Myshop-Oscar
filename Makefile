VENV = oscar
PYTEST = $(PWD)/$(VENV)/bin/py.test

# These targets are not files
.PHONY: build_sandbox clean compile_translations coverage css docs extract_translations help install install-python \
 install-test install-js lint release retest sandbox_clean sandbox_image sandbox test todo venv

help: ## Display this help message
	@echo "Please use \`make <target>\` where <target> is one of"
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | sort | awk 'BEGIN {FS = ":.*?## "}; \
	{printf "\033[36m%-40s\033[0m %s\n", $$1, $$2}'

##################
# Install commands
##################
install: install-python install-test assets ## Install requirements for local development and production

install-python: ## Install python requirements
	pip install -r requirements.txt

install-test: ## Install test requirements
	pip install -e .[test]

install-migrations-testing-requirements: ## Install migrations testing requirements
	pip install -r requirements_migrations.txt

assets: ## Install static assets
	npm install
	npm run build

venv: ## Create a virtual env and install test and production requirements
	$(shell which python3) -m venv $(VENV)
	$(VENV)/bin/pip install -e .[test]
	$(VENV)/bin/pip install -r docs/requirements.txt

#############################
# sandbox management commands
#############################
sandbox: install build_sandbox ## Install requirements and create a sandbox

build_sandbox: sandbox_clean sandbox_load_user sandbox_load_data ## Creates a sandbox from scratch

sandbox_clean: ## Clean sandbox images,cache,static and database
	# Remove media
	# -rm -rf sandbox/public/media/images
	# -rm -rf sandbox/public/media/cache
	# -rm -rf sandbox/public/static
	# -rm -f sandbox/db.sqlite
	# Create database
	myshop/manage.py migrate

sandbox_load_user: ## Load user data into sandbox
	myshop/manage.py loaddata myshop/fixtures/auth.json

sandbox_load_data: ## Import fixtures and collect static
	# Import some fixtures. Order is important as JSON fixtures include primary keys
	myshop/manage.py loaddata myshop/fixtures/child_products.json
	myshop/manage.py oscar_import_catalogue myshop/fixtures/*.csv
	myshop/manage.py oscar_import_catalogue_images myshop/fixtures/images.tar.gz
	myshop/manage.py oscar_populate_countries --initial-only
	myshop/manage.py loaddata myshop/fixtures/pages.json myshop/fixtures/ranges.json myshop/fixtures/offers.json
	myshop/manage.py loaddata myshop/fixtures/orders.json
	myshop/manage.py clear_index --noinput
	myshop/manage.py update_index catalogue
	myshop/manage.py thumbnail cleanup
	myshop/manage.py collectstatic --noinput
	myshop/manage.py oscar_import_catalogue myshop/fixtures/amazon_asin_more.csv
	

sandbox_image: ## Build latest docker image of django-oscar-sandbox
	docker build -t django-oscar-sandbox:latest .

##################
# Tests and checks
##################
test: venv ## Run tests
	$(PYTEST)

retest: venv ## Run failed tests only
	$(PYTEST) --lf

coverage: venv ## Generate coverage report
	$(PYTEST) --cov=oscar --cov-report=term-missing

lint: ## Run flake8 and isort checks
	flake8 src/oscar/
	flake8 tests/
	isort -c -q --diff src/ tests/

test_migrations: install-migrations-testing-requirements ## Tests migrations
	cd sandbox && ./test_migrations.sh

#######################
# Translations Handling
#######################
extract_translations: ## Extract strings and create source .po files
	cd src/oscar; django-admin.py makemessages -a

compile_translations: ## Compile translation files and create .mo files
	cd src/oscar; django-admin.py compilemessages

######################
# Project Management
######################
clean: ## Remove files not in source control
	find . -type f -name "*.pyc" -delete
	rm -rf nosetests.xml coverage.xml htmlcov *.egg-info *.pdf dist violations.txt

docs: venv ## Compile docs
	make -C docs html SPHINXBUILD=$(PWD)/$(VENV)/bin/sphinx-build

todo: ## Look for areas of the code that need updating when some event has taken place (like Oscar dropping support for a Django version)
	-grep -rnH TODO *.txt
	-grep -rnH TODO src/oscar/apps/
	-grep -rnH "django.VERSION" src/oscar/apps

release: clean ## Creates release
	pip install twine wheel
	rm -rf dist/*
	rm -rf src/oscar/static/*
	npm run build
	python setup.py sdist bdist_wheel
	twine upload -s dist/*
