# klmutils
The Python script provides functions to query GKLM and SKLM servers via REST API. 
Depending on the type of the deployed architecture (Standalone, Multi-Master or Master-Clone)
different kind of API endpoints are queried and the responses are evaluated. 

Based on experience in production a subset (more to come) of status are assessed with severity and return code values so 
that at the end of the script execution it can be easily evaluated by checking the return code value e.g. if 

* login to the Websphere Application Server / key server application vie REST API login FAILED | SUCCESSFULL
* DB2 connection between the key server and the DB2 instance is successfull (might indicate a password expiration, account locked condition,...)
* Replication Manager is DOWN
* replication failed
* backup is needed because cryptografic objects have been added but not backed up
* certificates or keys are expired

example: 
> py klmtool.py --cfg=IBM-SLE-GKLM-clusters.conf --instance=server1 --healthDetails

![image](https://user-images.githubusercontent.com/30479943/101474094-f2df0f80-394a-11eb-9002-639891e54640.png)

## Reporting Issues and Feedback

Please use the [issue tracker](https://github.com/IBM/klmutils/issues) to ask questions, report bugs and request features.


## Contributing Code

We welcome contributions to this project, see [Contributing](CONTRIBUTING.md) for more details.


## Copyright and License

Copyright IBM Corporation 2020, released under the terms of the [Apache License 2.0](LICENSE).
