
# BuildPiper Pre-Hook Docker Image

This Docker image runs the `build.sh` script to execute **pre-hook commands** in a controlled environment.
It is published to your private registry:

```
registry.buildpiper.in/impl/pre-hooks:nr_v0.1 #use for buildpiper
```

---

## Build & Push the Image

From the directory containing the `Dockerfile`:

```bash
# Build the image
docker build -t pre-hooks:nr_v0.1 .

```

---

## Run the Container

To execute `build.sh` with your local code mounted:

```bash
docker run --rm -it \
  -e DEBUG=true \
  -e WORKSPACE=/bp/workspace \
  -e CODEBASE_DIR=Example \
  -e PRE_HOOK_CMD=npm build \
  -v $(pwd):/bp/workspace \
  registry.buildpiper.in/impl/pre-hooks:nr_v0.1
```



---

## Environment Variables

| Variable                 | Description                                                      |
| ------------------------ | ---------------------------------------------------------------- |
| `DEBUG`                  | Enable debug logs (`true` / `false`).                            |
| `WORKSPACE`              | Workspace directory inside container (default: `/bp/workspace`). |
| `CODEBASE_DIR`           | Subdirectory inside workspace that contains the code.            |
| `ACTION`                | Action being performed (`build`, `deploy`).              |
| `SLEEP_DURATION`         | Sleep duration before execution (default: `5s`).                 |
| `PRE_HOOK_CMD`         | Set the value if run locally .                 |

---

> ⚠️ **Note:**
> If running locally, you need to set `PRE_HOOK_CMD` manually . When running from BuildPiper (BP), this value is set in select variable and the command automatically reads it from the environment.
> Additionally, when running from BuildPiper (BP) a pre-hook for a build, the `ACTION` value should be set to `build`, and for a deploy, it should be set to `deploy`.

## Code Mounting

Your project code should be mounted into `/bp/workspace` in the container.
Example:

```bash
-v $(pwd):/bp/workspace
```

If your service is in a subdirectory (`my-service`), set:

```bash
-e CODEBASE_DIR=example
```

---

## Debugging / Shell Access

To override the entrypoint and get a shell inside the container:

```bash
docker run --rm -it \
  -v $(pwd):/bp/workspace \
  --entrypoint /bin/bash \
  registry.buildpiper.in/impl/pre-hooks:nr_v0.1
```

---

## Workflow Example

1. Build the image:

   ```bash
   docker build -t registry.buildpiper.in/impl/pre-hooks:nr_v0.1 .
   ```

2. Run with environment variables:

   ```bash
   docker run --rm -it \
     -e DEBUG=true \
     -e WORKSPACE=/bp/workspace \
     -e CODEBASE_DIR=my-service \
     -e PRE_HOOK_CMD="pwd && la" \
     -e VALIDATION_FAILURE_ACTION=FAILURE \
     -v $(pwd):/bp/workspace \
     registry.buildpiper.in/impl/pre-hooks:nr_v0.1
   ```
---
