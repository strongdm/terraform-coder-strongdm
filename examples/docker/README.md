# Example Coder template: Docker workspace with StrongDM

A complete Coder template to copy and adapt. Each workspace is a Docker container that gets the StrongDM CLI from the [`strongdm` module](../../strongdm) and signs in as the workspace owner.

| File         | Purpose                                                                                                         |
| ------------ | --------------------------------------------------------------------------------------------------------------- |
| `main.tf`    | The template: Coder agent, the `strongdm` module, and a Docker container with a persistent home volume.          |
| `Dockerfile` | The workspace image. It has what the module needs: `curl`, `unzip`, `sha256sum`, `sed` and `awk`.                |

Change whatever your environment needs: the base image and the tools in it, resource limits, the volume, or swap the Docker resources for your own runtime. Keep the `module "strongdm"` block and an image with the module's requirements.

## Use it

1. Add StrongDM to your Coder server and create the integration in StrongDM, as in the [repository README](../../README.md), steps 1 and 2.
2. Push the template, which uploads this directory:

   ```bash
   coder templates push strongdm-docker --directory examples/docker \
     --variable strongdm_client_id=<client ID>
   ```

   If your external auth provider ID is not `strongdm`, add `--variable strongdm_provider_id=<id>`. For a regional StrongDM control plane, add `--variable strongdm_app_domain=app.uk.strongdm.com`, or your region's host.
3. Each developer links StrongDM under **Account > External Authentication**, then creates a workspace from the template.
4. In the workspace terminal, `sdm status` lists the resources they can use.

The Docker provider in `main.tf` uses the Docker socket of the machine that runs the Coder provisioner. The container reaches the Coder server through `host.docker.internal`, which suits a Coder server on the same host. If your Coder access URL is reachable from workspaces, delete the `replace(...)` around `init_script` and the `host` block.
