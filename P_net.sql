------------------------------------------------------------------------------------------
-- PACKAGE in PL/SQL that define a set of common functions to perform network operations 
-- over IP V4 ip addresses and networks
--
-- Version 1.0
-- Created by: William Della Noce
-- Contact: william dot dellanoce at gmail dot com
------------------------------------------------------------------------------------------

create or replace TYPE IPADDR 
AS VARRAY(4) OF integer;
--Create the IP Address (IPADDR) datatype formed by four numeric elements

create or replace TYPE IPNET AS OBJECT 
( ip        ipaddr,
  nmask     number
);
--Create the IP Network datatype formed by an IP address datatype and a network mask defined by an integer number

create or replace PACKAGE IP_NET AS 

function ip2bin(p_ip ipaddr) return varchar2;
-- Translate an ip type to it 32 bits binary representation as a string, without decimal point separators

function bin2ip(p_str varchar2) return ipaddr;
-- Translate a 32 bits binary a string, without decimal point separators, to it IP type

function str2ip(p_str varchar2) return ipaddr;
-- Translate a ip address string of the form A.B.C.D to an ip type, else return null

function ip2str(p_ip ipaddr) return varchar2;
-- Translate an ip type to it string form of A.B.C.D else retur null

function nmask_i2ip(p_mask number) return ipaddr;
-- Translate an integer network mask (1..32) to it ip type;

function nmask_ip2i(p_mask ipaddr) return number;
-- Trasnlate and ip network mask to it integer form (1..32) 

function net(p_ip ipaddr, p_mask number,p_out varchar2) return ipaddr;
function net(p_ip ipnet,p_out varchar2) return ipaddr;
-- Utility function to get general information about a network based on the parameter p_out:
-- NM:Netmask, WC: Wildcard, NW:Network, BC: Broadcast FH:Firsthost LH:Lasthost

function noverlap(p1_ip ipaddr,p1_mask number,p2_ip ipaddr,p2_mask number) return varchar2;
function noverlap(p_ip1 ipnet,p_ip2 ipnet) return varchar2;
-- Return Y if the two networks passed as parameter overlaps (has at least one common ip address), else return N

function maxip(p1_ip ipaddr,p2_ip ipaddr) return ipaddr;
-- Returns the lowest of the IPs sent as a parameter

function minip(p1_ip ipaddr,p2_ip ipaddr) return ipaddr;
-- Returns the largest of the IPs sent as a parameter

function supernet(p_ip1 ipaddr,p_mask1 number,p_ip2 ipaddr,p_mask2 number) return IPNET;
function supernet(p_n1 IPNET,p_n2 IPNET) return IPNET;
-- Based on the two networks passed as parameter, return the smallest network that contain both

END IP_NET;

create or replace PACKAGE BODY IP_NET AS

FUNCTION bin2dec ( binval IN VARCHAR2 ) RETURN INTEGER IS
digits             INTEGER;
result             INTEGER := 0;
current_digit      VARCHAR2(1);
current_digit_dec  INTEGER;

BEGIN digits := length(binval);
    FOR i IN 1..digits LOOP current_digit := substr(binval, i, 1);
        current_digit_dec := to_number(current_digit);
        result := ( result * 2 ) + current_digit_dec;
    END LOOP;

    RETURN result;
END bin2dec;

FUNCTION dec2bin ( n IN INTEGER ) RETURN VARCHAR2 IS 
binval      VARCHAR2(64);
n2          INTEGER := n;
BEGIN 
    IF n2 = 0 THEN 
        RETURN '00000000';
    END IF;
    WHILE ( n2 > 0 ) LOOP 
        binval := MOD(n2, 2)|| binval;
        n2 := trunc(n2 / 2);
    END LOOP;

    RETURN lpad(binval, 8, '0');
END dec2bin;

function ip2bin(p_ip ipaddr) return varchar2 as
v_str       varchar2(32);
begin
    for i in 1..4 loop
        v_str:=v_str||dec2bin(p_ip(i));
    end loop i;
    return v_str;
end ip2bin;

function bin2ip(p_str varchar2) return ipaddr as
v_out       ipaddr:=ipaddr(0,0,0,0);
begin
    for j in 1..4 loop
        v_out(j):=bin2dec(substr(p_str,(j-1)*8+1,8));
    end loop j;
    return v_out;
end bin2ip;

function compare(p1_ip ipaddr,p2_ip ipaddr) return varchar2 as
v_i             number:=1;
begin
    loop
        if p1_ip(v_i)>p2_ip(v_i) then
            return 'G';
        elsif p1_ip(v_i)<p2_ip(v_i) then
            return 'L';        
        else
            v_i:=v_i+1;
        end if;
        exit when v_i=5;
    end loop;
    return 'E';
end compare;

function str2ip(p_str varchar2) return ipaddr AS
v_str           varchar2(15);
v_ip            ipaddr:=ipaddr(0,0,0,0);
v_pos           integer:=0;
-- 10.10.109.254
BEGIN
    v_str:=p_str||'.';
    if regexp_instr(p_str,'^(([0-9]{1}|[0-9][0-9]|1[0-9][0-9]|2[0-4][0-9]|25[0-5])\.){3}([0-9]{1}|[0-9][0-9]|1[0-9][0-9]|2[0-4][0-9]|25[0-5])$')>0 then
        for i in 1..4 loop
            v_ip(i):=to_number(substr(v_str,v_pos+1,instr(v_str,'.',v_pos+1)-v_pos-1));
            v_pos:=instr(v_str,'.',v_pos+1);
        end loop i;
        return v_ip;
    else
        RETURN NULL;
    end if;
  exception when others then
    return null;
END str2ip;

