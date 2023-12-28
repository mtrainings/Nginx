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
     docker run -d --rm --name web-test-01 -p 8081:8000 crccheck/hello-world
     docker run -d --rm --name web-test-02 -p 8082:8000 crccheck/hello-world
     docker run -d --rm --name web-test-03 -p 8083:8000 crccheck/hello-world
     ```

3. **Configure CDN Server:**
   - On each CDN server, configure NGINX as a reverse proxy to the origin server.
   - Example NGINX configuration:

     ```nginx

    http {
        # CDN Configuration
        proxy_cache_path /var/lib/nginx/tmp/proxy/cdn.example.com levels=1:2 keys_zone=my_cache:20m inactive=720h max_size=10g;
        server {
            listen 80;
            server_name cdn.example.com;

        location / {
            proxy_pass http://backend_server;
            proxy_set_header Host $host;
            proxy_set_header  True-Client-IP  $remote_addr;
            }
            # Cache all static files, errors as well!
            location ~* .(jpg|png|gif|jpeg|webp|css|mp3|wav|swf|mov|doc|pdf|xls|ppt|docx|pptx|xlsx)$ {

                proxy_cache_key         "$scheme$host$request_uri";
                proxy_cache_revalidate on;
                proxy_cache_valid   200 301  7d;
                proxy_cache_valid   302      10s;
                proxy_cache_min_uses  2;
                proxy_cache_use_stale error timeout invalid_header http_500 http_502 http_503;
                proxy_ignore_headers Cache-Control;
                proxy_ignore_headers Expires;
                proxy_cache_valid any 30m;
                proxy_set_header Host $host;
                proxy_set_header  True-Client-IP  $remote_addr;
                proxy_cache my_cache;
                }            
        }
        # Load Balancing Configuration
        upstream backend_server {
            server 127.0.0.1:8081;
            server 127.0.0.1:8082;
            server 127.0.0.1:8083;
            # Add more backend servers as needed
        }
    }
     ```

4. **Testing:**
   - Access your content through the CDN URLs (cdn1.yourdomain.com, cdn2.yourdomain.com).
   - Use browser developer tools or online tools to confirm CDN usage and improved load times.

     ```
     echo "127.0.0.1 cdn.example.com" | sudo tee /etc/hosts
     sudo nginx -t
     sudo systemctl restart nginx
     ```

## Conclusion

This practice lab provides a basic setup for a CDN using NGINX. Explore additional features like SSL termination, cache purging, and security measures to enhance your CDN configuration.
