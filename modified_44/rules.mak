MLOG = log-$(shell date +%Y%m%d ).log
f1-echo=$(shell echo `date +%Y%m%d-%H%M%S` rulesmak line:$1 tgt:$@ "$2" "$3" "$4" "$5" "$6" "$7" "$8" >> $(MLOG) )
# These are used when we want to do substitutions without confusing Make
NULL  :=
SPACE := $(NULL) #
COMMA := ,

# Don't use implicit rules or variables
# we have explicit rules for everything
MAKEFLAGS += -rR

# Files with this suffixes are final, don't try to generate them
# using implicit rules
%/trace-events:
	$(call f1-echo,15,stem= $*)
%.hx:
	$(call f1-echo,16,stem= $*)
%.py:
%.objs:
	$(call f1-echo,19,stem= $*)
%.d:
%.h:
	$(call f1-echo,22,stem= $*)
%.c:
%.cc:
%.cpp:
%.m:
%.mak:
clean-target:
%.json:
	$(call f1-echo,30,stem= $*)
trace/generated-%:
	$(call f1-echo,32,stem= $*)
trace-events:
	$(call f1-echo,35)
trace-events-%:
	$(call f1-echo,37,stem= $*)
	
# Flags for dependency generation
QEMU_DGFLAGS += -MMD -MP -MT $@ -MF $(@D)/$(*F).d

# Compiler searches the source file dir first, but in vpath builds
# we need to make it search the build dir too, before any other
# explicit search paths. There are two search locations in the build
# dir, one absolute and the other relative to the compiler working
# directory. These are the same for target-independent files, but
# different for target-dependent ones.
QEMU_LOCAL_INCLUDES = -iquote $(BUILD_DIR)/$(@D) -iquote $(@D)

WL_U := -Wl,-u,
find-symbols = $(if $1, $(sort $(shell $(NM) -P -g $1 | $2)))
defined-symbols = $(call find-symbols,$1,awk '$$2!="U"{print $$1}')
undefined-symbols = $(call find-symbols,$1,awk '$$2=="U"{print $$1}')

# All the .mo objects in -m variables are also added into corresponding -y
# variable in unnest-vars, but filtered out here, when LINK is called.
#
# The .mo objects are supposed to be linked as a DSO, for module build. So here
# they are only used as a placeholders to generate those "archive undefined"
# symbol options (-Wl,-u,$symbol_name), which are the archive functions
# referenced by the code in the DSO.
#
# Also the presence in -y variables will also guarantee they are built before
# linking executables that will load them. So we can look up symbol reference
# in LINK.
#
# This is necessary because the exectuable itself may not use the function, in
# which case the function would not be linked in. Then the DSO loading will
# fail because of the missing symbol.
process-archive-undefs = $(filter-out %.a %.mo,$1) \
                $(addprefix $(WL_U), \
                     $(filter $(call defined-symbols,$(filter %.a, $1)), \
                              $(call undefined-symbols,$(filter %.mo,$1)))) \
                $(filter %.a,$1)

extract-libs = $(strip $(foreach o,$(filter-out %.mo,$1),$($o-libs)))
expand-objs = $(strip $(sort $(filter %.o,$1)) \
                  $(foreach o,$(filter %.mo,$1),$($o-objs)) \
                  $(filter-out %.o %.mo,$1))

%.o: %.c
	$(call quiet-command,69, $(CC) $(QEMU_LOCAL_INCLUDES) \
	$(QEMU_INCLUDES)  $(QEMU_CFLAGS) $(QEMU_DGFLAGS) $(CFLAGS) $($@-cflags) \
	-c -o $@ $<,"CC","$(TARGET_DIR)$@")

%.o: %.rc
	$(call quiet-command,73,$(WINDRES) -I. -o $@ $<,"RC","$(TARGET_DIR)$@")
# If we have a CXX we might have some C++ objects, in which case we
# must link with the C++ compiler, not the plain C compiler.
LINKPROG = $(or $(CXX),$(CC))

