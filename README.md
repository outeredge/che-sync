# che-sync
A sync tool to work on remote Eclipse Che workspaces


## Running

Run the command below, replacing:

 `<path>` with the local directory to sync (i.e. /home/user/myproject)  
 `<namespace/workspace>` with your namespace/workspace name (i.e. mycompany/myworkspace)  
 `<project>` with your remote project name  
 `<args>` as below  

```sh
$ docker run -it --pull --rm -v <path>:/mount:cached outeredge/che-sync <args> <namespace/workspace> <project>
```
### Args
```
Required

 -h     your che hostname (i.e. che.mycompany.com)
 -u     your che username (i.e. user)
 -p     your che password (i.e. pass)
 
Optional
 
 -s     ssh username for remote workspace
 ```
