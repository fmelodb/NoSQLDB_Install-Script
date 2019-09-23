########## ONB SETUP ################################################
#####################################################################

# Installation code for a 3x3 cluster with security (password file)

### ENVIRONMENT VARIABLES

KVHOME=/home/opc/kv-19.3.12
KVROOT=/ondb/root
KVADMIN=/ondb/admin
MALLOC_ARENA_MAX=1

export PATH KVHOME KVROOT MALLOC_ARENA_MAX

mkdir /ondb/root
mkdir /ondb/admin

mkdir /disk1/ondb
mkdir /disk2/ondb
mkdir /disk3/ondb

mkdir /disk1/ondb/data
mkdir /disk1/ondb/log
mkdir /disk2/ondb/data
mkdir /disk2/ondb/log
mkdir /disk3/ondb/data
mkdir /disk3/ondb/log


java -Xmx64m -Xms64m -jar $KVHOME/lib/kvstore.jar makebootconfig -root $KVROOT \
    -port 5000 -host storage-node-1 -harange 5010,5030 -servicerange 5035,5099 -capacity 3 \
    -admindir $KVADMIN -admindirsize 3_GB -store-security configure -pwdmgr pwdfile \
    -storagedir /disk1/ondb/data -storagedirsize 12_GB \
    -storagedir /disk2/ondb/data -storagedirsize 12_GB \
    -storagedir /disk3/ondb/data -storagedirsize 12_GB \
    -rnlogdir /disk1/ondb/log \
    -rnlogdir /disk2/ondb/log \
    -rnlogdir /disk3/ondb/log
	
java -Xmx64m -Xms64m -jar $KVHOME/lib/kvstore.jar makebootconfig -root $KVROOT \
    -port 5000 -host storage-node-2 -harange 5010,5030 -servicerange 5035,5099 -capacity 3 \
    -admindir $KVADMIN -admindirsize 3_GB -store-security enable -pwdmgr pwdfile \
    -storagedir /disk1/ondb/data -storagedirsize 12_GB \
    -storagedir /disk2/ondb/data -storagedirsize 12_GB \
    -storagedir /disk3/ondb/data -storagedirsize 12_GB \
    -rnlogdir /disk1/ondb/log \
    -rnlogdir /disk2/ondb/log \
    -rnlogdir /disk3/ondb/log
	
java -Xmx64m -Xms64m -jar $KVHOME/lib/kvstore.jar makebootconfig -root $KVROOT \
    -port 5000 -host storage-node-3 -harange 5010,5030 -servicerange 5035,5099 -capacity 3 \
    -admindir $KVADMIN -admindirsize 3_GB -store-security enable -pwdmgr pwdfile \
    -storagedir /disk1/ondb/data -storagedirsize 12_GB \
    -storagedir /disk2/ondb/data -storagedirsize 12_GB \
    -storagedir /disk3/ondb/data -storagedirsize 12_GB \
    -rnlogdir /disk1/ondb/log \
    -rnlogdir /disk2/ondb/log \
    -rnlogdir /disk3/ondb/log
	
	
nohup java -Xmx256m -Xms256m -jar $KVHOME/lib/kvstore.jar start -root $KVROOT &    

java -Xmx64m -Xms64m -jar $KVHOME/lib/kvstore.jar ping -host storage-node-1 -port 5000
java -Xmx64m -Xms64m -jar $KVHOME/lib/kvstore.jar ping -host storage-node-2 -port 5000
java -Xmx64m -Xms64m -jar $KVHOME/lib/kvstore.jar ping -host storage-node-3 -port 5000


# From one node

java -Xmx256m -Xms256m -jar $KVHOME/lib/kvstore.jar runadmin -port 5000 -host storage-node-1 -security $KVROOT/security/client.security


## Create the store and primary zone

configure -name kvstore
change-policy -params passwordComplexityCheck=false
plan create-user -name root -admin -wait
plan deploy-zone -name "zone1" -rf 3 -wait
show topology