LINK = $(call quiet-command,79, $(LINKPROG) $(QEMU_LDFLAGS) $(QEMU_CFLAGS) $(CFLAGS) $(LDFLAGS) -o $@ $(call process-archive-undefs, $1) $(version-obj-y) $(call extract-libs,$1) $(LIBS),"LINK","$(TARGET_DIR)$@")

%.o: %.S
	$(call quiet-command,84,$(CCAS) $(QEMU_LOCAL_INCLUDES) $(QEMU_INCLUDES) \
	       $(QEMU_CFLAGS) $(QEMU_DGFLAGS) $(CFLAGS) \
	       -c -o $@ $<,"CCAS","$(TARGET_DIR)$@")

%.o: %.cc
	$(call quiet-command,89,$(CXX) $(QEMU_LOCAL_INCLUDES) $(QEMU_INCLUDES) \
	       $(QEMU_CXXFLAGS) $(QEMU_DGFLAGS) $(CFLAGS) $($@-cflags) \
	       -c -o $@ $<,"CXX","$(TARGET_DIR)$@")

%.o: %.cpp
	$(call quiet-command,94,$(CXX) $(QEMU_LOCAL_INCLUDES) $(QEMU_INCLUDES) \
	  $(QEMU_CXXFLAGS) $(QEMU_DGFLAGS) $(CFLAGS) $($@-cflags) \
	      -c -o $@ $<,"CXX","$(TARGET_DIR)$@")



%.o: %.m
	$(call quiet-command,99,$(OBJCC) $(QEMU_LOCAL_INCLUDES) $(QEMU_INCLUDES) \
	       $(QEMU_CFLAGS) $(QEMU_DGFLAGS) $(CFLAGS) $($@-cflags) \
	       -c -o $@ $<,"OBJC","$(TARGET_DIR)$@")

%.o: %.dtrace
	$(call quiet-command,117,dtrace -o $@ -G -s $<,"GEN","$(TARGET_DIR)$@")

DSO_OBJ_CFLAGS := -fPIC -DBUILD_DSO

module-common.o: CFLAGS += $(DSO_OBJ_CFLAGS)
#	$(call f1-echo,108, var $(CFLAGS))
	
%$(DSOSUF): LDFLAGS += $(LDFLAGS_SHARED)
#	$(call f1-echo,111, var $(LDFLAGS))
	
%$(DSOSUF): %.mo
#	$(call LINK,$^)
# Copy to build root so modules can be loaded when program started without install
#	$(if $(findstring /,$@),$(call quiet-command,116,cp $@ $(subst /,-,$@),"CP","$(subst /,-,$@)"))


LD_REL = $(CC) -nostdlib $(LD_REL_FLAGS)

%.mo:
#	$(call quiet-command,118,$(LD_REL) -o $@ $^,"LD","$(TARGET_DIR)$@")

	
.PHONY: modules
modules:
	$(call f1-echo,130)
	
%$(EXESUF): %.o
	$(call f1-echo,129,LINK, $^)
	$(call LINK,$(filter %.o %.a %.mo, $^))
%.a:
	$(call quiet-command,132, rm -f $@ && $(AR) rcs $@ $^,"AR","$(TARGET_DIR)$@")

# Usage: $(call quiet-command,command and args,"NAME","args to print")
# This will run "command and args", and either:
#  if V=1 just print the whole command and args
#  otherwise print the 'quiet' output in the format "  NAME     args to print"
# NAME should be a short name of the command, 7 letters or fewer.
# If called with only a single argument, will print nothing in quiet mode.
#quiet-command $(if $(V),$1,$(if $(2),@printf "  %-7s %s\n" $2 $3 && $1, @$1))
r-quiet-command = $(if $(V),$1,$(if $(2),@printf "  %-7s %s\n" $2 $3 && $1, @$1))
quiet-command = $(shell echo `date +%Y%m%d-%H%M%S` rulesmak line:$1 tgt:$@ "\n" call quiet-command ::2::"$2" ::2:: "\n" ::3::"$3" ::3:: ::4::"$4"::4:: >> $(MLOG))
#		echo cmdcall: $(if $(V),$2,$(if $(3),@printf "  %-7s %s\n" $3 $4  && $2, @$2)) >> $(MLOG) ) 

