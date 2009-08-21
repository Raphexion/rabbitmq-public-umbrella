# This is a global include file for all Makefiles. It is expected that modules
# will include it with a command similar to "include ../include.mk". Before
# inclusion, the following variables MUST be set:
#  PACKAGE=    -- The name of the package
# 
# The following optional variables can be set if your build requires it:
#  DEPS                 -- Other projects that your build depends on (eg rabbitmq-server)
#  INTERNAL_DEPS        -- Internal dependencies that need to be built and included.
#  GENERATED_SOURCES	-- The names of modules that are automatically generated.
#			   Note that the names provided should EXCLUDE the .erl extension 
#  EXTRA_PACKAGE_DIRS   -- The names of extra directories (over ebin) that should be included
#			   in distribution packages
#  TEST_APPS            -- Applications that should be started as part of the VM that your tests
#                          run in
#  START_RABBIT_IN_TESTS -- If set, a Rabbit broker instance will be started as part of the test VM
#  TEST_ARGS            -- Appended to the erl command line when running or running tests.
#                          Beware of quote escaping issues!

EBIN_DIR=ebin
TEST_EBIN_DIR=test_ebin
SOURCE_DIR=src
TEST_DIR=test
INCLUDE_DIR=include
DIST_DIR=dist
DEPS_DIR=deps
PRIV_DEPS_DIR=build/deps
ROOT_DIR=..

SHELL=/bin/bash
ERLC=erlc
ERL=erl

