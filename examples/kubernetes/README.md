# Example Coder template: Kubernetes workspace with StrongDM

A complete Coder template to copy and adapt. Each workspace is a Deployment with a persistent home volume. It gets the StrongDM CLI from the [`strongdm` module](../../strongdm) and signs in as the workspace owner.

| File         | Purpose                                                                                                           |
| ------------ | ----------------------------------------------------------------------------------------------------------------- |
| `main.tf`    | The template: Coder agent, the `strongdm` module, a PersistentVolumeClaim and a Deployment.                       |
| `Dockerfile` | An image with what the module needs: `curl`, `unzip`, `sha256sum`, `sed` and `awk`. Optional; see below.          |

Change whatever your cluster needs: the image, resource requests and limits, the storage class, node selectors, or the security context. Keep the `module "strongdm"` block and an image with the module's requirements.

## Use it

1. Add StrongDM to your Coder server and create the integration in StrongDM, as in the [repository README](../../README.md), steps 1 and 2.
2. Make sure the Coder provisioner can manage Deployments and PersistentVolumeClaims in the workspace namespace. The Coder Helm chart does this for its own namespace.
3. Push the template, which uploads this directory:

   ```bash
   coder templates push strongdm-kubernetes --directory examples/kubernetes \
     --variable strongdm_client_id=<client ID>
   ```

   Add `--variable namespace=<namespace>` if workspaces don't run in `coder`. If your external auth provider ID is not `strongdm`, add `--variable strongdm_provider_id=<id>`. For a regional StrongDM control plane, add `--variable strongdm_app_domain=app.uk.strongdm.com`, or your region's host.
4. Each developer links StrongDM under **Account > External Authentication**, then creates a workspace from the template.
5. In the workspace terminal, `sdm status` lists the resources they can use.

The default image, `codercom/example-base:ubuntu`, has the module's requirements. To use your own, build the `Dockerfile`, push it to a registry your cluster can pull from, and set `--variable image=<your image>`.

Workspaces run on nodes with the same architecture as the Coder provisioner, because the agent binary is built for it. To run on a different architecture, change `arch` in the `coder_agent` and the Pod's `node_selector` together.

An init container makes `/home/coder` owned by the workspace user and not writable by others. Many volume provisioners create it as `root`, writable by everyone, and the StrongDM CLI refuses to read its credential file from a home directory like that. Keep the init container, or make sure your volumes have the same ownership.

The provider uses the credentials of the Coder provisioner's service account. To use a kubeconfig instead, set `config_path` in the `kubernetes` provider block.
