CC ?= gcc
SKYNET ?= ../skynet-src
OUT_PATH ?= ../clib

SHARED := -fPIC --shared -lpthread
CFLAGS = -g -Wall -I$(SKYNET)/3rd/lua -I$(SKYNET)/skynet-src -I$(SKYNET)/service-src/ -I$(SKYNET)/lualib-src/ -I$(SKYNET)/3rd/lua-md5/ -D CACHE_BUFF_SIZE=4096

# LIBS = misc shareidmap clogger binstream router redirect comlib protobuf timermgr snapshot pathfind amqp ballmanage aoimanage usertime
LIBS = misc protobuf 
                             

define BUILD_LIB
$(1) : $$(OUT_PATH)/$(1).so
$$(OUT_PATH)/$(1).so : $(1)/*
	rm *.o -f
	if [ "`echo $(1)/*.c`" != "$(1)/*.c" ]; then $$(CC) $$(CFLAGS) $$(SHARED) $(1)/*.c -c -std=gnu99; $$(CC) $$(SHARED) *.o -o $$@; fi
	if [ "`echo $(1)/*.cpp`" != "$(1)/*.cpp" ]; then $$(CC) $$(CFLAGS) $$(SHARED) $(1)/*.cpp -c -std=c++11; $$(CC) $$(SHARED) *.o -o $$@ -lstdc++; fi
	rm *.o -f
endef

all : $(foreach v, $(LIBS), $(v))

$(foreach v, $(LIBS), $(eval $(call BUILD_LIB,$(v))))

clean :
	rm -f $(foreach v, $(LIBS), $(OUT_PATH)/$(v).so)
