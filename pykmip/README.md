

PyKmip docs: https://pykmip.readthedocs.io/en/latest/client.html


**Installation:**

```
yum install python3
yum install python3-pip
python -m pip install --user --upgrade pip
py -m pip install --user virtualenv

pip3 install pykmip
```


If using a proxy, the following will work: 

> pip3 install --proxy=https://IP:3128 pykmip


**Create a client public/private key pair (self-signed)**

> openssl req -x509 -sha256 -nodes -days 1000 -newkey rsa:2048 -keyout kmipClient1.key -out kmipClient1.crt -addext "subjectAltName = DNS:kmipClient1"

```
Generating a RSA private key
.....................+++++
..............................................................................................................+++++
writing new private key to 'kmipclient1.key'
-----
You are about to be asked to enter information that will be incorporated into your certificate request.
What you are about to enter is what is called a Distinguished Name or a DN.
There are quite a few fields but you can leave some blank. For some fields there will be a default value,
If you enter '.', the field will be left blank.
-----
Country Name (2 letter code) [XX]:DE
State or Province Name (full name) []:HE
Locality Name (eg, city) [Default City]:Frankfurt
Organization Name (eg, company) [Default Company Ltd]:IBM
Organizational Unit Name (eg, section) []:ESCC
Common Name (eg, your name or your server's hostname) []:kmipClient1
Email Address []:
```

**Create a pykmip.conf file (optional)**

The pykmip config file is optional. All connection settings can be set in the Python script when creating the ProxyKmipClient object

Location @Linux: /etc/pykmip/pykmip.conf
Location @Windows: kmipconfig.ini

*Sample file:*
```
[client]
host=KLM_SERVER_IP
port=5696
certfile=/etc/pykmip/certs/kmipclient1.crt
keyfile=/etc/pykmip/certs/kmipclient1.key
ca_certs=/etc/pykmip/certs/gklm_server_kmip_cert.pem
kmip_version=enums.KMIPVersion.KMIP_1_2
cert_reqs=CERT_REQUIRED
ssl_version=PROTOCOL_SSLv23
do_handshake_on_connect=True
suppress_ragged_eofs=True
```


**Sample script result**
> python3 testClient.py

``` 
================================================================================
testing against KLM server: KLM_SERVER_IP
================================================================================


================================================================================
creating key with name: kmipTestClient___MGD2H3L3QNHK5Q6
================================================================================

UUID of created key: KEY-222c050-0372a9bd-9100-4771-af8f-69c9a5b31496

================================================================================
retrieving key by uuid: KEY-222c050-0372a9bd-9100-4771-af8f-69c9a5b31496
================================================================================

b'a800e399f4424b0eda8b321322b8ea8697446148296f1a793b008980534ab03f'


================================================================================
List of all sym keys that belong to the same client group
================================================================================


Name                                Last Change Date                Unique Identifier
--------------------------------------------------------------------------------------------------------------------
kmipTestClient___MGD2H3L3QNHK5Q6    Wed Feb  2 16:07:02 2022        KEY-222c050-0372a9bd-9100-4771-af8f-69c9a5b31496 
kmipTestClient___6J1GZN2CLAVNIB7    Wed Feb  2 16:06:22 2022        KEY-222c050-0a5d5258-3491-4e87-b030-4b49b08e2067 
kmipTestClient___G1CMV7Z1ID0RSH6    Wed Feb  2 16:06:02 2022        KEY-222c050-ee4b8db6-1db5-4773-9757-e7c310fb2c34 
kmipTestClient___CUR5BTZ698K3TW8    Wed Feb  2 16:05:32 2022        KEY-222c050-d2df9677-d89f-442e-b988-61b2b343ec7a 
Test_256_AES_Symmetric_Key2         Thu Jan  6 19:18:20 2022        KEY-f5494d6-bcb1aa3f-89b8-44b1-bb59-28bea77c7a06 
```


**Available Atributes for symmetric key objects**
```
['Cryptographic Algorithm', 
'Cryptographic Length', 
'Cryptographic Usage Mask', 
'Digest', 
'Fresh', 
'Initial Date', 'Last Change Date', 'Lease Time', 
'Name', 
'Object Type', 'Operation Policy Name', 
'Original Creation Date', 'State', 
'Unique Identifier']
```
