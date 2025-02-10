
## Deploy on Kubernetes

Although we can deploy a service directly using a container, a container orchestration framework (like Kubernetes) will help us scale a deployment:

* If a container fails, Kubernetes can automatically detect it and replace it with a functional container.
* Kubernetes can deploy multiple instances of a container across several hosts, and balance the load across them.
* Kubernetes can automatically scale the deployment in response to load.

After completing this section:

* You should be able to deploy a Kubernetes cluster using `kubespray`
* You should be able to deploy a service in Kubernetes with multiple replicas for load balancing
* You should be able to use horizontal scaling to automatically adjust the number of replicas


### Preliminaries

This subsection involves running commands on the hosts in our cluster (node1, node2, and node3) by using SSH from the Chameleon JupyterHub environment, then running commands inside the SSH session.

Inside the Chameleon JupyterHub environment, open three terminals:

**SSH to node1**: In the first terminal, SSH to the node1 using the floating IP address assigned to it (substitute this IP for `A.B.C.D`):

```
ssh -A cc@A.B.C.D
```

Note the `-A` argument - this is important. The `-A` allows us to "jump" from node1 to another node using the same key with which we authenticated to node1.

**SSH to node2**: In the second terminal, run the following command (substitute the floating IP assigned to your node1 for `A.B.C.D`) to SSH to node2, but using node1 to "jump" there (since node2 does not have a floating IP assigned, we cannot SSH to it directly):

```
ssh -A -J cc@A.B.C.D cc@192.168.1.12
```


**SSH to node3**: In the second terminal, run the following command (substitute the floating IP assigned to your node1 for `A.B.C.D`) to SSH to node3, but using node1 to "jump" there (since node3 does not have a floating IP assigned, we cannot SSH to it directly):

```
ssh -A -J cc@A.B.C.D cc@192.168.1.13
```


We are going to use a project called `kubespray` to bring up a Kubernetes cluster on our three-node topology.

First, though, we must:

* set up SSH login from the node1 host to all other hosts. It will use this SSH access during the installation and setup process.
* configure the firewall on all three nodes. Kubespray does not manage firewall rules for us.


We'll start with the SSH connections between hosts. On node1, we'll generate a new keypair:

```bash
# run on node1
ssh-keygen -t rsa -b 4096 -f ~/.ssh/id_rsa -q -N "" 
```

Then, we copy that newly generated public key from node1 to the "authorized keys" list on each of the three nodes in the cluster (including node1 itself):


```bash
# run on node1
ssh-copy-id -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -i ~/.ssh/id_rsa.pub cc@192.168.1.11;
ssh-copy-id -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -i ~/.ssh/id_rsa.pub cc@192.168.1.12;
ssh-copy-id -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -i ~/.ssh/id_rsa.pub cc@192.168.1.13;
```


Next, we will disable the host-level firewall on all three nodes (we are still protected by the security groups we configured from the infrastructure provider):

```bash
# run on node1, node2, and node3
sudo service firewalld stop
```


Finally, we need to remove the version of Docker we installed earlier on node1; `kupesrapy` will install a different version (one that is specifically known to work with the version of Kubernetes that it will deploy).


```bash
# run on node1
sudo apt -y remove docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin;
sudo rm /etc/apt/sources.list.d/docker.list; sudo apt update;
```


### Prepare `kubespray`

Now, we'll download and set up `kubespray`, which will help us deploy our Kubernetes cluster.

First, we get the source code and prepare a Python virtual environment in which to run it:

```bash
# run on node1
git clone --branch release-2.26 https://github.com/kubernetes-sigs/kubespray
sudo apt update; sudo apt -y install virtualenv
virtualenv -p python3 myenv
```

We install prerequisite Python packages in this virual environment

```bash
# run on node1
source myenv/bin/activate;  cd kubespray;   pip3 install -r requirements.txt; pip3 install ruamel.yaml; 
```

We copy over a sample "cluster inventory" provided by `kubespray`, and make a couple of change to the configuration:

* we select `docker` as the container manager
* and we enable the metrics server, which we will use for automatic scaling of our deployment

```bash
# run on node1
cd; mv kubespray/inventory/sample kubespray/inventory/mycluster;
sed -i "s/container_manager: containerd/container_manager: docker/" kubespray/inventory/mycluster/group_vars/k8s_cluster/k8s-cluster.yml;
sed -i "s/metrics_server_enabled: false/metrics_server_enabled: true/" kubespray/inventory/mycluster/group_vars/k8s_cluster/addons.yml;
```

Finally, we use an "inventory builder" script to describe the configuration of our desired cluster. We define the list of IP addresses of the nodes that will be included in the cluster, then let the automatic inventory builder create our configuration.

