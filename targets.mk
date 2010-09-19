ifdef PACKAGE_DIR
ifndef $(PACKAGE_DIR)_TARGETS
$(PACKAGE_DIR)_TARGETS:=true

# get the ezs to depend on the beams, hrls and $(DIST_DIR)
$(foreach EZ,$($(PACKAGE_DIR)_OUTPUT_EZS),$(eval $(PACKAGE_DIR)/$(DIST_DIR)/$(EZ): $($(PACKAGE_DIR)_EBIN_BEAMS) $($(PACKAGE_DIR)_INCLUDE_HRLS)))

$($(PACKAGE_DIR)_DEPS_FILE)_EBIN_DIR:=$($(PACKAGE_DIR)_EBIN_DIR)
$($(PACKAGE_DIR)_DEPS_FILE): $($(PACKAGE_DIR)_SOURCE_ERLS) $($(PACKAGE_DIR)_INCLUDE_HRLS)
	escript $(@D)/../generate_deps $@ $($(@D)_EBIN_DIR) $^

$($(PACKAGE_DIR)_EBIN_DIR)_INCLUDE_DIR:=$($(PACKAGE_DIR)_INCLUDE_DIR)
$($(PACKAGE_DIR)_EBIN_DIR)/%.beam: $($(PACKAGE_DIR)_SOURCE_DIR)/%.erl | $($(PACKAGE_DIR)_EBIN_DIR)
	ERL_LIBS=$(DIST_DIR) $(ERLC) $(ERLC_OPTS) -I $($(@D)_INCLUDE_DIR) -pa $(@D) -o $(@D) $<

$($(PACKAGE_DIR)_EBIN_DIR):
	mkdir -p $@

# only do the _app.in => .app dance if we can actually find a _app.in
ifneq "$(wildcard $($(PACKAGE_DIR)_EBIN_DIR)/$($(PACKAGE_DIR)_APP_NAME)_app.in)" ""
$($(PACKAGE_DIR)_EBIN_DIR)/$($(PACKAGE_DIR)_APP_NAME).app: $($(PACKAGE_DIR)_EBIN_DIR)/$($(PACKAGE_DIR)_APP_NAME)_app.in
	sed -e 's:%%VSN%%:$(VERSION):g' < $< > $@

.PHONY: $(PACKAGE_DIR)/clean_app
clean:: $(PACKAGE_DIR)/clean_app
$(PACKAGE_DIR)/clean_app:
	rm -f $($(@D)_EBIN_DIR)/$($(@D)_APP_NAME).app
endif

.PHONY: $(PACKAGE_DIR)/clean
clean:: $(PACKAGE_DIR)/clean
$(PACKAGE_DIR)/clean::
	rm -f $($(@D)_DEPS_FILE)
	rm -rf $(@D)/$(DIST_DIR)
	rm -f $($(@D)_EBIN_BEAMS)

$($(PACKAGE_DIR)_EBIN_BEAMS): $($(PACKAGE_DIR)_DEPS_FILE)

# only set up a target for the plain package ez. Other ezs must be
# handled manually. .beam dependencies et al are created by the
# generic output_ezs dependencies. For ease of comprehension, we save
# out variables that we need.
$(PACKAGE_DIR)/$(DIST_DIR)/$(PACKAGE_NAME).ez_DIR:=$(PACKAGE_DIR)/$(DIST_DIR)/$(PACKAGE_NAME)
$(PACKAGE_DIR)/$(DIST_DIR)/$(PACKAGE_NAME).ez_APP:=$($(PACKAGE_DIR)_EBIN_DIR)/$($(PACKAGE_DIR)_APP_NAME).app
$(PACKAGE_DIR)/$(DIST_DIR)/$(PACKAGE_NAME).ez_EBIN_BEAMS:=$($(PACKAGE_DIR)_EBIN_BEAMS)
$(PACKAGE_DIR)/$(DIST_DIR)/$(PACKAGE_NAME).ez_INCLUDE_HRLS:=$($(PACKAGE_DIR)_INCLUDE_HRLS)
$(PACKAGE_DIR)/$(DIST_DIR)/$(PACKAGE_NAME).ez: $($(PACKAGE_DIR)_EBIN_DIR)/$($(PACKAGE_DIR)_APP_NAME).app | $(PACKAGE_DIR)/$(DIST_DIR)
	rm -rf $@ $($@_DIR)
	mkdir -p $($@_DIR)/ebin $($@_DIR)/include
	$(foreach BEAM,$($@_EBIN_BEAMS),cp $(BEAM) $($@_DIR)/ebin;)
	$(foreach HRL,$($@_INCLUDE_HRLS),cp $(HRL) $($@_DIR)/include;)
	cp $($@_APP) $($@_DIR)/ebin
	cd $(dir $($@_DIR)) && zip -r $@ $(notdir $(basename $@))

define generic_ez
# $(EZ) is in $(1)
ifneq "$(1)" "$(PACKAGE_NAME).ez"
.PHONY: $(PACKAGE_DIR)/$(DIST_DIR)/$(1)
$(PACKAGE_DIR)/$(DIST_DIR)/$(1):
	$(MAKE) -C $(PACKAGE_DIR)/$(DEPS_DIR)/$(basename $(1)) -j
	cp $(PACKAGE_DIR)/$(DEPS_DIR)/$(basename $(1))/$(1) $$@

$(PACKAGE_DIR)/clean::
	$(MAKE) -C $(PACKAGE_DIR)/$(DEPS_DIR)/$(basename $(1)) clean
endif
endef

$(foreach EZ,$($(PACKAGE_DIR)_OUTPUT_EZS),$(eval $(call generic_ez,$(EZ))))

ifneq "$(strip $(TESTABLEGOALS))" "$($(PACKAGE_DIR)_DEPS_FILE)"
ifneq "$(strip $(patsubst clean%,,$(patsubst %clean,,$(TESTABLEGOALS))))" ""
-include $($(PACKAGE_DIR)_DEPS_FILE)
endif
endif

endif
endif
