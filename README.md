# docker.haproxy

A docker container for running HAproxy as a dynamic SNI redirector.

SNI redirection allows routing TLS traffic through HAproxy without
needing to terminate the TLS traffic. This allows multiple secure
streams behind the server. 

It does not mean you are secure from the server though - any provider of 
SNI-based tunneling could just as easily acquire a LetsEncrypt certificate 
using your domain name and look perfectly legitimate to incoming traffic
while MITM'ing you.

It is however a very convenient way to avoid having to manage certificates
for downstream servers.

## Usage

This container is designed to be dynamically reconfigured. It exposes
a simple REST API which manages the HAproxy configurations. Optionally
the config can be persisted by mounting the `/data` directory to a
persistent store to allow it to reset on launch.

## Endpoints

Control endpoints and metrics are implemented on port 8443 and by default
are password protected and served via TLS.

`:8443/api/v1/forwarder` implements webhooks for updating backend server
configuration. This endpoint is protected by the password specified for `ADMIN_PASSWORD`
and the username specified as `ADMIN_USER`.

```
curl -X POST \
    -H "Content-Type: application/json" \
    -d '{ "host" : "a-frontend-domain", "http_port" : "88", "https_port" : "444", "dest" : "a-backend-domain"  }'  https://my-gateway-server:8443/api/v1/forwarder
```

`:8443/metrics` serves Prometheus metrics for the container.

## Environment Variables

* `CORE_COUNT` - number of cores to use on the machine for HAproxy.

* `HOSTNAME` - hostname to set inside the container. Affects self-signed certificate generation.

* `ADMIN_AUTH` - default `yes` - enables HTTP basic auth on the `/api/v1/forwarder` endpoint on port
  `8443`.

* `WEBUI_SSL_SERVER_CERT` - Web UI SSL public cert. Can be filepaths in the container, literal PEM       certificates or blank. Blank causes the container to automatically generate certificates on 
  first run.

* `WEBUI_SSL_SERVER_CERT` - Web UI SSL private key. Can be filepaths in the container, literal PEM       certificates or blank. Blank causes the container to automatically generate certificates on 
   first run.

* `PLATFORM_TLS_TRUST_CERTIFICATES` if set, overrides the built-in list of public certificate roots.
  Good for dealing with corporate firewalls or secure environments (a privately deployed container
  shouldn't ever need to trust public certs on the internet for example).