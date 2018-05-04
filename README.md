# che-sync [![Docker Build Status](https://img.shields.io/docker/build/outeredge/che-sync.svg?style=flat-square)](https://hub.docker.com/r/outeredge/che-sync)
A tool by [outer/edge](https://github.com/outeredge) to work on remote Eclipse Che workspaces

## Running

Run the command below _from the folder_ you wish to sync your project into. If all goes well, you should land in the remote workspaces bash prompt and your project files should be syncing in the background.

```sh
$ docker run -it --rm -v $PWD:/mount:cached outeredge/che-sync <options> <workspace> <project>
```

| Argument      | Description                                                  |
| ------------- | ------------------------------------------------------------ |
| `<workspace>` | your workspace name including namespace (i.e. mycompany/myworkspace) |
| `<project>`   | your remote project name |
| `<options>`   | **-h**  your che hostname (i.e. che.mycompany.com)<br/>**-u**  your che username<br/>**-p**  your che password<br/>**-t**  Two-factor TOTP (2fa) code *(optional)*<br/>**-r**  Sync repeat delay in seconds, defaults to `watch` *(optional)*<br/>**-s** ssh username for remote workspace *(optional)*|

### Passing arguments as environment variables

As well as CLI aguments, you can also pass some (or all) of the arguments as environment variables to docker (i.e. with `-e` or with a `docker-compose.yml`).

| Variable | Default     |
| -------- | ----------- |
| CHE_HOST | -      |
| CHE_USER | -      |
| CHE_PASS | -      |
| CHE_TOTP | -      |
| CHE_WORKSPACE | - |
| CHE_PROJECT | -   |
| SSH_USER | user        |
| UNISON_PROFILE | default |
| UNISON_REPEAT | watch  |

### Additional unison profiles

You can store one (`default.prf`) or multiple unison profile files in a `.unison` directory within your projects. Specify `-e UNISON_PROFILE=yourprofilename` to use a non-default profile.

## Upgrading

```sh
$ docker pull outeredge/che-sync
```

## Troubleshooting

You can watch the Unison sync logs by running the below command in a new terminal after starting che-sync.

```sh
$ docker exec $(docker ps -lq) tail -f unison.log
```
