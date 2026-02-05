

## Deploy a service in a Docker container


At this point, we have compute resources on which we could deploy a service directly - but we want to make sure that we deploy a service in a way that is scalable (like cattle, not like pets). So, install of installing libraries and middleware and deploying a service "natively", we will do all this inside a container.

After completing this section:

* You should be able to `pull` a Docker container and `run` a container (either in detached or interactive/TTY mode)
* You should be able to use `docker ps` to see running containers, `docker logs` to see output of a running proess in a container, and `docker stop` to stop containers.
* You should be able to describe how network traffic to or from a Docker container is passed to the container by the host
* You should be able to use `-p HOST_PORT:CONTAINER_PORT` to publish a port from the container to the host (and you should understand when you need to)
* You should be able to describe how the overlay filesystem used by Docker works, and how it enables container images to be shared by many instances of a running container
* You should be able to use volumes and bind mounts to make a persistent filesystem available to a container
* You should be able to build a container using a Dockerfile

In this section, we will run *all* commands on the `node1` host we brought up earlier, or inside a container on this host, by copying and pasting into the terminal. (Use SSH to connect to this server.) We won't execute any cells in the *notebook* interface in this section. A comment at the top of each code block will specify where the command should run.


### Install a container engine

First, we need to install the Docker engine. On `node1`, run

```bash
# run on node1 host
sudo apt-get update
sudo apt-get -y install ca-certificates curl

curl -sSL https://get.docker.com/ | sudo sh
```

If we try to use `docker` now, though, we will get an error message:


```
docker: permission denied while trying to connect to the Docker daemon socket at unix:///var/run/docker.sock: Head "http://%2Fvar%2Frun%2Fdocker.sock/_ping": dial unix /var/run/docker.sock: connect: permission denied.
See 'docker run --help'.
```

because before we can run `docker` commands as an unprivileged user, we need to add the user to the `docker` group:

```bash
# run on node1 host
sudo groupadd -f docker; sudo usermod -aG docker $USER
```

then, we need to end the SSH session (`exit`) and open a new one for the change to be reflected. 

After opening a new SSH session, if we run 

```bash
# run on node1 host
id
```

we should see a  group named `docker` listed in the output, indicating that the `cc` user is part of the `docker` group. Now, we can run 

```bash
# run on node1 host
docker run hello-world
```

and we should see a "Hello from Docker!" message.


We are going to practice building a container, but first, we want to understand a bit more about how containers work, and especially, how to share network and filesystem resources between the host and the container in a controlled and secure way.

### Container networking 

Containers need to be able to communicate with other containers and/or the Internet in order to do their jobs. However, we also want to be sure that containers are isolated from each other and from the host - a container should only have access to its own network traffic, and network configurations such as routing rules or firewall rules applied inside a container should not affect the host.

> **Note**: 
> Docker has a few networking "types": `bridge`, `host`, `none`. This section describes `bridge` mode, which is the default.

By default, this is implemented as follows in Docker:

Before any container is started, a `docker0` interface is created on the host. This is a *bridge* network interface, which acts as a virtual switch to connect containers to one another, and to connect containers to the outside world by routing through the host's network interfaces. We can see this interface with

```bash
# run on node1 host
ip addr show docker0
```

Note that the IP address of this interface (`inet`) is specified as `172.17.0.1/16`, which (`172.17.0.1`) is the first address in the private address subnet 172.17.0.1 - 172.17.255.254. 

We can also see Docker-specific settings for this network using 

```bash
# run on node1 host
docker network inspect bridge
```

