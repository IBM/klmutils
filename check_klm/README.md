**sample call:**

```
./check_klm.sh -h


 IBM Security Guardium Key Lifecycle Manager NRPE plugin, version 0.53 (MIT licence)

 usage:         ./check_klm.sh [ -a | -b | -f | -l | -p | -r | -h ]

 syntax:
         -a     --> Run ALL checks, identical to no parameter
         -b     --> Verify if BACKUP is needed
         -f     --> Verify FILESYSTEM usage
         -l     --> Verify TCP port LISTERNER states
         -p     --> Verify that required PROCESSES (WAS, DB2) are running
         -r     --> check REST API for health status (only KLM 4.0
         -h     --> Print This Help Screen
```


**./check_klm.sh -a**

```
utility name:                 ./check_klm.sh
utility version:              0.57
checking agains KLM version:  40
using config file:            klm_v40.def

ERROR    check_api_status     API endpoint /SKLM/rest/v1/health reported BAD state: "overall": false
WARNING  check_filesystems    filesystem /opt/IBM/WebSphere has less than 4 GB free space: 4108636 KB
OK       check_filesystems    filesystem /tmp has more than 4 GB free space: 14 GB
OK       check_filesystems    filesystem /home/sklmdb40 has more than 4 GB free space: 11 GB
OK       check_ports          Websphere HTTPS port 9083 OK
OK       check_ports          GKLM SSL port 1441 OK
OK       check_ports          GKLM IPP port 3801 OK
OK       check_ports          GKLM KMIP port 5696 OK
OK       check_ports          GKLM HTTPS GUI port 9443 OK
OK       check_ports          DB2 default port 50060 OK
OK       check_ports          Replication port 1111 (role master) OK
OK       check_processes      WebSphere Application server PID: 13197
ERROR    check_processes      DB2 database watchdog PID: no process detected
WARNING  check_isBackupNeeded CTGKM1305I Cryptographic objects were added or modified since the last backup, or no previous backups exist. Create a backup.
ERROR    main                 highest returncode
```

```
echo $?
2
```