```bash
# run on node1
cd; source myenv/bin/activate;  cd kubespray;  
declare -a IPS=(192.168.1.11 192.168.1.12 192.168.1.13);
CONFIG_FILE=inventory/mycluster/hosts.yaml python3 contrib/inventory_builder/inventory.py ${IPS[@]};
```


We can look at the configuration we will deploy, and make sure everything looks as expected:

```bash
# run on node1    
cat ~/kubespray/inventory/mycluster/hosts.yaml
```

### Install Kubernetes

We're ready for the installation step! This will take a while, so you can start it and then step away for a half hour or so. 

If you get interrupted, you can just re-connect to node1 and then run the command below again.

```bash
# run on node1    
cd; source myenv/bin/activate; cd kubespray; ansible-playbook -i inventory/mycluster/hosts.yaml  --become --become-user=root cluster.yml
```

When the process is finished, you will see a “PLAY RECAP” in the output (near the end):

```
PLAY RECAP *********************************************************************
localhost                  : ok=3    changed=0    unreachable=0    failed=0    skipped=0    rescued=0    ignored=0   
node1                     : ok=752  changed=149  unreachable=0    failed=0    skipped=1276 rescued=0    ignored=8   
node2                     : ok=652  changed=136  unreachable=0    failed=0    skipped=1124 rescued=0    ignored=3   
node3                     : ok=535  changed=112  unreachable=0    failed=0    skipped=797  rescued=0    ignored=2  
```

Make sure that each node shows `failed=0`. If not, you should re-run the command above, to re-try the failed parts. (If you re-run it a few times and it's still not working, though, that's a sign that something is wrong and you might need to get some help.)

We are almost ready to use our Kubernetes cluster! We just need to copy some configuration files from the root user to the non-privileged user, so that the non-privileged user will be able to run `kubectl` commands to use the cluster.

```bash
# run on node1
cd; sudo cp -R /root/.kube /home/cc/.kube; sudo chown -R cc /home/cc/.kube; sudo chgrp -R cc /home/cc/.kube
```

Now, we can run 

```bash
# run on node1
kubectl get nodes
```

and we should see three nodes with `Ready` status.


### Prepare a container registry


> **Note** 
>
> If you have just run the "Docker" section of this tutorial on the same cluster, you have already configured it so that  `docker` commands can run as an unprivileged user! If you haven't, do that now on node1 (and after you do, use `exit` to end your SSH session and then, reconnect): 
>
> `sudo groupadd -f docker; sudo usermod -aG docker $USER`


In a previous section, we had built a Docker container and run it from a single host. Now that we have a cluster, though, we need to make our container image available across the cluster.

For this, we'll need a container registry. We prefer not to have to bother with a public registery, like Docker hub, for now; we'll set up a private container registry on this node. 

Run 


```bash
# run on node1
docker run -d -p 5000:5000 --restart always --name registry registry:2
```

to start a registry (inside a container, of course!) which will run on port 5000 on node1.

This registry is not secured (there is no authentication; anyone can push a container image to the registry, or pull a container image from the registry). We will have to explicitly configure the Docker engine on each of the three nodes to permit the use of this registry.

```bash
# run on node1, node2, and node3
sudo vim /etc/docker/daemon.json
```

In the editor, type `i` to switch from command mode to insert mode. Then, paste


```
{
    "insecure-registries": ["node1:5000"]
}
```

Use `Esc` to get back in command mode, then `:wq` and hit Enter to save and quit the tet editor.

To apply this change, restart the Docker service:

```bash
# run on node1, node2, and node3
sudo service docker restart
```

You can close the SSH connections to node2 and node3 now; you'll only need to run commands on node1 for the rest of this section.

We'll need to push the container for our GourmetGram app to this registry. Run

```bash
# run on node1
# un-comment if you haven't already retrieved the gourmetgram source
# git clone https://github.com/teaching-on-testbeds/gourmetgram gourmetgram

docker build -t gourmetgram-app:0.0.1 gourmetgram
docker tag gourmetgram-app:0.0.1  node1:5000/gourmetgram-app:latest
docker push node1:5000/gourmetgram-app
```

### Deploy your service on Kubernetes

On Kubernetes, **namespaces** are used to create logical groups of resources, services, applications, etc. Let's create a namespace for our GourmetGram test service:

```bash
# run on node1
kubectl create namespace kube-gourmetgram
```

We can list existing namespaces with 

```bash
# run on node1
kubectl get namespaces
```

Now, we are going to prepare a file that describes the details of the service we will run on Kubernets. Create this file with

```bash
# run on node1
vim deployment.yaml
```

and use `i` to switch from command mode to insert mode. 

> **Note**:
> 
>  Whitespace matters in YAML files, so when pasting content in this file, make sure to match the indentation shown here!


Then, paste the following:

