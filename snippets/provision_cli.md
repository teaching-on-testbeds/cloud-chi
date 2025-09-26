
::: {.cell .markdown}

## Provision resources using the `openstack` CLI

:::

::: {.cell .markdown}

Although the GUI is useful for exploring the capabilities of a cloud, the command line interface is much more efficient for provisioning resources. In this section, we will practice using the `openstack` CLI to explore the capabilities of our cloud and manage resources.

To follow along, open this experiment on Trovi:

* Use this link: [Cloud Computing on Chameleon](https://chameleoncloud.org/experiment/share/a5efb034-917e-4fdd-b83d-1a7f8930d960) on Trovi
* Then, click “Launch on Chameleon”. This will start a new Jupyter server for you, with the experiment materials already in it.

You will see several notebooks inside the `cloud-chi` directory - look for the one titled `2_provision_cli.ipynb`. Note that this is a `bash` notebook that executes `bash` commands on the terminal in the Jupyter environment. 

After completing this section:

* You should be able to provision server instances and ports using the `openstack` CLI
* You should be able to use the `openstack` CLI to see already provisioned resources

:::

::: {.cell .markdown}

When we left off in the previous section, we had provisioned part of our overall topology (not including the gray parts):

![Experiment topology.](images/2-lab-topology-with-floating.svg)

Now, we will provision the rest.

:::


::: {.cell .markdown}

### Authentication

When we use the GUI to provision and manage resources, we had to sign in first. Similarly, to use the CLI, we must authenticate with the OpenStack Keystone service. However, the Chameleon JupyterHub instance that we are running this notebook on is already configured to authenticate the `openstack` client.

We just need to set some additional environment variables that specify which Chameleon site we want to use (KVM@TACC) and which project. In the cell below, replace `CHI-XXXXXX` with the name of *your* Chameleon project, then run the cell.

:::

::: {.cell .code}
```bash
export OS_AUTH_URL=https://kvm.tacc.chameleoncloud.org:5000/v3
export OS_PROJECT_NAME="CHI-XXXXXX"
export OS_REGION_NAME="KVM@TACC"
```
:::

<!-- 
::: {.cell .markdown}

### Other setup

The OpenStack CLI installed in this JupyterHub environment is not the most recent version, and we need some features that are only available in the most recent version (namely: VM instance reservation). So, we must update the Blazar (reservation service) client, and then make sure the shell will use that updated version.

:::

::: {.cell .code}
```bash
PYTHONUSERBASE=/work/.local pip install --user git+https://github.com/ChameleonCloud/python-blazarclient.git
export PATH=/work/.local/bin:$PATH
```
:::

-->

::: {.cell .markdown}

### Exploring the cloud

The openstack CLI has many capabilities, most of which we won't touch at all. Run the following cell to see some of them:

:::


::: {.cell .code}
```bash
openstack help
```
:::


::: {.cell .markdown}

Note, however, that some of these commands are unavailable to use because of access management policies (e.g. some commands are only available to the cloud infrastructure provider) and because the OpenStack cloud we are using may not necessarily include all of the possible services that an OpenStack cloud *can* offer.

To see the services available from the current site (KVM@TACC), run

:::

::: {.cell .code}
```bash
openstack catalog list
```
:::

::: {.cell .markdown}

### Work with network resources

Before we provision new resources, let's look at the resources we created earlier. We'll start with the network resources.

:::

::: {.cell .markdown}

We can list all of the networks that are provisioned by our project at KVM@TACC:

:::

::: {.cell .code}
```bash
openstack network list
```
:::


::: {.cell .markdown}

but there may be a lot of them! We can use `grep` to filter this output by our own net ID, to see the private network we created earlier. In the cell below, replace **netID** with your *own* net ID before you run it.

:::

::: {.cell .code}
```bash
openstack network list | grep netID
```
:::


::: {.cell .markdown}

You can also get the details of any network by specifying its name or ID, e.g. in the cell below replace **netID** with your own net ID - 

:::

::: {.cell .code}
```bash
openstack network show private_cloud_net_netID
```
:::


::: {.cell .code}
```bash
openstack network show sharednet1
```
:::

::: {.cell .markdown}

We can similarly see the subnets we created earlier. In the two cells below, replace **netID** with your *own* net ID before you run them.

:::

::: {.cell .code}
```bash
openstack subnet list | grep netID
```
:::

::: {.cell .code}
```bash
openstack subnet show private_cloud_subnet_netID
```
:::

::: {.cell .markdown}

Let's add two more ports to our private network now. First, to see usage information:

:::

::: {.cell .code}
```bash
openstack port create -h
```
:::


::: {.cell .markdown}

Note that there are many more options available via the CLI than the GUI.

Now we will create two ports with the same options (fixed IP, no port security) as before - we will specify `192.168.1.12` and `192.168.1.13` as the fixed IP address for these new ports, and we will also give them each a name (to make it easier to use the port in subsequent `openstack` commands).

In the following two cells, you will need to replace **netID** with your own net ID *three* times in each - in the name of the network, in the name of the subnet, and in the name of the port.

:::


::: {.cell .code}
```bash
openstack port create \
    --network private_cloud_net_netID \
     --fixed-ip subnet=private_cloud_subnet_netID,ip-address=192.168.1.12 \
     --disable-port-security \
     port2_netID
```
:::



::: {.cell .code}
```bash
openstack port create \
    --network private_cloud_net_netID \
     --fixed-ip subnet=private_cloud_subnet_netID,ip-address=192.168.1.13 \
     --disable-port-security \
     port3_netID
```
:::


::: {.cell .markdown}

and then you may list ports on the network (substitute with your own net ID):

:::


::: {.cell .code}
```bash
openstack port list --network private_cloud_net_netID
```
:::


::: {.cell .markdown}

Now, our topology looks like this:

![Experiment topology.](images/2-lab-topology-three-port.svg)

:::



::: {.cell .markdown}

### Work with compute resources

Next, let's look at the compute resources.

:::

::: {.cell .markdown}

First, since Chameleon requires reservations for compute instances, we'll need a reservation. Check the current reservation list with:

:::

::: {.cell .code}
```bash
openstack reservation lease list
```
:::


::: {.cell .markdown}

We will create a single lease with reservations for **two** `m1.medium` flavors, for 8 hours. We will use the `date` command to automatically set the start and end time.

In the cell below, replace **netID** with your own net ID, then run it to request a lease:

:::

::: {.cell .code}
```bash
openstack reservation lease create lease2_cloud_netID \
  --start-date "$(date -u '+%Y-%m-%d %H:%M')" \
  --end-date "$(date -u -d '+8 hours' '+%Y-%m-%d %H:%M')" \
  --reservation "resource_type=flavor:instance,flavor_id=$(openstack flavor show m1.medium -f value -c id),amount=2"
```
:::

::: {.cell .markdown}

Then, check the list again:

:::


::: {.cell .code}
```bash
openstack reservation lease list
```
:::




::: {.cell .markdown}

Now, we are ready to create some additional server instances.

In the cell below, replace **netID** with your own net ID to see a list of already-provisioned servers that have your net ID in their name:

:::


::: {.cell .code}
```bash
openstack server list --name "netID"
```
:::

::: {.cell .markdown}

We are going to add two more. First, to see usage information:

:::


::: {.cell .code}
```bash
openstack server create -h
```
:::

::: {.cell .markdown}

We are going to want to specify the image name and the key to install on the new compute instances, along with their network connectivity. We already confirmed the network resources, but let's look at the rest to make sure we know what everything is called:

:::

::: {.cell .code}
```bash
# there are MANY images available, so we'll just list a few
openstack image list --limit 5
```
:::


::: {.cell .code}
```bash
openstack keypair list
```
:::

::: {.cell .markdown}

We are also going to need to get the reserved "flavor" ID, from the reservation we just made. We'll save this in a variable `flavor_id` so that we can reuse it in our `openstack server create` command.

In the cell below, replace **netID** with your own net ID in the lease name. This cell should print a UUID:

:::

::: {.cell .code}
```bash
flavor_id=$(openstack reservation lease show lease2_cloud_netID -f json -c reservations \
      | jq -r '.reservations[0].flavor_id')
echo $flavor_id
```
:::

::: {.cell .markdown}

Now we can launch our additional compute instances! In the two cells below, you will need to 

* replace **netID** with your own net ID in the port name
* replace `id_rsa_chameleon` with the name of the key as listed in Chameleon, if it is different
* replace **netID** with your own net ID in the name of the server (last line)

:::

::: {.cell .code}
```bash
openstack server create \
  --image "CC-Ubuntu24.04" \
  --flavor $flavor_id \
  --network sharednet1 \
  --port port2_netID \
  --security-group default \
  --security-group allow-ssh \
  --security-group allow-http-80 \
  --key-name id_rsa_chameleon \
  --user-data config-hosts.yaml \
  node2-cloud-netID
```
:::

::: {.cell .code}
```bash
openstack server create \
  --image "CC-Ubuntu24.04" \
  --flavor $flavor_id \
  --network sharednet1 \
  --port port3_netID \
  --security-group default \
  --security-group allow-ssh \
  --security-group allow-http-80 \
  --key-name id_rsa_chameleon \
  --user-data config-hosts.yaml \
  node3-cloud-netID
```
:::


::: {.cell .markdown}

You can get your new server list with 

:::


::: {.cell .code}
```bash
openstack server list --name "netID"
```
:::

::: {.cell .markdown}

Finally, our topology looks like this:

![Experiment topology.](images/2-lab-topology.svg)

:::


::: {.cell .markdown}

> **Note**
> 
> You may have noticed that in Openstack, everything - network, port, subnet, flavor, disk image, compute instance, etc. - has an ID associated with it. In the commands above, we used names, but we could have used IDs (and if there were duplicate resources with the same name, we would have to use IDs).

:::

::: {.cell .markdown}

Now that we have resources, in the next section we will deploy a containerized application on them.

:::