function ip2str(p_ip ipaddr) return varchar2 as
v_str           varchar2(16);
begin
    for i in 1..4 loop
        v_str:=v_str||p_ip(i)||'.';
    end loop i;
    v_str:=substr(v_str,1,length(v_str)-1);
    
    return v_str;
end ip2str;

function nmask_i2ip(p_mask number) return ipaddr as
v_out           ipaddr:=ipaddr(0,0,0,0);
v_str           varchar2(32 char);

begin
    if p_mask between 1 and 32 then
        v_str:=rpad('1',p_mask,'1')||rpad('0',32-p_mask,'0');
        
        for j in 1..4 loop
            v_out(j):=bin2dec(substr(v_str,(j-1)*8+1,8));
        end loop j;
    end if;
    
    return v_out;
end  nmask_i2ip;   

function nmask_ip2i(p_mask ipaddr) return number as
v_str           varchar2(32);
begin
    v_str:=ip_net.ip2bin(p_mask);
    
    if instr(v_str,'01')>0 then
        return null;
    else
        return instr(v_str||'0','10');
    end if;
end nmask_ip2i;

function net(p_ip ipaddr, p_mask number,p_out varchar2) return ipaddr as
v_out           ipaddr:=ipaddr(0,0,0,0);
v_str           varchar2(32);
begin
    if upper(p_out)='NM' then 
        v_out:=ip_net.nmask_i2ip(p_mask);
    elsif upper(p_out)='WC' then
        v_out:=ip_net.nmask_i2ip(p_mask);
        v_str:=ip_net.ip2bin(v_out);
        v_str:=replace (replace (replace (v_str,'0','.'),'1','0'),'.','1');
        v_out:=ip_net.bin2ip(v_str);
    elsif upper(p_out) in ('NW','FH') then
        v_str:=ip_net.ip2bin(p_ip);
        v_str:=substr(v_str,1,p_mask)||replace(substr(v_str,p_mask+1),'1','0');
        if upper(p_out)='FH' then
            v_str:=substr(v_str,1,31)||'1';
        end if;
        v_out:=ip_net.bin2ip(v_str);
    elsif upper(p_out) in ('BC','LH') then
        v_str:=ip_net.ip2bin(p_ip);
        v_str:=substr(v_str,1,p_mask)||replace(substr(v_str,p_mask+1),'0','1');
        if upper(p_out)='LH' then
            v_str:=substr(v_str,1,31)||'0';
        end if;
        v_out:=ip_net.bin2ip(v_str);
    end if;
    
    return v_out;
end net;

function net(p_ip ipnet,p_out varchar2) return ipaddr as
v_out           ipaddr:=ipaddr(0,0,0,0);
begin
    v_out:=ip_net.net(p_ip.ip,p_ip.nmask,p_out);
    return v_out;
end net;

function noverlap(p1_ip ipaddr,p1_mask number,p2_ip ipaddr,p2_mask number) return varchar2 as
v_ip1           ipaddr:=ipaddr(0,0,0,0);
v_ip2           ipaddr:=ipaddr(0,0,0,0);
v_least         number;
v_i             number:=1;
begin
    v_least:=least(p1_mask,p2_mask);
    v_ip1:=ip_net.net(p1_ip,v_least,'NW');
    v_ip2:=ip_net.net(p2_ip,v_least,'NW');
    loop
        if v_ip1(v_i)!=v_ip2(v_i) then
            return 'N';
        else
            v_i:=v_i+1;
        end if;
        exit when v_i=5;
    end loop;
    return 'Y';
end noverlap;

function noverlap(p_ip1 ipnet,p_ip2 ipnet) return varchar2 as
v_out   varchar2(1);
begin
    v_out:=ip_net.noverlap(p_ip1.ip,p_ip1.nmask,p_ip2.ip,p_ip2.nmask);
    return v_out;
end noverlap;

function maxip(p1_ip ipaddr,p2_ip ipaddr) return ipaddr as
begin
    if compare(p1_ip,p2_ip) in ('G','E') then
        return p1_ip;
    else
        return p2_ip;
    end if;
end maxip;    

function minip(p1_ip ipaddr,p2_ip ipaddr) return ipaddr as
begin
    if compare(p1_ip,p2_ip) in ('L','E') then
        return p1_ip;
    else
        return p2_ip;
    end if;
end minip; 

function supernet(p_ip1 ipaddr,p_mask1 number,p_ip2 ipaddr,p_mask2 number) return IPNET as
v_out       ipnet;
v_bin1      varchar2(32);
v_bin2      varchar2(32);
v_ip        ipaddr:=ipaddr(0,0,0,0);
i           number:=1;
begin
    v_bin1:=ip_net.ip2bin(ip_net.net(p_ip1,p_mask1,'NW'));
    v_bin2:=ip_net.ip2bin(ip_net.net(p_ip2,p_mask2,'NW'));
    
    loop
        if substr(v_bin1,i,1)!=substr(v_bin2,i,1) then
            i:=i-1;
            exit;
        else
            i:=i+1;
        end if;
        exit when i=33;
    end loop;
    
    if i between 1 and 32 then
        v_ip:=ip_net.bin2ip(substr(v_bin1,1,i)||rpad('0',32-i,'0'));
    else
        return ipnet(v_ip,1);
    end if;
   
    v_out:=ipnet(v_ip,i);
    return v_out;
end supernet;    

function supernet(p_n1 IPNET,p_n2 IPNET) return IPNET as
v_out       ipnet;
begin
    v_out:=ip_net.supernet(p_n1.ip,p_n1.nmask,p_n2.ip,p_n2.nmask);
    return v_out;
end supernet;    

END IP_NET;