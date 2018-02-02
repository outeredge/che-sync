# che-sync
A sync tool to work on remote Eclipse Che workspaces


## Running

Run the command below, replacing `<path>` with the local directory to sync to and `<args>` as below:

```sh
$ docker run -it --rm -v <path>:/mount:cached outeredge/che-sync <args>
```
```
Required

 -u     your che username (i.e. user)
 -p     your che password (i.e. pass)
 -h     your che hostname (i.e. che.mycompany.com)
 
Optional
 
 -s     ssh username for remote workspace
 ```
