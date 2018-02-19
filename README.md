# che-sync [![Docker Build Status](https://img.shields.io/docker/build/outeredge/che-sync.svg?style=flat-square)](https://hub.docker.com/r/outeredge/che-sync)
A sync tool to work on remote Eclipse Che workspaces

## Running

```sh
$ docker run -it --rm -v <path>:/mount:cached outeredge/che-sync <args> <workspace> <project>
```

| Argument      | Description                                                  |
| ------------- | ------------------------------------------------------------ |
| `<path>`      | the local directory to sync (i.e. /home/user/myproject) |
| `<workspace>` | your namespace/workspace name (i.e. mycompany/myworkspace) |
| `<project>`   | your remote project name |
| `<args>`      | **-h**  your che hostname (i.e. che.mycompany.com)<br/>**-u**  your che username<br/>**-p**  your che password<br/>**-t**  Two-factor TOTP (2fa) code<br/>**-r**  Sync repeat delay in seconds, default 5 *(optional)*<br/>**-s** ssh username for remote workspace *(optional)*|
