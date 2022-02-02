import ssl
import random
import string

from kmip.pie.client import ProxyKmipClient, enums
from kmip import enums
from kmip.pie import objects
from kmip.core.factories import attributes

h1 = "\n"*3 + "="*80
h2 = "=" * 80 + "\n"*2

primary = "primary_KLMServerIP_or_Hostname"
standby = "standby_KLMServerIP_or_Hostname"


klmServer           = primary
klmServerKmipCert   = "certs/gklm_server_kmip_cert.pem"     # this is the KLM KMIP/SSL certificate
clientCert          = "certs/kmipclient1.crt"               # this is the public key of the KMIP client that needs to be imported and trusted in the keyserver
clientKey           = "certs/kmipclient1.key"               # this private key is only used by the KMIP client script


def createNewKey(keyName = None):
    if keyName == None:    
        randomStringLenght = 15
        randomString = "kmipTestClient___" + ''.join(random.choices(string.ascii_uppercase + string.digits, k = randomStringLenght))
        keyName=randomString
    
    print(h1)
    print("ccreating key with name: " + keyName)
    print(h2)

    try:
            with c:
                    key_id = c.create(
                            enums.CryptographicAlgorithm.AES,256,
                            operation_policy_name='default',
                            name=keyName,
                            cryptographic_usage_mask=[
                                    enums.CryptographicUsageMask.ENCRYPT,
                                    enums.CryptographicUsageMask.DECRYPT
                            ]
                    )
                    print("UUID of created key: " + key_id)
                    return key_id

    except Exception as e:
            print(e)
    


def retrieveKey(uuid = None):
    print()
    print(h1)
    print("retrieving key by uuid: " + keyUuid)
    print(h2)

    try:
            with c:
                    key = c.get(keyUuid)
                    print(key)
    except Exception as e:
            print(e)



print(h1)
print("testing against KLM server: " + klmServer)
print(h2)

c = ProxyKmipClient(
        hostname=klmServer,
        port=5696,
        cert=clientCert,
        key=clientKey,
        ca=klmServerKmipCert,
        ssl_version='PROTOCOL_SSLv23',
        kmip_version=enums.KMIPVersion.KMIP_1_2
)



keyFailure  = "KEY-f5494d6-43f998c7-bb6d-4e4e-82be-c509eb1eb0b8"    # UUID that does not exist in keystore or belongs to a different client
keyIdOK     = "KEY-f5494d6-527b9c21-6106-40fc-9eef-6b5978930f49"
keyUuid     = keyIdOK

keyUuid = createNewKey()
retrieveKey(uuid=keyUuid)


print(h1)
print("List of all sym keys that belong to the same client group")
print(h2)

f = attributes.AttributeFactory()
attributeList = ['Name', 'Last Change Date', 'Unique Identifier']

try:
        print("".join("{:35} ".format(attrName) for attrName in attributeList))
        print("-"*140)

        with c:
                keyUuidList = c.locate( attributes=[ f.create_attribute(enums.AttributeType.OBJECT_TYPE,enums.ObjectType.SYMMETRIC_KEY ) ] )
                for id in keyUuidList:
                        attrs = c.get_attributes(uid=id, attribute_names=attributeList)
                        obj = {}
                       
                        for elem in attrs[1]:
                            obj[str(elem.attribute_name)] = str(elem.attribute_value)
                            #print(elem.attribute_name, elem.attribute_value)
                        
                        print("".join("{:35} ".format(value) for key, value in obj.items()))

except Exception as e:
        print(e)
