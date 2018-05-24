# che-sync [![Docker Build Status](https://img.shields.io/docker/build/outeredge/che-sync.svg?style=flat-square)](https://hub.docker.com/r/outeredge/che-sync)

A tool by [outer/edge](https://github.com/outeredge) to work on remote Eclipse Che workspaces in your local IDE. Support for remote port forwarding (to enable, for example, XDebug) on Linux, MacOS & Windows built-in.

## Running

To run che-sync, you will need docker [installed](https://docs.docker.com/install/) on your local machine.

Run the command below _from the folder_ you wish to sync your project into. If all goes well, you should land in the remote workspaces bash prompt and your project files should be syncing in the background.

```sh
$ docker run -it --rm -v $PWD:/mount:cached outeredge/che-sync <options> <workspace> <project>
```

| Argument      | Description                                                  |
| ------------- | ------------------------------------------------------------ |
| `<options>`   | **-h**  your che hostname (i.e. che.mycompany.com)<br/>**-u**  your che username<br/>**-p**  your che password<br/>**-t**  Two-factor TOTP (2fa) code *(optional)*<br/>**-r**  Sync repeat delay in seconds, defaults to `watch` *(optional)*<br/>**-s** ssh username for remote workspace *(optional)*|
| `<workspace>` | your workspace name including namespace (i.e. mycompany/myworkspace) |
| `<project>`   | your remote project name *(optional)* |

### Passing arguments as environment variables

As well as CLI aguments, you can also pass some (or all) of the arguments as environment variables to docker (i.e. with `-e` or with a `docker-compose.yml`).

| Variable | Default     | Description |
| -------- | ----------- | ----------- |
| CHE_HOST | -      | Your Che hostname (i.e. che.mycompany.com) |
| CHE_USER | -      | Your Che password |
| CHE_PASS | -      | Your Che username |
| CHE_TOTP | -      | Two-factor TOTP (2fa) code *(optional)* |
| CHE_NAMESPACE | - | Your Che organisation name |
| CHE_WORKSPACE | - | Your Che workspace name |
| CHE_PROJECT | -   | Your Che project name *(optional)* |
| SSH_USER | user   | SSH username for remote workspace *(optional)* |
| UNISON_NAME | che-local | Set this to an alternative value if you use che-sync on multiple machines |
| UNISON_PROFILE | default | Specify which remote unison profile to use |
| UNISON_REPEAT | watch | Sync repeat delay in seconds |
| FORWARD_PORT | 9000 | Specify a remote port to forward to your local machine |

### Using Docker Compose

With [Docker Compose](https://docs.docker.com/compose/install), you can create a single `docker-compose.yml` on your local machine for each project/workspace like so:

```yml
version: '3'
services:
  sync:
    image: outeredge/che-sync
    volumes:
      - .:/mount:cached
    environment:
      - CHE_HOST=che.mycompany.com
      - CHE_NAMESPACE=mycompany
      - CHE_WORKSPACE=test
      - CHE_PROJECT=test
      - CHE_USER=user
      - CHE_PASS=password
```

You can then launch the sync and enter the workspace simply with:

`$ docker-compose run --rm sync`

If you only want to access the workspace via SSH without file sync, you can type:

`$ docker-compose run --rm sync ssh`


### Additional unison profiles

You can store one (`default.prf`) or multiple unison profile files in a `.chesync` directory within your projects. Specify `-e UNISON_PROFILE=yourprofilename` to use a non-default profile.

## Upgrading

```sh
$ docker pull outeredge/che-sync
```

## Troubleshooting

You can watch the Unison sync logs by running the below command in a new terminal after starting che-sync.

```sh
$ docker exec $(docker ps -lq) tail -f unison.log
```

If you are seeing errors about exceeding filesystem watchers, try;

```sh
$ echo fs.inotify.max_user_watches=1048576 | sudo tee -a /etc/sysctl.conf && sudo sysctl -p
```