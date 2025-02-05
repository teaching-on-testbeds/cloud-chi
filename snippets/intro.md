::: {.cell .markdown}


# Cloud Computing on Chameleon

In this tutorial, we will explore some elements of cloud computing infrastructure using Chameleon, an OpenStack cloud (although the basic principles are common to all types of clouds). 

* First, we will provision virtual machines, networks, and ports using the OpenStack GUI, Horizon. Then, we will practice using the CLI. 
* We will use Docker to containerize a simple application and serve it from our cloud resources.
* Finally, we will install Kubernetes on our cluster, and use it to manage our containerized application.

To run this experiment, you should have already created an account on Chameleon, and become part of a project. You should also have added your SSH key to the KVM@TACC site.

:::

::: {.cell .markdown}

## Experiment topology 

In this experiment, we will deploy a Kubernetes cluster on Chameleon instances. The cluster will be self-managed, which means that the infrastructure provider is not responsbile for setting up and maintaining our cluster; *we* are.  

However, the cloud infrastructure provider will provide the compute resources and network resources that we need for our cluster. We will provision the following resources for this experiment:

![Experiment topology.](images/2-lab-topology.svg)


This includes:

* **Compute resources**: three virtual machine instances.
* **Network resources**: 
  * the VMs will be attached to an Internet-connected network provisioned by the infrastructure provider, and we will use security groups to protect this network.
  * the VMs will also be attached to a "private" network that we provision, on which the virtual machine instances can communicate with one another. We will use the following subnet on this network: 192.168.1.0/24. This means that every VM instance on this network will get an address in the form 192.168.1.X, where X is different for each VM instance on the network.
  * We will get a publicly routable "floating IP" address for one of the VM instances, and add this address to the VM's network interface on the Internet-connected network. This will allow us to SSH to this VM over the Internet, and we can then "hop" from this VM to any of the others.

:::

::: {.cell .markdown}

## Provision a key

Before you begin, open this experiment on Trovi:

* Use this link: [Cloud Computing on Chameleon](https://chameleoncloud.org/experiment/share/a5efb034-917e-4fdd-b83d-1a7f8930d960) on Trovi
* Then, click “Launch on Chameleon”. This will start a new Jupyter server for you, with the experiment materials already in it.

You will see several notebooks inside the `cloud-chi` directory - look for the one titled `0_intro.ipynb`. Open this notebook and execute the following cell (and make sure the correct project is selected):

:::

::: {.cell .code}
```python
from chi import server, context

context.version = "1.0" 
context.choose_project()
context.choose_site(default="KVM@TACC")

server.update_keypair()
```
:::

::: {.cell .markdown}

Then, you may continue following along at [Cloud Computing on Chameleon](https://teaching-on-testbeds.github.io/cloud-chi/) until the next part that requires the Jupyter environment. 


:::
