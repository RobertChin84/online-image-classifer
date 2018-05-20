.PHONY: clean data lint install-deps install-deps-all test test-cov test-all type-check sync-data-to-s3 sync-data-from-s3 sync-data-to-gcs sync-data-from-gcs

#################################################################################
# GLOBALS                                                                       #
#################################################################################

PROJECT_DIR := $(shell dirname $(realpath $(lastword $(MAKEFILE_LIST))))
S3_BUCKET = [OPTIONAL] your-bucket-for-syncing-data (do not include 's3://')
AWS_PROFILE = default
PROJECT_NAME = online-image-classifier
PYTHON_INTERPRETER = python3
GCS_BUCKET = [OPTIONAL] your-bucket-for-syncing-data (do not include 'gs://')
GCP_PROJECT = default

#################################################################################
# COMMANDS                                                                      #
#################################################################################


## Installs just the app dependencies into a Pipenv (virtualenv) environment
install-deps:
	pipenv install

## Installs all of the dependencies into a Pipenv (virtualenv) environment
install-deps-all:
	pipenv install --dev

## Runs the whole test suite
test:
	PYTHONPATH=./src pipenv run $(PYTHON_INTERPRETER) -m pytest src

## Runs the whole test suite and produces a command line coverage report
test-cov:
	PYTHONPATH=./src pipenv run $(PYTHON_INTERPRETER) -m pytest --cov-config=setup.cfg --cov=src src

## Runs the static type checker
type-check:
	MYPYPATH="$$(pwd)/src" pipenv run $(PYTHON_INTERPRETER) -m mypy src

## Runs the flake8 linter and static type checker
lint:
	pipenv run $(PYTHON_INTERPRETER) -m flake8 src

## Runs the linter and the test suite
test-all: type-check lint test

## Make Dataset
data: install-deps-all
	$(PYTHON_INTERPRETER) src/data/make_dataset.py

## Delete all compiled Python files
clean:
	find . -type f -name "*.py[co]" -delete
	find . -type d -name "__pycache__" -delete


## Upload Data to S3
sync-data-to-s3:
ifeq (default,$(AWS_PROFILE))
	aws s3 sync data/ s3://$(S3_BUCKET)/data/
else
	aws s3 sync data/ s3://$(S3_BUCKET)/data/ --profile $(AWS_PROFILE)
endif

## Download Data from S3
sync-data-from-s3:
ifeq (default,$(AWS_PROFILE))
	aws s3 sync s3://$(S3_BUCKET)/data/ data/
else
	aws s3 sync s3://$(S3_BUCKET)/data/ data/ --profile $(AWS_PROFILE)
endif

## Upload Data to GCS
sync-data-to-gcs:
ifeq (default,$(GCP_PROJECT))
	gsutil rsync data/ gs://$(GCS_BUCKET)/data
else
	gcloud config set project $(GCP_PROJECT)
	gsutil rsync data/ gs://$(GCS_BUCKET)/data
	echo "\nWARNING: Please note that your default GCP project has changed to $(GCP_PROJECT)"
endif

## Download Data to GCS
sync-data-from-gcs:
ifeq (default,$(GCP_PROJECT))
	gsutil rsync gs://$(GCS_BUCKET)/data data/
else
	gcloud config set project $(GCP_PROJECT)
	gsutil rsync gs://$(GCS_BUCKET)/data data/
	echo "\nWARNING: Please note that your default GCP project has changed to $(GCP_PROJECT)"
endif



#################################################################################
# PROJECT RULES                                                                 #
#################################################################################



#################################################################################
# Self Documenting Commands                                                     #
#################################################################################

.DEFAULT_GOAL := show-help

# Inspired by <http://marmelab.com/blog/2016/02/29/auto-documented-makefile.html>
# sed script explained:
# /^##/:
# 	* save line in hold space
# 	* purge line
# 	* Loop:
# 		* append newline + line to hold space
# 		* go to next line
# 		* if line starts with doc comment, strip comment character off and loop
# 	* remove target prerequisites
# 	* append hold space (+ newline) to line
# 	* replace newline plus comments by `---`
# 	* print line
# Separate expressions are necessary because labels cannot be delimited by
# semicolon; see <http://stackoverflow.com/a/11799865/1968>
.PHONY: show-help
show-help:
	@echo "$$(tput bold)Available rules:$$(tput sgr0)"
	@echo
	@sed -n -e "/^## / { \
		h; \
		s/.*//; \
		:doc" \
		-e "H; \
		n; \
		s/^## //; \
		t doc" \
		-e "s/:.*//; \
		G; \
		s/\\n## /---/; \
		s/\\n/ /g; \
		p; \
	}" ${MAKEFILE_LIST} \
	| LC_ALL='C' sort --ignore-case \
	| awk -F '---' \
		-v ncol=$$(tput cols) \
		-v indent=19 \
		-v col_on="$$(tput setaf 6)" \
		-v col_off="$$(tput sgr0)" \
	'{ \
		printf "%s%*s%s ", col_on, -indent, $$1, col_off; \
		n = split($$2, words, " "); \
		line_length = ncol - indent; \
		for (i = 1; i <= n; i++) { \
			line_length -= length(words[i]) + 1; \
			if (line_length <= 0) { \
				line_length = ncol - indent - length(words[i]) - 1; \
				printf "\n%*s ", -indent, " "; \
			} \
			printf "%s ", words[i]; \
		} \
		printf "\n"; \
	}' \
	| more $(shell test $(shell uname) = Darwin && echo '--no-init --raw-control-chars')