# cc-option
# Usage: CFLAGS+=$(call cc-option, -falign-functions=0, -malign-functions=0)

cc-option = $(if $(shell $(CC) $1 $2 -S -o /dev/null -xc /dev/null >/dev/null 2>&1 && echo OK), $2, $3)
cc-c-option = $(if $(shell $(CC) $1 $2 -c -o /dev/null -xc /dev/null >/dev/null 2>&1 && echo OK), $2, $3)

VPATH_SUFFIXES = %.c %.h %.S %.cc %.cpp %.m %.mak %.texi %.sh %.rc
set-vpath = $(if $1,$(foreach PATTERN,$(VPATH_SUFFIXES),$(eval vpath $(PATTERN) $1)))

# install-prog list, dir
define install-prog
	$(INSTALL_DIR) "$2"
	$(INSTALL_PROG) $1 "$2"
	$(if $(STRIP),$(STRIP) $(foreach T,$1,"$2/$(notdir $T)"),)
endef

# find-in-path
# Usage: $(call find-in-path, prog)
# Looks in the PATH if the argument contains no slash, else only considers one
# specific directory.  Returns an # empty string if the program doesn't exist
# there.
find-in-path = $(if $(findstring /, $1),  $(wildcard $1), $(wildcard $(patsubst %, %/$1, $(subst :, ,$(PATH)))))

# Logical functions (for operating on y/n values like CONFIG_FOO vars)
# Inputs to these must be either "y" (true) or "n" or "" (both false)
# Output is always either "y" or "n".
# Usage: $(call land,$(CONFIG_FOO),$(CONFIG_BAR))
# Logical NOT
lnot = $(if $(subst n,,$1),n,y)
# Logical AND
land = $(if $(findstring yy,$1$2),y,n)
# Logical OR
lor = $(if $(findstring y,$1$2),y,n)
# Logical XOR (note that this is the inverse of leqv)
lxor = $(if $(filter $(call lnot,$1),$(call lnot,$2)),n,y)
# Logical equivalence (note that leqv "","n" is true)
leqv = $(if $(filter $(call lnot,$1),$(call lnot,$2)),y,n)
# Logical if: like make's $(if) but with an leqv-like test
lif = $(if $(subst n,,$1),$2,$3)

# String testing functions: inputs to these can be any string;
# the output is always either "y" or "n". Leading and trailing whitespace
# is ignored when comparing strings.
# String equality
eq = $(if $(subst $2,,$1)$(subst $1,,$2),n,y)
# String inequality
ne = $(if $(subst $2,,$1)$(subst $1,,$2),y,n)
# Emptiness/non-emptiness tests:
isempty = $(if $1,n,y)
notempty = $(if $1,y,n)

# Generate files with tracetool
TRACETOOL = $(PYTHON) $(SRC_PATH)/scripts/tracetool.py

# Generate timestamp files for .h include files



config-%.h: config-%.h-timestamp
	$(call f1-echo,205,stem=$*, "@cmp $< $@ >/dev/null 2>&1 || cp $< $@" )

config-%.h-timestamp: config-%.mak $(SRC_PATH)/scripts/create_config
	$(call quiet-command,208,stem=$* "$(SRC_PATH)/scripts/create_config < $< > $@","GEN","$(TARGET_DIR)config-$*.h")


.PHONY: clean-timestamp
clean-timestamp:
	$(call f1-echo,213, "rm -f *.timestamp")
clean: clean-timestamp
	$(call f1-echo,215)
# will delete the target of a rule if commands exit with a nonzero exit status
.DELETE_ON_ERROR:
	$(call f1-echo,218)
# save-vars
# Usage: $(call save-vars, vars)
# Save each variable $v in $vars as save-vars-$v, save their object's
# variables, then clear $v.  saved-vars-$v contains the variables that
# where saved for the objects, in order to speedup load-vars.
define save-vars
 $(call f1-echo,225,--begin save-vars--)
	$(foreach v,$1, 
	$(eval save-vars-$v := $(value $v))
	$(eval saved-vars-$v := $(foreach o,$($v),  $(if $($o-cflags), $o-cflags $(eval save-vars-$o-cflags := $($o-cflags))$(eval $o-cflags := ))  $(if $($o-libs), $o-libs $(eval save-vars-$o-libs := $($o-libs))$(eval $o-libs := ))  $(if $($o-objs), $o-objs $(eval save-vars-$o-objs := $($o-objs))$(eval $o-objs := ))))  $(eval $v := ))
 $(call f1-echo,235,--end save-vars---)
