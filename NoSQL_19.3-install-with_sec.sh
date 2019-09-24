########## ONB SETUP ################################################
#####################################################################

# Installation code for a 3x3 cluster with security (password file)

# Run the following statements on all Nodes

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

# Run on Node 1
java -Xmx64m -Xms64m -jar $KVHOME/lib/kvstore.jar makebootconfig -root $KVROOT \
    -port 5000 -host storage-node-1 -harange 5010,5030 -servicerange 5035,5099 -capacity 3 \
    -admindir $KVADMIN -admindirsize 3_GB -store-security configure -pwdmgr pwdfile \
    -storagedir /disk1/ondb/data -storagedirsize 12_GB \
    -storagedir /disk2/ondb/data -storagedirsize 12_GB \
    -storagedir /disk3/ondb/data -storagedirsize 12_GB \
    -rnlogdir /disk1/ondb/log \
    -rnlogdir /disk2/ondb/log \
    -rnlogdir /disk3/ondb/log
    

# Copy the folder /KVROOT/security/ and its files to the remaining nodes

# Run on Node 2
java -Xmx64m -Xms64m -jar $KVHOME/lib/kvstore.jar makebootconfig -root $KVROOT \
    -port 5000 -host storage-node-2 -harange 5010,5030 -servicerange 5035,5099 -capacity 3 \
    -admindir $KVADMIN -admindirsize 3_GB -store-security enable -pwdmgr pwdfile \
    -storagedir /disk1/ondb/data -storagedirsize 12_GB \
    -storagedir /disk2/ondb/data -storagedirsize 12_GB \
    -storagedir /disk3/ondb/data -storagedirsize 12_GB \
    -rnlogdir /disk1/ondb/log \
    -rnlogdir /disk2/ondb/log \
    -rnlogdir /disk3/ondb/log

# Run on Node 3
java -Xmx64m -Xms64m -jar $KVHOME/lib/kvstore.jar makebootconfig -root $KVROOT \
    -port 5000 -host storage-node-3 -harange 5010,5030 -servicerange 5035,5099 -capacity 3 \
    -admindir $KVADMIN -admindirsize 3_GB -store-security enable -pwdmgr pwdfile \
    -storagedir /disk1/ondb/data -storagedirsize 12_GB \
    -storagedir /disk2/ondb/data -storagedirsize 12_GB \
    -storagedir /disk3/ondb/data -storagedirsize 12_GB \
    -rnlogdir /disk1/ondb/log \
    -rnlogdir /disk2/ondb/log \
    -rnlogdir /disk3/ondb/log
	
# Run on all Nodes	
nohup java -Xmx256m -Xms256m -jar $KVHOME/lib/kvstore.jar start -root $KVROOT &    

java -Xmx64m -Xms64m -jar $KVHOME/lib/kvstore.jar ping -host storage-node-1 -port 5000
java -Xmx64m -Xms64m -jar $KVHOME/lib/kvstore.jar ping -host storage-node-2 -port 5000
java -Xmx64m -Xms64m -jar $KVHOME/lib/kvstore.jar ping -host storage-node-3 -port 5000


# From one node the following statements:
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

## Create the pool
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

Admin access: java -Xmx256m -Xms256m -jar $KVHOME/lib/kvstore.jar runadmin -port 5000 -host storage-node-1 -security $KVROOT/security/adminlogin.txt -store kvstore

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

 
# Shutdown all nodes
java -Xmx64m -Xms64m -jar $KVHOME/lib/kvstore.jar stop -root $KVROOT


# Start all nodes
nohup java -Xmx256m -Xms256m -jar $KVHOME/lib/kvstore.jar start -root $KVROOT &

# connect with client
java -jar %KVHOME%\lib\sql.jar -helper-hosts 129.213.115.31:5000 -store kvstore -security D:\login\userlogin.txt

# connect with admin
java -jar $KVHOME/lib/kvstore.jar ping -host storage-node-1 -port 5000 -security $KVROOT/security/adminlogin.txt








### Troubleshooting:

# Check if iptables allows NoSQL DB communicates with the ports
# NTP should be configured
# Check if /etc/hosts is correct and have one entry for each host in the cluster