## Create the storage nodes

plan deploy-sn -zn zn1 -host storage-node-1 -port 5000 -wait
plan deploy-admin -sn sn1 -wait

plan deploy-sn -zn zn1 -host storage-node-2 -port 5000 -wait
plan deploy-admin -sn sn2 -wait

plan deploy-sn -zn zn1 -host storage-node-3 -port 5000 -wait
plan deploy-admin -sn sn3 -wait

## CRIA O POOL

pool create -name myPool
pool join -name myPool -sn sn1
pool join -name myPool -sn sn2
pool join -name myPool -sn sn3

## Create the topology

topology create -name 3x3 -pool myPool -partitions 120
plan deploy-topology -name 3x3 -wait
show topology

java -Xmx256m -Xms256m -jar $KVHOME/lib/kvstore.jar securityconfig pwdfile create -file $KVROOT/security/login.passwd
java -Xmx256m -Xms256m -jar $KVHOME/lib/kvstore.jar securityconfig pwdfile secret -file $KVROOT/security/login.passwd -set -alias root

echo "oracle.kv.auth.username=root" >> $KVROOT/security/adminlogin.txt
echo "oracle.kv.auth.pwdfile.file=/ondb/root/security/adminlogin.passwd" >> $KVROOT/security/adminlogin.txt 


Acesso admin: java -Xmx256m -Xms256m -jar $KVHOME/lib/kvstore.jar runadmin -port 5000 -host storage-node-1 -security $KVROOT/security/adminlogin.txt -store kvstore
Acesso client: java -jar $KVHOME/lib/sql.jar -helper-hosts storage-node-1:5000 -store kvstore -security $KVROOT/security/userlogin.txt
 

# Generate access to clients:

java -jar $KVHOME/lib/kvstore.jar runadmin -port 5000 -host storage-node-1 -security $KVROOT/security/adminlogin.txt -store kvstore
execute 'CREATE USER Fernando IDENTIFIED BY "oracle123"';
execute 'GRANT DBADMIN TO USER Fernando';
execute 'GRANT READWRITE TO USER Fernando';

java -jar $KVHOME/lib/kvstore.jar securityconfig pwdfile create -file $KVROOT/security/userlogin.passwd
java -jar $KVHOME/lib/kvstore.jar securityconfig pwdfile secret -file $KVROOT/security/userlogin.passwd -set -alias Fernando
cp $KVROOT/security/client.security $KVROOT/security/userlogin.txt
echo "oracle.kv.auth.username=Fernando" >> $KVROOT/security/userlogin.txt
echo "oracle.kv.auth.pwdfile.file=/home/opc/kvroot/security/userlogin.passwd" >> $KVROOT/security/userlogin.txt

java -jar $KVHOME/lib/sql.jar -helper-hosts storage-node-1:5000 -store kvstore -security $KVROOT/security/userlogin.txt
 
 
# Take the following files to the client side:
$KVROOT/security/userlogin.txt
$KVROOT/security/userlogin.passwd
$KVROOT/security/client.trust

 
# Shutdown
java -Xmx64m -Xms64m -jar $KVHOME/lib/kvstore.jar stop -root $KVROOT


# Start
nohup java -Xmx256m -Xms256m -jar $KVHOME/lib/kvstore.jar start -root $KVROOT &

# connect with client
java -jar %KVHOME%\lib\sql.jar -helper-hosts 129.213.115.31:5000 -store kvstore -security D:\login\userlogin.txt

# connect with admin
java -jar $KVHOME/lib/kvstore.jar ping -host storage-node-1 -port 5000 -security $KVROOT/security/adminlogin.txt













# Troubleshooting:

- Aparece rota invalid route to host: sudo service iptables stop
- Warnings ao criar topologia informando que storagesize não foi especificado:  plan change-storagedir -sn sn1 -storagedir /disk2/ondb/data -storagedirsize "96 gb" -add -wait
- verificar NTP (systemctl stop/start ntpd, timedatectl)



