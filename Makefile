# bin file
bin = DisableMonitor

# source files
src = DisableMonitor.c

# flags 
flags = -Wall -framework ApplicationServices


DisableMonitor:
	rm -rf $(bin)
	gcc -o $(bin) $(src) $(iniparser) $(flags)
	
clean:
	rm -rf $(bin)
