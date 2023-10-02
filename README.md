# About

This is a terraform module that provisions an haproxy load balancer for a patroni cluster on openstack.

It is dependent on a dns server to resolve member of the patroni cluster.

Also, while it doesn't handle tls termination for postgres traffic, it requires valid client tls credentials to perform health checks on the patroni api to determine the master.

# Usage

## Variables

This module takes the following variables as input:

- **name**: Name to give to the vm. Will be the hostname as well.
- **image_source**: Source of the image to provision the load balancer on. It takes the following keys (only one of the two fields should be used, the other one should be empty):
  - **image_id**: Id of the image to associate with a vm that has local storage
  - **volume_id**: Id of a volume containing the os to associate with the vm
- **flavor_id**: Id of the vm flavor to assign to the instance. 
- **network_port**: Resource of type **openstack_networking_port_v2** to assign to the vm for network connectivity
- **server_group**: Server group to assign to the node. Should be of type **openstack_compute_servergroup_v2**.
- **keypair_name**: Name of the ssh keypair that will be used to ssh against the vm.
- **haproxy**: Haproxy configuration. Takes the following keys:
  - **postgres_nodes_max_count**: Maximum expected number of postgres nodes
  - **postgres_nameserver_ips**: List of nameserver ips that will resolve the domain name of the postgres nodes.
  - **postgres_domain**: Domain name that will resolve to the postgres nodes.
  - **patroni_client**: Tls client certificate credentials that haproxy will use to authentication against the patroni api. Takes the following keys:
    - **ca_certificate**: CA certificate that patroni will use to authentify the patroni servers.
    - **client_key**: Private key used to sign the client certificate
    - **client_certificate**: Client certificate haproxy will use to authentify itself to patroni for health checks
  - **timeouts**: Various timeouts for haproxy. It has the following keys:
    - **connect**: Timeout to establish a new connection
    - **check**: Timeout on the checks that determine which patroni node is master
    - **idle**: Timeout on iddle connections, either between haproxy and the client or between haproxy and a postgres backend
- **chrony**: Optional chrony configuration for when you need a more fine-grained ntp setup on your vm. It is an object with the following fields:
  - **enabled**: If set the false (the default), chrony will not be installed and the vm ntp settings will be left to default.
  - **servers**: List of ntp servers to sync from with each entry containing two properties, **url** and **options** (see: https://chrony.tuxfamily.org/doc/4.2/chrony.conf.html#server)
  - **pools**: A list of ntp server pools to sync from with each entry containing two properties, **url** and **options** (see: https://chrony.tuxfamily.org/doc/4.2/chrony.conf.html#pool)
  - **makestep**: An object containing remedial instructions if the clock of the vm is significantly out of sync at startup. It is an object containing two properties, **threshold** and **limit** (see: https://chrony.tuxfamily.org/doc/4.2/chrony.conf.html#makestep)
- **fluentd**: Optional fluend configuration to securely route logs to a fluend node using the forward plugin. It has the following keys:
  - **enabled**: If set the false (the default), fluentd will not be installed.
  - **load_balancer_tag**: Tag to assign to logs coming from haproxy
  - **node_exporter_tag** Tag to assign to logs coming from the prometheus node exporter
  - **forward**: Configuration for the forward plugin that will talk to the external fluend node. It has the following keys:
    - **domain**: Ip or domain name of the remote fluend node.
    - **port**: Port the remote fluend node listens on
    - **hostname**: Unique hostname identifier for the vm
    - **shared_key**: Secret shared key with the remote fluentd node to authentify the client
    - **ca_cert**: CA certificate that signed the remote fluentd node's server certificate (used to authentify it)
  - **buffer**: Configuration for the buffering of outgoing fluentd traffic
    - **customized**: Set to false to use the default buffering configurations. If you wish to customize it, set this to true.
    - **custom_value**: Custom buffering configuration to provide that will override the default one. Should be valid fluentd configuration syntax, including the opening and closing ```<buffer>``` tags.
- **container_registry**: Parameters to get haproxy image from a custom container registry with username/password authentication. It has the following parameters:
  - **url**: Url of the registry (with the http protocol)
  - **username**: Username you want to connect to the registry as
  - **password**: Password of the user
- **install_dependencies**: Whether cloud-init should install external dependencies (should be set to false if you already provide an image with the external dependencies built-in).