# NGINX As CDN

#### Objective

Set up a simple CDN using NGINX to improve content delivery and reduce latency.

## Steps

1. **Install Nginx:**
   - If you haven't installed Nginx, do so based on your operating system. For example:
     - Ubuntu/Debian: `sudo apt-get install nginx`
     - CentOS: `sudo yum install nginx`

2. **Configure Origin Server:**
   - Configure the origin server to serve content.

     ```bash
     sudo apt-get install docker.io -y
     mkdir -p /var/lib/nginx/tmp/proxy/cdn.example.com
     docker run -d --rm --name web-test-01 -p 8081:80 mcr.microsoft.com/azuredocs/aks-helloworld:v1
     docker run -d --rm --name web-test-02 -p 8082:80 mcr.microsoft.com/azuredocs/aks-helloworld:v1
     docker run -d --rm --name web-test-03 -p 8083:80 mcr.microsoft.com/azuredocs/aks-helloworld:v1
     ```

3. **Configure CDN Server:**
   - Back up the nginx configuration

   ```bash
   mv /etc/nginx/nginx.conf /etc/nginx/nginx.conf.backup
   ```

   - Create a new NGINX configuration file and use below configuration

   ```nginx
    user www-data;
    worker_processes auto;
    worker_rlimit_nofile 4096;
    pid /run/nginx.pid;

    events {
        worker_connections  4096;
        # multi_accept on;
    }

    http {
        # Basic Setings
        include mime.types;
        default_type application/octet-stream;
        sendfile on;
        tcp_nopush on;
        tcp_nodelay on;
        server_tokens off;
        keepalive_timeout 65;

        # Log Settings
        log_format cache_log '$remote_addr - $remote_user [$time_local] "$request" '
                            '$status $body_bytes_sent "$http_referer" '
                            '"$http_user_agent" "$http_x_forwarded_for" '
                            'rt=$request_time '
                            'ua="$upstream_addr" us="$upstream_status" '
                            'ut="$upstream_response_time" ul="$upstream_response_length" '
                            'cs=$upstream_cache_status';
        access_log /var/log/nginx/cdn-access.log cache_log;

        # SSL Settings if needed
        # ssl_protocols TLSv1.2 TLSv1.1 TLSv1;
        # ssl_prefer_server_ciphers on;
        # ssl_ciphers 'kEECDH+ECDSA+AES128 kEECDH+ECDSA+AES256 kEECDH+AES128 kEECDH+AES256 kEDH+AES128 kEDH+AES256 DES-CBC3-SHA +SHA !aNULL !eNULL !LOW !kECDH !DSS !MD5 !RC4 !EXP !PSK !SRP !CAMELLIA !SEED';
        # add_header Strict-Transport-Security "max-age=31536000; preload" always;
        # ssl_session_cache shared:SSL:10m;
        # ssl_session_timeout 20m;
        # ssl_certificate /etc/ssl/cert_file.crt;
        # ssl_certificate_key /etc/ssl/key_file.key;
        # ssl_dhparam /etc/ssl/dhparam_file.pem;

        # Core Cache Setting
        proxy_cache_key $uri;
        proxy_cache_path /etc/nginx/cache levels=1:2 keys_zone=my_cache:10m max_size=10g
                        inactive=30d use_temp_path=off;

        # Load Balancing Configuration
        upstream backend_server {
            server 127.0.0.1:8081;
            server 127.0.0.1:8082;
            server 127.0.0.1:8083;
            # Add more backend servers as needed
        }

        # Server For Caching
        server {
            listen 80; # or use 443 if you use SSL
            server_name cdn.example.com;

            location / {
                # cache path
                proxy_cache my_cache;

                # server resends file only if the file changed
                proxy_cache_revalidate on;

                # use stale cache when updating on background
                proxy_cache_background_update on;
                proxy_cache_use_stale updating;

                # Only 1 request gets to the origin at a time
                proxy_cache_lock on;

                # Set caching time to any HTTP response
                proxy_cache_valid 200 7d;

                # ignore request header
                proxy_ignore_headers Cache-Control;
                proxy_ignore_headers Set-Cookie;
                proxy_ignore_headers Expires;

                # addcache status header
                add_header X-Cache-Status $upstream_cache_status;

                # Using HTTP 1.1 protocol
                proxy_http_version 1.1;
                proxy_set_header Conenction "";

                proxy_set_header Host $host;
                proxy_pass http://backend_server;
            }
        }
        
    }
   ```

4. **Testing:**
   - Add entry into hosts file and restart nginx

     ```bash
     echo "127.0.0.1 cdn.example.com" | sudo tee /etc/hosts
     sudo nginx -t
     sudo systemctl reload nginx
     ```

   - Access your content through the CDN URLs (cdn.example.com).
   - Use browser developer tools or online tools to confirm CDN usage.

5. **Cleanup:**

- Remove added configuration from point `3`.