endef

# load-vars
# Usage: $(call load-vars, vars, add_var)
# Load the saved value for each variable in @vars, and the per object
# variables.
# Append @add_var's current value to the loaded value.
define load-vars
	$(call f1-echo,244,--begin load-vars---, var $2)
    $(eval $2-new-value := $(value $2))
    $(foreach v,$1,
		 $(eval $v := $(value save-vars-$v))
        $(foreach o,$(saved-vars-$v),
		    $(eval $o := $(save-vars-$o))
			$(eval save-vars-$o := ))
        $(eval save-vars-$v := )
        $(eval saved-vars-$v := ))
    $(eval $2 := $(value $2) $($2-new-value))
	$(call f1-echo,255, ---end-load-vars---)
endef

# fix-paths
# Usage: $(call fix-paths, obj_path, src_path, vars)
# Add prefix @obj_path to all objects in @vars, and add prefix @src_path to all
# directories in @vars.
define fix-paths
	$(call f1-echo,256,--begin fix-paths--, var $3)
    $(foreach v,$3,
        $(foreach o,$($v),
            $(if $($o-libs),
                $(eval $1$o-libs := $($o-libs)))
            $(if $($o-cflags),
                $(eval $1$o-cflags := $($o-cflags)))
            $(if $($o-objs),
                $(eval $1$o-objs := $(addprefix $1,$($o-objs)))))
        $(eval $v := $(addprefix $1,$(filter-out %/,$($v))) \
                     $(addprefix $2,$(filter %/,$($v)))))
	$(call f1-echo,267,--end fix-paths--)
endef

# unnest-var-recursive
# Usage: $(call unnest-var-recursive, obj_prefix, vars, var)
#
# Unnest @var by including subdir Makefile.objs, while protect others in @vars
# unchanged.
#
# @obj_prefix is the starting point of object path prefix.
#
define unnest-var-recursive
	$(call f1-echo,279,--begin unnest-var-recursive--, 3:$3, 2:$2 1:$1)
    $(eval dirs := $(sort $(filter %/,$($3))))
    $(eval $3 := $(filter-out %/,$($3)))
    $(foreach d,$(dirs:%/=%),
            $(call save-vars,$2)
            $(eval obj := $(if $1,$1/)$d)
            $(call f1-echo, 286,  eval -include $(SRC_PATH)/$d/Makefile.objs)
            $(call fix-paths,$(if $1,$1/)$d/,$d/,$2)
            $(call load-vars,$2,$3)
            $(call unnest-var-recursive,$1,$2,$3))
	$(call f1-echo,289,--end unnest-var-recursive--)
endef