Docker uses [packet filtering and firewall rules](https://docs.docker.com/engine/network/packet-filtering-firewalls/) on this bridge network to enforce policies that are specified for containers. If we run 

```bash
# run on node1 host
sudo iptables --list -n
sudo iptables --list -n -t nat
```

we will see some firewall "chains" listed: `DOCKER-USER` for user-defined rules, `DOCKER` which applies the port forwarding configuration specified when running a container, and a set of forwarding and bridge-related chains (`DOCKER-FORWARD`, `DOCKER-BRIDGE`, and `DOCKER-CT`) which are used to control and isolate container network traffic.

Once we run a container, 

* A network *namespace* is created for the container. This is a feature of the Linux kernel that provides an independent network stack (including network interfaces, routing tables, firewall rules, etc.). 
* Within the container's network namespace, a new "Ethernet" interface will be created, and will be assigned an address in that same 172.17.0.1 - 172.17.255.254 private address range.
* On the *host*, a virtual Ethernet interface (`veth`) will be created. This is like a virtual "network cable" that connects the container's network namespace to the `docker0` bridge.

Now the container has a complete network stack (provided by its own network namespace) that is isolated from the host network and other containers, but it also has a connection to a bridge via which it can reach the outside world (according to the rules that will be set up by the Docker engine in `iptables`, and routes that are already configured on the host).

The overall networking setup is illustrated as follows:

![Container networking.](images/2-docker-networking.svg)


To see how it all works, we're going to run a container. We will need two SSH sessions on `node1` - 

* in one, we'll inspect the network configuration on the host
* in the second, we'll attach to the container and inspect the network configuration there

Let's get the latest [`alpine` Linux container from the DockerHub registry](https://hub.docker.com/_/alpine):

```bash
# run on node1 host
docker pull alpine
```

If we just run the container with:

```bash
# run on node1 host
docker run alpine
```

nothing much will happen. Unlike a virtual machine, a container does not "live" forever until it is shut down; it "lives" only as long as whatever process we start inside it is still running.

Let's run it with a persistent terminal, so that we can interact with the container:

```bash
# run on node1 host
docker run --name alpine-shell -it --rm alpine
```

 The `-it` flags mean to start the container
 
 * `-i` interactive (so we can type into it), 
 * `-t` with a TTY (a terminal where we can see output of the commands we type)

 and

  * `--name alpine-shell` gives the container a predictable name. (Note the *container name* can be anything we want! If we did not specify a name, a random name would be assigned and we could find out what it is from the `docker ps` output.) 
 * `--rm` removes the container when it stops, so we can re-run this command without cleanup


The terminal prompt will change, indicating that we are now executing commands directly inside the container. Note the `#` at the end of the prompt, which signals that we are running commands as an admin (`root`) user inside the contaier.

On the *host* (not inside the container), run

```bash
# run on node1 host
docker ps
```

to see the details of the running container. Then, still on the *host*, run 


```bash
# run on node1 host
docker network inspect bridge
```

again. Note that now, there is an entry in the "Containers" section, with the details of the container we just started.

Also run 

```bash
# run on node1 host
ip addr
```

on the *host*, and look at the new `veth` interface. In particular, note that

* it says `master docker0` - this means it connected to a "port" on the `docker0` bridge.
* and that it includes a `link-netnsid` field with an integer value (e.g. 0, 1, 2), which indicates the network namespace it connects to.


Now, *on the root shell that is running inside the container*, run 


```bash
# run inside alpine container
ip addr
```

in the container, to see a list of network interfaces and the addresses associated with them.

We should see:

* a loopback interface named `lo`. The loopback interface is used for communication between processes *within* the container using network protocols. 
* an interface typically named `eth0`, which in this case is a virtual Ethernet interface. It has an address in the private address subnet 172.17.0.1 - 172.17.255.254.

Let's test our network connectivity inside the container. In the container, run

```bash
# run inside alpine container
traceroute 1.1.1.1
```

to get a list of "network hops" from the container, to the address `1.1.1.1` (CloudFlare's DNS service on the public Internet). You should see that 

* the first hop is the gateway address on the `docker0` subnet, `172.17.0.1`
* the second hop is a gateway on the `shared1` network on Chameleon
* and from there, we can reach the TACC network and then the Internet.


Inside the container, run

```bash
# run inside alpine container
exit
```

to leave the terminal session.


#### Publishing a port

Now we understand how a container can connect *out* to resources on the Internet, but we need a few more things in place before we can establish a connection *to* a container from the Internet.


We'll run another container:

```bash
# run on node1 host
docker run --name nginx-demo -d --rm nginx:alpine
```

`nginx` is a lightweight web server, and we are running it on top of `alpine` Linux. The image name `nginx:alpine` uses a *tag* (`alpine`) to select a specific variant of the `nginx` image; tags let you choose which version of an image to run.

Also, 

* `--name nginx-demo` gives the container a predictable name. 
* the `-d` says to run the container in "detached" mode (in the background), 
* `--rm` removes it once it stops, 

There should now be a web server running on TCP port 80 (the default HTTP server port) inside the container.

This container image is configured to start a long-lived process (the `nginx` server) when it is run, which is why we don't need an interactive terminal and it doesn't terminate immediately. Run

```bash
# run on node1 host
docker logs nginx-demo
```

to see the output of the long-lived command and confirm it is running.

The `nginx` image is configured to *expose* TCP port 80 outside of itself - if you run 

```bash
# run on node1 host
docker image inspect nginx:alpine
```

on the *host* terminal, you will see this in the "ExposedPorts" section.

On the host terminal, use

```bash
# run on node1 host
docker network inspect bridge
```

to find out the IP address of the `nginx` container (e.g. 172.17.0.2). Finally, you can run


```bash
# run on node1 host
curl http://172.17.0.X/
```

where in place of `X` you substitute the appropriate value for *your* container, to see the home page served by the `nginx` web server in the container. 


However, it's not very useful to serve a web page that is only accessible inside the Docker host! Try putting


```
http://A.B.C.D
```

in the address bar of *your own* browser (on your laptop), substituting the floating IP assigned to the instance. The service will not accept incoming connections, because the Docker container's listening port is not mapped to a listening port on the host.

We're going to want to make this container available on node1's public IP address.

To do this, let's first stop the running container. Run

```bash
# run on node1 host
docker ps
```

to get the details of the container. Then, run

```bash
# run on node1 host
docker stop nginx-demo
```

This stops the `nginx-demo` container we started above. (You can also use a container ID from `docker ps`.)

Now, we'll run our container again, but with the addition of the `-p` argument:

```bash
# run on node1 host
docker run --name nginx-public -d --rm -p 80:80 nginx:alpine
```

which specifies that we want to *publish* the container's port 80 (the second `80` in the argument) to the host port 80 (the first `80` in the argument).

On the host, get the IP address of the host network interface that is on the `sharednet1` network, with


```bash
# run on node1 host
ip addr
```

It will have an address of the form `10.56.X.Y`. Then, run

```bash
# run on node1 host
curl http://10.56.X.Y/
```

(substituting the IP address you found from `ip addr`). Now, the web server is accessible from the host's IP address - not only the container's IP address.

Finally, since we had configured this instance with a floating IP and a security group to allow incoming connections on TCP port 80, we can access this web server from outside the host, too!

In your *own* browser running on your laptop, put the floating IP assigned to your instance in the address bar, as in

```
http://A.B.C.D/
```

You should see the `nginx` welcome page.

This mapping between host port and container port is achieved by a forwarding rule - run

```bash
# run on node1 host
sudo iptables --list -n
sudo iptables --list -n -t nat
```

on the host, and note that the `DOCKER` chain now includes additional rules to handle this mapping.

Stop the running container. Run

```bash
# run on node1 host
docker ps
```

to get the details of the container. Then, run

```bash
# run on node1 host
docker stop nginx-public
```

This stops the `nginx-public` container we started above. (You can also use a container ID from `docker ps`.)


### Container filesystems

To explore the Docker filesystem, it will be helpful to have the `tree` utility, so let's install it:

```bash
# run on node1 host
sudo apt update
sudo apt -y install tree
```

Then, let's get back into our `nginx` container.  First, we'll start the container in detached mode:

```bash
# run on node1 host
docker run --name nginx-1 -d --rm nginx:alpine
```

Then, we'll open a `sh` shell on the container in interactive (TTY) mode using `docker exec`:

```bash
# run on node1 host
docker exec -it nginx-1 /bin/sh
```

If you now run

```bash
# run inside nginx-1 container
df
```

inside the container, you will note that the root of the file tree (`/`) is on an **overlay** file system. The overlay file system is what makes containers so flexible and lightweight! 

A Docker container image is made out of *read-only* image layers.

* there is the base layer, 
* and then there are layers created by the additional instructions used to build the container image, which are stacked on top of the base layer.

Because these layers are read-only, they can be re-used - if I spin up another instance of the same container, for example, I don't have to worry that these layers have been modified by the previous instance.

Then, when you create a container from an image, Docker adds a *read-write* layer, which is called a container layer, on top of those image layers. You can create or edit files inside the Docker container. (Changes are made to files in a kind of staging area called the "workdir", then they are copied to the container layer.) But, your changes are temporary - they last only as long as the container is running. 

From the point of view of processes running inside the Docker container, the filesystem looks like a "merged" version of the image layers and the container layer.

The overall setup is illustrated as follows:

![Container filesystems.](images/2-docker-overlayfs.svg)


Let's look at these layers. 

First, let's look at what is inside the filesystem from the container's perspective:

```bash
# run inside nginx-1 container
ls
```

Then, from *outside* the container, we will see how this filesystem is realized. On the *host* (not inside the container), first get the container ID:

```bash
# run on node1 host
CID=$(docker inspect -f '{{.Id}}' nginx-1)
echo "$CID"
```

and use it to locate the container's filesystem:

```bash
# run on node1 host
sudo ctr -n moby snapshots ls | grep "$CID"
```

You will see

* an entry with `KIND` set to `Active` - this represents the container’s writable filesystem and, when mounted, shows the "merged" view
* and an entry with `KIND` set to `Committed` - this is the read-only snapshot.

We'll dig a little deeper. Let's save paths in Bash variables corresponding to the "upperdir" and "lowerdir", to make them easier to use:

```bash
# run on node1 host
sudo mkdir -p /tmp/ctr-tmp
MOUNT_OUT=$(sudo ctr -n moby snapshots mount /tmp/ctr-tmp "$CID" 2>&1)
UPPERDIR=$(echo "$MOUNT_OUT" | sed -n 's/.*upperdir=\([^,]*\).*/\1/p')
LOWERDIRS=($(echo "$MOUNT_OUT" | sed -n 's/.*lowerdir=\([^,]*\).*/\1/p' | tr ':' ' '))
sudo umount /tmp/ctr-tmp 2>/dev/null || true
```

and a Bash variable corresponding to the "merged" view:

```bash
# run on node1 host
PID=$(docker inspect -f '{{.State.Pid}}' nginx-1)
MERGED=/proc/$PID/root
```

Now the variable `UPPERDIR` points to the writable container layer:

```bash
# run on node1 host
echo $UPPERDIR
```

and the array `LOWERDIRS` contains one entry per read-only image layer:

```bash
# run on node1 host
printf 'LOWERDIR=%s\n' "${LOWERDIRS[@]}"
```

If we further explore these directories with `ls` and `cat`, it will become clear how these layers represent the changes made to the container image by the commands described in [the file used to build the image](https://github.com/nginxinc/docker-nginx/blob/master/Dockerfile-alpine-slim.template).

Currently, the "upperdir" has any files created or edited in the container layer, with updated files in the container layer replacing their original version in the image layer. You can see the contents of the "upperdir" as a tree by running:

```bash
# run on node1 host
sudo tree $UPPERDIR
```

(This layer currently has files that are edited or created automatically when the `nginx` process started at the beginning of the container's lifetime.)

You can see the same list of files as a "diff" - try

```bash
# run on node1 host
docker diff nginx-1
```

Note that most of the files visible in the container (we saw the root of the filesystem with `ls` earlier) are *not* in the "upperdir", they are served from the "lowerdir" because they have not been modified.

Let's edit a file in the container layer to see how the overlay filesystem works! Inside the container, run

```bash
# run inside nginx-1 container
vi /usr/share/nginx/html/index.html
```

(If you haven't used `vi` before, follow these instructions very carefully - some of the keystrokes mentioned are commands that control the behavior of the editor, not text that appears in the output, which can be confusing if you are not used to it.) Use the arrow keys on your keyboard to navigate to the line that says

```
<h1>Welcome to nginx!</h1>
```

and to position your cursor right before the `!`. Then, type `i` to change from command mode to insert mode. Use the backspace key to erase `nginx` and replace it with `ECE-GY 9183`, so it says: `Welcome to ECE-GY 9183!`. Use the `Esc` key to get back to command mode, and type `:wq`, then hit Enter, to save and close the editor.

To test your work, on the *host*, get the IP address of the container with

```bash
# run on node1 host
docker inspect nginx-1
```

and then use 

```bash
# run on node1 host
curl http://172.17.0.X/
```

(substituting the actual IP address) to view the page and confirm that it now says "Welcome to ECE-GY 9183!".

Now, let's see the effect of this change in the filesystem.  First, we will look at the same file in the (read-only) image layers:

```bash
# run on node1 host
for dir in "${LOWERDIRS[@]}"; do
    FILE="$dir/usr/share/nginx/html/index.html"
    sudo bash -c "[ -f '$FILE' ] && echo \"$dir:\" && cat '$FILE'"
done
```

In the (writeable) container layer, though, this same file has been modified. Note that the file now appears in

```bash
# run on node1 host
sudo tree $UPPERDIR
```

and in 

```bash
# run on node1 host
docker diff nginx-1
```

and we can see from the file contents in the (writeable) container layer that it reflects the changes we have made:


```bash
# run on node1 host
sudo cat "$UPPERDIR/usr/share/nginx/html/index.html"
```

Finally, we note that in the "merged" directory (which is what processes inside the container will see!) we see the updated version of this file.


```bash
# run on node1 host
sudo cat "$MERGED/usr/share/nginx/html/index.html"
```


Now, we're going to run a second instance of the `nginx` container! On the host, run

```bash
# run on node1 host
docker run --name nginx-2 -d --rm nginx:alpine
```

and then 

```bash
# run on node1 host
{% raw %}
CID2=$(docker inspect -f '{{.Id}}' nginx-2)
{% endraw %}
sudo ctr -n moby snapshots ls | grep "$CID2"
```

Then run

```bash
# run on node1 host
sudo mkdir -p /tmp/ctr-tmp
MOUNT_OUT2=$(sudo ctr -n moby snapshots mount /tmp/ctr-tmp "$CID2" 2>&1)
UPPERDIR2=$(echo "$MOUNT_OUT2" | sed -n 's/.*upperdir=\([^,]*\).*/\1/p')
LOWERDIRS2=($(echo "$MOUNT_OUT2" | sed -n 's/.*lowerdir=\([^,]*\).*/\1/p' | tr ':' ' '))
sudo umount /tmp/ctr-tmp 2>/dev/null || true
```

to get the "upperdir" and "lowerdir" for this container.

If you compare the "lowerdir" layers for the first and second container:

```bash
# run on node1 host
printf 'LOWERDIR=%s\n' "${LOWERDIRS[@]}"
```

```bash
# run on node1 host
printf 'LOWERDIR2=%s\n' "${LOWERDIRS2[@]}"
```

You will notice that except for the top layer, which is not strictly part of the image, the second instance of the container has exactly the same file paths for the "lowerdir" (read-only image layers) - in other words, there is a single copy of the image layers that is used by *all* instances of this container. 

However, it has its own separate "upperdir" container layer, since the container may write to these.

```bash
# run on node1 host
echo $UPPERDIR
```

```bash
# run on node1 host
echo $UPPERDIR2
```

Stop both running containers:

```bash
# run on node1 host
docker stop nginx-1
docker stop nginx-2
```

#### Volume mounts

With the overlay filesystem, a single copy of the container image on disk can be shared by *all* container instances using that image. Each container instance only needs to maintain its own local changes, in the container layer.

Sometimes, we may want to *persist* some files beyond the lifetime of the container. For persistent storage, we can create a [volume](https://docs.docker.com/engine/storage/volumes/) in Docker and attach it to a container.

Let's create a volume now. We will use this volume to store HTML files for our `nginx` web site:

```bash
# run on node1 host
docker volume create webvol
```

Now, let us run the `nginx` container, and we will mount the `webvol` volume at `/usr/share/nginx/html` inside the container filesystem:

```bash
# run on node1 host
docker run --name nginx-vol -d --rm -v webvol:/usr/share/nginx/html -p 80:80 nginx:alpine
```

Since the `/usr/share/nginx/html` directory in the container already contains files (these are created automatically by the `nginx` installation), they will be copied to the volume. If we visit our web service using a browser, we will see the "Welcome to nginx" message on the home page.


Let us edit the home page. Run an `alpine` Linux container and mount this volume to the position `/data/web`, using the `-v` argument:


```bash
# run on node1 host
docker run --rm -it -v webvol:/data/web alpine
```

*Inside* the container, we can edit the HTML files in the `/data/web` directory

```bash
# run inside alpine container
cd /data/web
vi index.html
```

Use the arrow keys on your keyboard to navigate to the line that says

```
<h1>Welcome to nginx!</h1>
```

and to position your cursor right before the `!`. Then, type `i` to change from command mode to insert mode. Use the backspace key to erase `nginx` and replace it with `docker volumes`.  Use the `Esc` key to get back to command mode, and type `:wq`, then hit Enter, to save and close the editor. Then, you can type

```bash
# run inside alpine container
exit
```

inside the container, to close the terminal session on the `alpine` container.

Now, visit the web service using a browser, and we will see the "Welcome to nginx" message has changed to a "Welcome to docker volumes" message.

Furthermore, the data in the volume persists across containers and container instances. To verify this:

* Use `docker ps` and `docker stop` on the host to stop all running containers. (You can also use `docker container prune` to completely remove all stopped containers.)
* Then, start the `nginx` container again with the volume mounted, and check the home page of the web service.



#### Bind mounts

While volumes make persistent data available to containers, the data inside the volumes is not easily accessible from the host operating system. For some use cases, we may want to create or modify data inside a container, and then have that data also be available to the host (or vice versa).

Try running your `nginx` container, but attach the `/usr/share/nginx/html` directory in the container to the `~/data` directory

```bash
# run on node1 host
docker run --name nginx-bind -d --rm -v ~/data/web:/usr/share/nginx/html -p 80:80 nginx:alpine
```

Then, on the host, create a new HTML file inside `~/data/web`:

```bash
# run on node1 host
sudo vim ~/data/web/index.html
```

Type `i` to change from command mode to insert mode. Then, paste the HTML below:


```html
<!DOCTYPE html>
<html lang="en">
  <head>
    <meta charset="UTF-8">
    <title>Hello world</title>
  </head>
  <body>
    <p>Hello bind mounts</p>
  </body>
</html>
```

Use the `Esc` key to get back to command mode, and type `:wq`, then hit Enter, to save and close the editor. 

Now, visit the web service using a browser, and we will see HTML file we just created.  Furthermore, the data persists across containers and container instances. To verify this:

* Use `docker ps` and `docker stop` on the host to stop the running container. (You can also use `docker container prune` to completely remove all stopped containers.)
* Then, start the `nginx` container again with the volume mounted, and check the home page of the web service.

Also note that we can edit the data in `~/data/web/` from the host even when no container is attached to it.

Use `docker ps` and `docker stop` on the host to stop all running containers before you move on to the next section.

### Build and serve a container for a machine learning model


Finally, we're going to build our own container, and use it to serve a machine learning model!

The premise of this service is as follows: You are working at a machine learning engineer at a small startup company called GourmetGram. They are developing an online photo sharing community focused on food. You are testing a new model you have developed that automatically classifies photos of food into one of a set of categories: Bread, Dairy product, Dessert, Egg, Fried food, Meat, Noodles/Pasta, Rice, Seafood, Soup, and Vegetable/Fruit. You have built a simple web application with which to test your model and get feedback from others.

The source code for your web application is at: [https://github.com/teaching-on-testbeds/gourmetgram](https://github.com/teaching-on-testbeds/gourmetgram). Retrieve it on node1 with

```bash
# run on node1 host
git clone https://github.com/teaching-on-testbeds/gourmetgram gourmetgram
```

The repository includes the following materials:

```
  -   instance/
  -   static/
  -   templates/
  -   food11.pth
  -   app.py
  -   requirements.txt
  -   Dockerfile
```

where

* `static` and `templates` are directories containing the HTML, CSS, and JS materials to implement the front end
* `food11.pth` is a Pytorch model,
* `app.py` implements a web application in Flask serving this model, 
* `requirements.txt` specifies the Python libraries required, 
* and `Dockerfile` is a set of instructions for building a container image. 

We can take a closer look at the `Dockerfile` to see how the container image will be built. It is based on a Python image; then it installs Python libraries, copies the contents of the repository into the working directory, exposes port 8000 on the container, and then runs the Python application (which will listen for incoming connections on port 8000).

```
# Use an official Python runtime as a parent image
FROM python:3.11-slim-buster

# Set the working directory to /app
WORKDIR /app

# Copy the requirements.txt into the container at /app
# we do this separately so that the "expensive" build step (pip install)
# does not need to be repeated if other files in /app change.
COPY requirements.txt /app

# Install any needed packages specified in requirements.txt
RUN pip install --trusted-host pypi.python.org -r requirements.txt

# Copy the current directory contents into the container at /app
COPY . /app

# Expose the port on which the app will run
EXPOSE 8000

# Run the command to start the Flask server
CMD ["python","app.py"]
```

We can use this file to build a container image as follows: we run


```bash
# run on node1 host
docker build -t gourmetgram-app:0.0.1 gourmetgram
```

which builds the image from the directory `gourmetgram`, gives the image the name `gourmetgram-app`, and gives it the tag `0.0.1` (typically this is a version number).

Now, we can run the container with

```bash
# run on node1 host
docker run --name gourmetgram-app -d --rm -p 80:8000 gourmetgram-app:0.0.1
```

Put

```
http://A.B.C.D
```

in the address bar of *your own* browser (on your laptop), substituting the floating IP assigned to the instance. Try uploading an image of a food item to the service, and see what "tag" is assigned by the model.


Now that we have a basic deployment, in the next section we will scale it up using Kubernetes.
