Hello.

This script define two new data types in Oracle's pl/sql  for ip address and ip network, and provide the following functions to perform calculations over the ip v4 address and network:

ip2bin: Translate an ip type to it 32 bits binary representation as a string, without decimal point separators
bin2ip:  Translate a 32 bits binary a string, without decimal point separators, to it IP type
str2ip:  Translate a ip address string of the form A.B.C.D to an ip type, else return null
ip2str:  Translate an ip type to it string form of A.B.C.D else return null
nmask_i2ip: Translate an integer network mask (1..32) to it ip type;
nmask_ip2: Translate and ip network mask to it integer form (1..32) 
net: Utility function to get general information about a network based on the parameter p_out:
       NM:Netmask, WC: Wildcard, NW:Network, BC: Broadcast FH:Firsthost LH:Lasthost
noverlap: Return Y if the two networks passed as parameter overlaps (has at least one common ip address), else return N
maxip: Returns the lowest of the IPs sent as a parameter
minip: Returns the largest of the IPs sent as a parameter
supernet: Based on the two networks passed as parameter, return the smallest network that contain both