# unnest-vars
# Usage: $(call unnest-vars, obj_prefix, vars)
#
# @obj_prefix: object path prefix, can be empty, or '..', etc. Don't include
# ending '/'.
#
# @vars: the list of variable names to unnest.
#
# This macro will scan subdirectories's Makefile.objs, include them, to build
# up each variable listed in @vars.
#
# Per object and per module cflags and libs are saved with relative path fixed
# as well, those variables include -libs, -cflags and -objs. Items in -objs are
# also fixed to relative path against SRC_PATH plus the prefix @obj_prefix.
#
# All nested variables postfixed by -m in names are treated as DSO variables,
# and will be built as modules, if enabled.
#
# A simple example of the unnest:
#
#     obj_prefix = ..
#     vars = hot cold
#     hot  = fire.o sun.o season/
#     cold = snow.o water/ season/
#
# Unnest through a faked source directory structure:
#
#     SRC_PATH
#        ├── water
#        │   └── Makefile.objs──────────────────┐
#        │       │ hot += steam.o               │
#        │       │ cold += ice.mo               │
#        │       │ ice.mo-libs := -licemaker    │
#        │       │ ice.mo-objs := ice1.o ice2.o │
#        │       └──────────────────────────────┘
#        │
#        └── season
#            └── Makefile.objs──────┐
#                │ hot += summer.o  │
#                │ cold += winter.o │
#                └──────────────────┘
#
# In the end, the result will be:
#
#     hot  = ../fire.o ../sun.o ../season/summer.o
#     cold = ../snow.o ../water/ice.mo ../season/winter.o
#     ../water/ice.mo-libs = -licemaker
#     ../water/ice.mo-objs = ../water/ice1.o ../water/ice2.o
#
# Note that 'hot' didn't include 'season/' in the input, so 'summer.o' is not
# included.
#
define unnest-vars
	$(call f1-echo,345,--begin unnest-vars--, 3:$3 2:$2 1:$1)
    # In the case of target build (i.e. $1 == ..), fix path for top level
    # Makefile.objs objects
    $(if $1,$(call fix-paths,$1/,,$2))

    # Descend and include every subdir Makefile.objs
    $(foreach v, $2,
	$(call f1-echo,355,$1,$2,$v)
        $(call unnest-var-recursive,$1,$2,$v)
        # Pass the .mo-cflags and .mo-libs along to its member objects
        $(foreach o, $(filter %.mo,$($v)),
            $(call f1-echo,358,$o,$v) \
	      $(foreach p,$($o-objs),\
		$(call f1-echo,361,$o-objs,$p) \
                $(if $($o-cflags),\ 
			$(call f1-echo,363,eval,$o-cflags,$p-cflags) \
			$(eval $p-cflags += $($o-cflags)))
                $(if $($o-libs), $(eval $p-libs += $($o-libs))))))

    # For all %.mo objects that are directly added into -y, just expand them
    $(foreach v,$(filter %-y,$2),
        $(eval $v := $(foreach o,$($v),$(if $($o-objs),$($o-objs),$o))))

    $(foreach v,$(filter %-m,$2),
        # All .o found in *-m variables are single object modules, create .mo
        # for them
        $(foreach o,$(filter %.o,$($v)),
            $(eval $(o:%.o=%.mo)-objs := $o))
        # Now3:$3, 2:$2 1:$1 unify .o in -m variable to .mo
        $(eval $v := $($v:%.o=%.mo))
        $(eval modules-m += $($v))

        # For module build, build shared libraries during "make modules"
        # For non-module build, add -m to -y
        $(if $(CONFIG_MODULES),
             $(foreach o,$($v),
                   $(eval $($o-objs): CFLAGS += $(DSO_OBJ_CFLAGS))
                   $(eval $o: $($o-objs)))
             $(eval $(patsubst %-m,%-y,$v) += $($v))
             $(eval modules: $($v:%.mo=%$(DSOSUF))),
             $(eval $(patsubst %-m,%-y,$v) += $(call expand-objs, $($v)))))

    # Post-process all the unnested vars
    $(foreach v,$2,
        $(foreach o, $(filter %.mo,$($v)),
            # Find all the .mo objects in variables and add dependency rules
            # according to .mo-objs. Report error if not set
            $(if $($o-objs),
                $(eval $(o:%.mo=%$(DSOSUF)): module-common.o $($o-objs)),
                $(error $o added in $v but $o-objs is not set)))
        $(call f1-echo,390, unnest-var --> shell mkdir -p ./ $(sort $(dir $($v))))
        # Include all the .d files
        $(call f1-echo,392, unnest-var --> eval -include $(patsubst %.o,%.d,$(patsubst %.mo,%.d,$($v))))
        $(eval $v := $(filter-out %/,$($v))))
	$(call f1-echo,394,--end unnest-vars--)	
endef

TEXI2MAN = $(call quiet-command,398, \
	perl -Ww -- $(SRC_PATH)/scripts/texi2pod.pl $(TEXI2PODFLAGS) $< $@.pod && \
	$(POD2MAN) --section=$(subst .,,$(suffix $@)) --center=" " --release=" " $@.pod > $@, \
	"GEN","$@")

%.1:
	$(call TEXI2MAN)
%.7:
	$(call TEXI2MAN)
%.8:
	$(call TEXI2MAN)

-include force.mak


