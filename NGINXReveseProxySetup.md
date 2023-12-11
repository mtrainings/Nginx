# NGINX Revese Proxy Setup

**Practice Lab:** Nginx Reverse Proxy Configuration

## Objective

Configure Nginx as a reverse proxy to forward requests to backend servers for enhanced load balancing and security.

## Steps

1. **Install Nginx:**
   - If you haven't installed Nginx, do so based on your operating system. For example:
     - Ubuntu/Debian: `sudo apt-get install nginx`
     - CentOS: `sudo yum install nginx`

2. **Set Up Backend Servers:**

     ```bash
     sudo apt-get install docker.io -y
     docker run -d --rm --name web-test -p 8080:8000 crccheck/hello-world
     ```

3. **Configure Nginx as a Reverse Proxy:**
   - Open the Nginx default configuration file for editing.

     ```bash
     sudo nano /etc/nginx/nginx.conf
     ```

   - Add server blocks for the reverse proxy configuration.

     ```nginx
     server {
         listen 80;
         server_name example-domain.com;

         location / {
             proxy_pass http://127.0.0.1:8080;
             proxy_set_header Host $host;
             proxy_set_header X-Real-IP $remote_addr;
             proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
             proxy_set_header X-Forwarded-Proto $scheme;
         }
     }
     ```

4. **Test Configuration:**
   - Test the Nginx configuration to ensure there are no syntax errors.

     ```bash
     echo "127.0.0.1 example-domain.com" | sudo tee /etc/hosts
     sudo nginx -t
     ```

5. **Reload Nginx:**
   - If the test is successful, reload Nginx to apply the changes.

     ```bash
     sudo systemctl reload nginx
     ```

6. **Verify Reverse Proxy:**
   - Open a web browser and navigate to `example-domain.com`. Requests should be forwarded to the backend server.

## Conclusion

This lab guides you through configuring Nginx as a reverse proxy to forward requests to backend servers. It includes setting up backend servers, configuring Nginx as a reverse proxy, testing the configuration, and exploring additional proxy directives for advanced features.