```
apiVersion: v1
kind: Service
metadata:
  name: gourmetgram-kube-svc
  namespace: kube-gourmetgram

```

This says we are going to define a **Service**. A Service in Kubernetes is the network endpoint on which your application can be reached; although the application is actually going to be executed by one or more containers potentially distributed across nodes in the cluster, it can always be reached at this network endpoint.

We specify the name of the service, `gourmetgram-kube-svc`, and that it is in the `kube-gourmetgram` namespace.

Next, paste in the rest of the definition of the Service:

```
spec:
  selector:
    app: gourmetgram-kube-app
  ports:
    - protocol: "TCP"
      port: 80          # Service port inside the cluster
      targetPort: 8000  # Forward to the pod's port 8000
  externalIPs:
    - 10.56.X.Y
  type: ClusterIP
```

but in place of 10.56.X.Y, substitute the IP address of your node1 host on the `sharednet1` network (the network that faces the Internet).

This specifies that our service will be the network endpoints for the `gourmetgram-kube-app` application (which we'll define shortly). Our service will listen for incoming connections on TCP port 80, and then it will forward those requests to the containers running the application on *their* port 8000. 

The service is of type **ClusterIP**, which means that it will accept incoming traffic on an IP address that belongs to a node in the cluster; here, we specify the IP address in `externalIPs`.

![ClusterIP deployment illustration.](images/2-k8s-ports-service-types.svg)

Next, we'll add a **Deployment** definition to the file. Paste in the following:

```
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: gourmetgram-kube-app
  namespace: kube-gourmetgram
```

While a Service describes the network endpoint, the Deployment describes the pods that will run and actually implement the service. (In Kubernetes, a **pod** is a container or a group of containers that are deployed and scaled together; we'll stick to one-container-per-pod.) We have named our deployment `gourmetgram-kube-app`.

Next, we will specify more details of the Deployment. Paste this into the file:

```
spec:
  selector:
    matchLabels:
      app: gourmetgram-kube-app
  replicas: 1
  template:
    metadata:
      labels:
        app: gourmetgram-kube-app
```

Our Deployment will give all pods it creates the label `gourmetgram-kube-app`. Note that this app label was specified in the "selector" part of the Service definition; this makes sure that traffic directed to the Service will be passed to the correct pods.

Our current Deployment uses 1 **replicas**, or copies of the pod.

Next, we'll specify the details of the containers in the pods. Paste this in:

```
    spec:
      containers:
      - name: gourmetgram-kube-app
        image: node1:5000/gourmetgram-app:latest
        imagePullPolicy: Always
        ports:
        - containerPort: 8000
```

We specify that the containers should use the image "gourmetgram-app:latest" from our private container image registry running on node1 port 5000, and that the container itself exposes port 8000.

Next, we'll add a **readiness probe**. In our application, we have implemented a `/test` endpoint that returns a prediction for an image that is already present in the app. Kubernetes will use this to determine when a pod is ready to start receiving traffic; it will consider a pod ready only after three HTTP GET calls to the `/test` endpoint have returned successfully.

Paste this into the config:


```
        readinessProbe:
          httpGet:
            path: /test
            port: 8000
          periodSeconds: 5
          initialDelaySeconds: 5
          successThreshold: 3
```

Finally, we'll specify the compute resource that our containers will need. Here, we say that each container should not be allowed to exceed half of a CPU and 500M of RAM; and that a container requires at least 30% of a CPU and 300M of RAM (otherwise, it will not even start). 

Paste this into the file:

```
        resources:
          limits:
            cpu: "0.5"
            memory: "500Mi"
          requests:
            cpu: "0.3"
            memory: "300Mi"
```


Once you have finished the `deployment.yaml`, use `Esc` to switch back to command mode, then `:wq` and `Enter` to quit the editor.

We're ready to apply the configuration in the file now! Run

```bash
# run on node1
kubectl apply -f deployment.yaml
```

You should see some output that says

```
service/gourmetgram-kube-svc created
deployment.apps/gourmetgram-kube-app created
```

To see the status of everything in this namespace, run

```bash
# run on node1
kubectl get all -n kube-gourmetgram  -o wide
```

Note that your pod may be deployed in any node in the cluster; you will see which in the "NODE" column.

Initially, your pod may be in "ContainerCreating" state; then it may go to "Running" state, but with a "0/1" in the "Ready" column. Finally, once it passes the "readiness probe", it will appear as "1/1" in the "Ready" column.

When it does, you can put

```
http://A.B.C.D
```

in the address bar of *your own* browser (on your laptop), substituting the floating IP assigned to the instance. Try uploading an image of a food item to the service.

Let's stress-test our service.  On node1, run

```bash
# run on node1
sudo apt update; sudo apt -y install siege
```

Open a second SSH session on node1. In one, run

```bash
# run on node1
watch -n 5 kubectl top pod -n kube-gourmetgram
```

to monitor the pod's resource usage (CPU and memory) in real time.

In the second SSH session, run

```bash
# run on node1
siege -c 10 -t 30s http://$(curl -s ifconfig.me/ip)/test
```

to run a test in which you establish many concurrent connections to the `/test` endpoint on the web service (which causes it to make a prediction!)

While it is running, you may see some instances of

```
[error] socket: unable to connect sock.c:282: Connection refused
```

in the output. This is an indication that in the tests, some of the connections failed entirely because the service is under such heavy load.

Watch the `kubectl top pod` output as the test is in progress, and make a note of the CPU and memory usage of the container when it is under load. (The container may crash and need to be restarted during the test; if it does, you'll temporarily be unable to see compute resource usage as it restarts.)

When the "siege" test is finished, it will print some information about the test, including the total number of transactions served (not including failed connections!) and the average response time (in seconds) for those connections. Make a note of these results.

(You can use Ctrl+C to stop watching the pod resource usage.)

### Deploy your service on Kubernetes with more replicas

To support more load, we may increase the number of replicas of our pod. Run

```bash
# run on node1
vim deployment.yaml
```

Navigate to the line where the number of replicas is defined. Then, use `i` to switch from command mode to insert mode, and change it from 1 to 6.

Use `Esc` to return to command mode, and `:wq` and then `Enter` to save the file and quit the editor.

To apply this change, run 

```bash
# run on node1
kubectl apply -f deployment.yaml
```

To see the effect, run

```bash
# run on node1
kubectl get all -n kube-gourmetgram  -o wide
```

and note that we should now have six replicas of the pod! 

Let's repeat our stress test. In one SSH session on node1, run

```bash
# run on node1
watch -n 5 kubectl top pod -n kube-gourmetgram
```

In the second SSH session, run

```bash
# run on node1
siege -c 10 -t 30s http://$(curl -s ifconfig.me/ip)/test
```

When the "siege" test is finished, note the total number of transactions served during the 30 second test (it should be much larger than before!) and the average response time (it should be much smaller!)

(You can use Ctrl+C to stop watching the pod resource usage.)


### Deploy your service on Kubernetes with automatic scaling

While our service is responding nicely now, it's also wasting compute resources when the load is *not* heavy. To address this, we can use scaling - where the resource deployment changes in response to load on the service. In this example, specifically we use horizontal scaling, which adds more pods/replicas to handle increasing levels of work, and removes pods when they are not needed. (This is in contrast to vertical scaling, which would increase the resources assigned to pods - CPU and memory - to handle increasing levels of work.)

Run

```bash
# run on node1
vim deployment.yaml
```

Navigate to the line where the number of replicas is defined. Then, use `i` to switch from command mode to insert mode, and change it from 6 back to 1. (The number of replicas will be handled dynamically in a new section that we are about to add.)

Then, go to the bottom of the file, and paste the following:

```
---
apiVersion: autoscaling/v2
kind: HorizontalPodAutoscaler
metadata:
  name: gourmetgram-kube-hpa
  namespace: kube-gourmetgram
spec:
  scaleTargetRef:
    apiVersion: apps/v1
    kind: Deployment
    name: gourmetgram-kube-app
  minReplicas: 2
  maxReplicas: 6
  metrics:
  - type: Resource
    resource:
      name: cpu
      target:
        type: Utilization
        averageUtilization: 50
```

This says to scale the number of replicas from 2 (minimum) up to 6 (maximum) if the existing replicas have high CPU utilization, i.e. they are under heavy load.

Use `Esc` to return to command mode, and `:wq` and then `Enter` to save the file and quit the editor.

To apply this change, run 

```bash
# run on node1
kubectl apply -f deployment.yaml
```

To see the effect, run

```bash
# run on node1
kubectl get all -n kube-gourmetgram  -o wide
```

Some of our pods are now "Terminating" in order to meet our new scaling constraints! Near the bottom of this output, note the current CPU utilization is compared to the target we set.


Let's add some load. In one SSH session on node1, run

```bash
# run on node1
watch -n 5 kubectl get all -n kube-gourmetgram  -o wide
```

In the second SSH session, run

```bash
# run on node1
siege -c 10 -t 30s http://$(curl -s ifconfig.me/ip)/test
```

In response to the load, you will see that the number of pods is increased. Wait a few minutes, then run the test again:


```bash
# run on node1
siege -c 10 -t 30s http://$(curl -s ifconfig.me/ip)/test
```

and you may see the deployment scale up again, in response to the persistent load.

If you keep watching, though, after about 5 minutes of minimal load, the deployment will revert back to its minimum size of 2 replicas.

### Stop the deployment

When we are finished, we can clean up everything with

```bash
# run on node1
kubectl delete -f deployment.yaml
```
