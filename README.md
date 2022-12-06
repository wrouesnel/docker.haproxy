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

Available on gchr:
```
docker pull ghcr.io/wrouesnel/haproxy
```

This container is designed to be dynamically reconfigured. It exposes
a simple REST API which manages the HAproxy configurations. Optionally
the config can be persisted by mounting the `/data` directory to a
persistent store to allow it to reset on launch.

### Stateless Configuration

If you want to use a stateless, declarative configuration then the application also can read a directory
of configuration items (consistent with a Kubernetes config map being mounted) to set endpoints. The directory
should be a simple flat directory of JSON files which contain the configuration items (see below).

By default this directory should be mounted at `/config`.

```json
{ 
   "host" : "a-frontend-domain", 
   "http_port" : "88", 
   "https_port" : "444", 
   "dest" : "a-backend-domain"  
}
```

Note in the example above http and https ports are 88 and 444. This is because this server is behind a NAT and uses
these to advertise its external services.

Usages are:

* `host`: the frontend hostname. This value is expected to be sent as the SNI name.
* `http_port`: the port on the `dest` server to send HTTP traffic too.
* `https_port`: the port on the `dest` server to send HTTPS traffic too.
* `dest`: the backend server, specified by either DNS or IP address. You will frequently use DNS name when running with
   proxychains enabled for an outbound proxy server.

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

* `ADMIN_PASSWORD` - password to protect the forwarder endpoint with.

* `WEBUI_SSL_SERVER_CERT` - Web UI SSL public cert. Can be filepaths in the container, literal PEM       certificates or blank. Blank causes the container to automatically generate certificates on 
  first run.

* `WEBUI_SSL_SERVER_KEY` - Web UI SSL private key. Can be filepaths in the container, literal PEM       certificates or blank. Blank causes the container to automatically generate certificates on 
   first run.

* `PLATFORM_TLS_TRUST_CERTIFICATES` if set, overrides the built-in list of public certificate roots.
  Good for dealing with corporate firewalls or secure environments (a privately deployed container
  shouldn't ever need to trust public certs on the internet for example).

* `HTTP_PORT=80` port on which to serve the HTTP router.

* `HTTPS_PORT=443` port on which to serve the SNI HTTPS router.

* `ADMIN_HTTPS_PORT=8443` port on which to serve the admin interface.

# Proxychains-ng
In certain circumstances you may need to run an HAProxy which contacts hosts behind
a regular HTTP forward proxy. This is not supported in haproxy out of the box but
can be accomplished with proxychans.

proxychains-ng is configured with the following environment variables. As with the
others above, `CONFIG_DISABLE` prevents overwriting templated files.

 * `PROXYCHAIN`
    Default none. If set to `yes` then squid will be launched with proxychains.
    You should specify some proxies when doing this.
 * `PROXYCHAIN_PROXYx`
    Upstream proxies to be passed to the proxy chan config file. The suffix (`x`)
    determines the order in which they are templated into the configuration file.
    The format is a space separated string like "http 127.0.0.1 3129"
 * `PROXYCHAIN_TYPE`
    Default `strict_chain`. Can be `strict_chain` or `dynamic_chain` sensibly
    within this image. In `strict_chain` mode, all proxies must be up. In
    `dynamic_chain` mode proxies are used in order, but skipped if down.
    Disable configuration and bind a configuration file to /etc/proxychains.conf
    if you need more flexibility.
 * `PROXYCHAIN_DNS`
   Default none. When set to `yes`, turns on the `proxy_dns` option for Proxychains.