SOURCES=$(wildcard $(SOURCE_DIR)/*.erl)
TEST_SOURCES=$(wildcard $(TEST_DIR)/*.erl)
DEP_EZS=$(foreach DEP, $(DEPS), $(wildcard $(ROOT_DIR)/$(DEP)/$(DIST_DIR)/*.ez))
DEP_NAMES=$(patsubst %.ez, %, $(foreach DEP_EZ, $(DEP_EZS), $(shell basename $(DEP_EZ))))

TARGETS=$(foreach DEP, $(INTERNAL_DEPS), $(DEPS_DIR)/$(DEP)/ebin) \
	$(foreach DEP_NAME, $(DEP_NAMES), $(PRIV_DEPS_DIR)/$(DEP_NAME)/ebin) \
	$(foreach GEN, $(GENERATED_SOURCES), src/$(GEN).erl)  \
        $(patsubst $(SOURCE_DIR)/%.erl, $(EBIN_DIR)/%.beam, $(SOURCES)) \
        $(foreach GEN, $(GENERATED_SOURCES), ebin/$(GEN).beam)
TEST_TARGETS=$(patsubst $(TEST_DIR)/%.erl, $(TEST_EBIN_DIR)/%.beam, $(TEST_SOURCES))

ERLC_OPTS=$(INCLUDE_OPTS) -o $(EBIN_DIR) -Wall
TEST_ERLC_OPTS=$(INCLUDE_OPTS) -o $(TEST_EBIN_DIR) -Wall

DEPS_LOAD_PATH=$(foreach DEP, $(DEP_NAMES), -pa $(PRIV_DEPS_DIR)/$(DEP)/ebin) \
	$(foreach DEP, $(INTERNAL_DEPS), -pa $(DEPS_DIR)/$(DEP)/ebin)
TEST_LOAD_PATH=-pa $(EBIN_DIR) -pa $(TEST_EBIN_DIR) $(DEPS_LOAD_PATH)

INCLUDE_OPTS=-I $(INCLUDE_DIR) $(DEPS_LOAD_PATH)

LOG_BASE=/tmp
LOG_IN_FILE=true
RABBIT_SERVER=rabbitmq-server
ADD_BROKER_ARGS=-pa $(ROOT_DIR)/$(RABBIT_SERVER)/ebin -mnesia dir tmp -boot start_sasl -s rabbit -sname rabbit\
        $(shell [ $(LOG_IN_FILE) = "true" ] && echo "-sasl sasl_error_logger '{file, \"'${LOG_BASE}'/rabbit-sasl.log\"}' -kernel error_logger '{file, \"'${LOG_BASE}'/rabbit.log\"}'")
ifeq ($(START_RABBIT_IN_TESTS),)
FULL_TEST_ARGS=$(TEST_ARGS)
else
FULL_TEST_ARGS=$(ADD_BROKER_ARGS) $(TEST_ARGS)
endif

TEST_APP_ARGS=$(foreach APP,$(TEST_APPS),-eval 'ok = application:start($(APP))')

all: package

diag:
	@echo DEP_EZS=$(DEP_EZS)
	@echo DEP_NAMES=$(DEP_NAMES)
	@echo TARGETS=$(TARGETS)
	@echo INCLUDE_OPTS=$(INCLUDE_OPTS)

$(EBIN_DIR):
	mkdir -p $(EBIN_DIR)

$(EBIN_DIR)/%.beam: $(SOURCE_DIR)/%.erl
	@mkdir -p $(EBIN_DIR)
	$(ERLC) $(ERLC_OPTS) -pa $(EBIN_DIR) $<

$(TEST_EBIN_DIR):
	mkdir -p $(TEST_EBIN_DIR)

$(TEST_EBIN_DIR)/%.beam: $(TEST_DIR)/%.erl
	@mkdir -p $(TEST_EBIN_DIR)
	$(ERLC) $(TEST_ERLC_OPTS) -pa $(TEST_EBIN_DIR) $<

$(DEPS_DIR)/%/ebin:
	$(MAKE) -C $(shell dirname $@)

$(PRIV_DEPS_DIR)/%/ebin:
	@mkdir -p $(PRIV_DEPS_DIR)
	$(foreach EZ, $(DEP_EZS), cp $(EZ) $(PRIV_DEPS_DIR) &&) true
	(cd $(PRIV_DEPS_DIR); unzip $*.ez)

list-deps:
	@echo $(foreach DEP, $(INTERNAL_DEPS), $(DEPS_DIR)/$(DEP))

package: $(DIST_DIR)/$(PACKAGE).ez

$(DIST_DIR)/$(PACKAGE).ez: $(TARGETS)
	rm -rf $(DIST_DIR)
	mkdir -p $(DIST_DIR)/$(PACKAGE)
	cp -r $(EBIN_DIR) $(DIST_DIR)/$(PACKAGE)
	$(foreach EXTRA_DIR, $(EXTRA_PACKAGE_DIRS), cp -r $(EXTRA_DIR) $(DIST_DIR)/$(PACKAGE);)
	(cd $(DIST_DIR); zip -r $(PACKAGE).ez $(PACKAGE))
	$(foreach DEP, $(INTERNAL_DEPS), cp $(DEPS_DIR)/$(DEP)/$(DEP).ez $(DIST_DIR))
	$(foreach DEP, $(DEP_NAMES), cp $(PRIV_DEPS_DIR)/$(DEP).ez $(DIST_DIR) &&) true

test:	$(TARGETS) $(TEST_TARGETS)
	$(ERL) $(TEST_LOAD_PATH) -noshell $(FULL_TEST_ARGS) $(TEST_APP_ARGS) -eval "$(foreach CMD,$(TEST_COMMANDS),$(CMD), )halt()."

run:	$(TARGETS) $(TEST_TARGETS)
	$(ERL) $(TEST_LOAD_PATH) $(FULL_TEST_ARGS) $(TEST_APP_ARGS)

clean:
	rm -f $(EBIN_DIR)/*.beam
	rm -f $(TEST_EBIN_DIR)/*.beam
	rm -f erl_crash.dump
	rm -rf $(PRIV_DEPS_DIR)
	$(foreach GEN, $(GENERATED_SOURCES), rm -f src/$(GEN);)
	$(foreach DEP, $(INTERNAL_DEPS), $(MAKE) -C $(DEPS_DIR)/$(DEP) clean)
	rm -rf $(DIST_DIR)
