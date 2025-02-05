
## Provision resources using the GUI

We will practice provisioning resources using the GUI and also using the CLI. First, we will practice using the GUI. After completing this section:

* You should be able to provision VM instances, networks, and ports (with appropriate security groups) using the Horizon GUI
* You should be able to associate a floating IP with an instance using the Horizon GUI
* You should be aware of the options for managing a server instance (e.g. reboot, rebuild, delete) using the Horizon GUI


### Access the Horizon GUI

We will use the OpenStack graphical user interface, which is called Horizon, to provision our resources. To access this interface,

* from the [Chameleon website](https://chameleoncloud.org/hardware/)
* click "Experiment" > "KVM@TACC"
* log in if prompted to do so
* check the project drop-down menu near the top left (which shows e.g. "CHI-XXXXXX"), and make sure the correct project is selected.


> **Note**
> 
> Be careful to set the *name* of each resource - network, router, or compute instance - exactly as instructed. 


### Provision a "private" network

First, let's set up our "private" network.

* On the left side of the interface, expand the "Network" menu
* Choose the "Networks" option
* Click the "Create network" button 

You will be prompted to set up your network step by step using a graphical "wizard".

* On the first ("Network") tab, specify the network name as <code>private_cloud_net_<b>netID</b></code> where in place of <code><b>netID</b></code> you substitute your own net ID (e.g. `ff524` in my case). Leave other settings at their defaults, and click "Next".
* On the second ("Subnet") tab, specify the subnet name as <code>private_cloud_subnet_<b>netID</b></code> where in place of <code><b>netID</b></code> you substitute your own net ID (e.g. `ff524` in my case). Specify the subnet address as `192.168.1.0/24`. Check the "Disable gateway" box. Leave other settings at their defaults, and click "Next".
* On the third ("Subnet Details") tab, leave all settings at their default values. Click "Create".

You should now see your network in the list of networks shown in the GUI.  

We have provisioned this part of the overall topology (not including the gray parts):

![Experiment topology.](images/2-lab-topology-private-net-only.svg)


### Provision a port on our "private" network

When we create a compute instance and want it to have a point of attachment to a network, we can either 

* attach it to a network directly (which will create a port on that network - in the "switch port" sense, not "TCP port" sense - and then attach that port to the network)
* or we can prepare a port on the network in advance, and then when creating the instance, attach it to that port. This may be necessary if we want a non-default configuration on the port, e.g. a fixed IP address instead of one that is assigned dynamically, or to have port security disabled.

We are now going to create a port on our "private" network, and later we will attach a compute instance to it.

* On the left side of the interface, expand the "Network" menu
* Choose the "Networks" option
* Click on the <code>private_cloud_net_<b>netID</b></code> network you created earlier.
* Choose the "Ports" tab from the options on the top.
* Click "Create Port".

We will set up the port as follows:

* It's OK to leave "Name" blank (a name will be automatically generated)
* In the "Specify IP address or subnet" menu, choose "Fixed IP address"
* Then, in the "Fixed IP Address" field, put `192.168.1.11`
* Un-check the box next to "Port Security"
* Leave other settings at their default values
* Click "Create".

Our topology now looks like this (gray parts are not yet provisioned):

![Experiment topology.](images/2-lab-topology-one-port.svg)

### Provision a VM instance

Next, let's create a VM instance.

* On the left side of the interface, expand the "Compute" menu
* Choose the "Instances" option
* Click the "Launch Instance" button 

You will be prompted to set up your instance step by step using a graphical "wizard".


* On the first ("Details") tab, set the instance name to  <code>node1-cloud-<b>netID</b></code> where in place of <code><b>netID</b></code> you substitute your own net ID (e.g. `ff524` in my case). Leave other settings at their default values, and click "Next".
* In the second ("Source") tab, we specify the source disk from which the instance should boot. In the "Select Boot Source" menu, choose "Image". Then, in the "Available" list at the bottom, search for `CC-Ubuntu24.04` (exactly - without any date suffix). Click the arrow next to this entry. You will see the `CC-Ubuntu24.04` image appear in the "Allocated" list. Click "Next".
* In the third ("Flavor") tab, we specify the resources that will be allocated to the instance. In the "Available" list at the bottom, click the arrow next to `m1.medium`.  You will see the `m1.medium` flavor appear in the "Allocated" list. Click "Next".
* In the fourth ("Networks") tab, we will attach the instance to a network provided by the infrastructure provider which is connected to the Internet.
  * From the "Available" list, click on the arrow next to `sharednet1`. It will appear as item 1 in the "Allocated" list. 
  * Click "Next".
* In the fifth ("Ports") tab, we will additionally use the port we just created to attach the instance to the private network we created earlier. 
  * From the "Available" list, find the port you created earlier. (The subnet is noted by name in the "IP" column. Since the subnet has your net ID in its name, you can search using your net ID to find "your" port.)
  * Click the arrow next to it, and it will appear in the "Available" list.
  * Click "Next".
* In the sixth ("Security Groups") tab, we will specify the rules according to which the infrastructure provider will pass traffic to and from our instances. We need to add security groups for any port (in the "TCP port" sense, not the "switch port" sense) on which we will need to receive incoming connections on our instances.
  * Expand the `default` section to see the details of the currently allocated security group, `default`. It is configured to allow egress (outgoing) connections to any remote address (`0.0.0.0/0` means "every address"), but to allow ingress (incoming) connections from no address.
  * From the "Available" list at the bottom, find the `allow-ssh` security group and click the arrow next to it, so that it appears in "Allocated". If you expand this section, you will see that it permits incoming connections from any remote address on TCP port 22, which is used by the SSH service.
  * From the "Available" list at the bottom, find the `allow-http-80` security group and click the arrow next to it, so that it appears in "Allocated". If you expand this section, you will see that it permits incoming connections from any remote address on TCP port 80, which will be used by the web service we will host on our instance.
  * Click "Next".
* In the seventh ("Key Pair") tab, find the SSH key associated with your laptop on the "Available" list. Click on the arrow next to it to move it to the "Allocated" section. 
* In the eighth ("Customization") tab, paste the following into the text input field:

```
#cloud-config
runcmd:
  - echo "127.0.1.1 $(hostname)" >> /etc/hosts
```

Then you can click "Launch Instance" (the remaining tabs are not required).

You will see your instance appear in the list of compute instances, initally in the "Spanning" state. Within a few moments, it will go to the "Running" state. 

Click on the &#x25BC; menu to the far right side of the running compute instance, to see the options that are available. You will see that you can do things like:

* restart the instance
* rebuild the instance (load the same or a different disk image)
* or delete the instance

using the GUI. You also can click on the instance name to see the "Overview" according to the configuration you just specified.

Our topology now looks like this (gray parts are not yet provisioned):

![Experiment topology.](images/2-lab-topology-one-vm.svg)


### Provision a floating IP

The VM instance currently has only "private" addresses which are not reachable over the Internet:

* It has an address in the 192.168.1.0/24 "private" network we created. This network is not connected to the Internet.
* It has an address in the 10.56.0.0/22 subnet on the `sharednet1` network provided by Chameleon for Internet access. However, while this network allows the instance to initiate a connection to an endpoint on the Internet (using NAT), it is still within the private address range, so it is not usable for initiating a connection *to* the instance across the Internet.

We are going to provision and attach a "floating IP", which is a public address that will allow us to initiate a connection to the instance across the Internet.

* On the left side of the interface, expand the "Network" menu
* Choose the "Floating IPs" option
* Click "Allocate IP to project"
* In the "Pool" menu, choose "public"
* In the "Description" field, write: <code>Cloud IP for <b>netID</b></code>, where in place of <code><b>netID</b></code> you use your own net ID.
* Click "Allocate IP"
* Then, choose "Associate" next to "your" IP in the list.
* In the "Port" menu, choose the port associated with your <code>node1-cloud-<b>netID</b></code> instance on the `shared1` network, with an IP address of the form `10.56.X.X`.
* Click "Associate".

Our topology now looks like this (gray parts are not yet provisioned):


![Experiment topology.](images/2-lab-topology-with-floating.svg)


### Access your instance over SSH

Now, you should be able to access your instance over SSH! Test it now. From your local terminal, run

```
ssh -i ~/.ssh/id_rsa_chameleon cc@A.B.C.D
```

where

* in place of `~/.ssh/id_rsa_chameleon`, substitute the path to your own key that you had uploaded to KVM@TACC
* in place of `A.B.C.D`, use the floating IP address you just associated to your instance.

and confirm that you can access the compute instance. Run

```
hostnamectl
```

inside this SSH session to see details about the host.

Also, run


```
echo "127.0.0.1 $(hostname)" | sudo tee -a /etc/hosts
```

inside the SSH session

### Provision additional instances

We *could* use a similar procedure to provision the two additional VMs we will need, but that's a lot of clicks! Instead, we will use the `openstack` command line interface.