require "mkmf"

# the string is the init function's suffix in the .c source file. e.g, void Init_go()
# it's also the name of the extension. e.g, go.so

$libs = append_library($libs, "wiringPi")

create_makefile("hd44780")
