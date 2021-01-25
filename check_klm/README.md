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
         
