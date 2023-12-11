# NGINX Load Balancers

#### Objective

Set up load balancing with NGINX to distribute incoming traffic among multiple servers for improved performance and high availability.

## Steps

1. **Install Nginx:**
   - If you haven't installed Nginx, do so based on your operating system. For example:
     - Ubuntu/Debian: `sudo apt-get install nginx`
     - CentOS: `sudo yum install nginx`

2. **Configure Application Servers:**
   - Set up your application on three backend servers.

     ```bash
     sudo apt-get install docker.io -y
     docker run -d --rm --name web-test-01 -p 8081:8000 crccheck/hello-world
     docker run -d --rm --name web-test-02 -p 8082:8000 crccheck/hello-world
     docker run -d --rm --name web-test-03 -p 8083:8000 crccheck/hello-world
     ```

   - Repeat for app_server2 and app_server3.

3. **Configure NGINX Load Balancer:**
   - On the NGINX load balancer server, configure NGINX to act as a load balancer.
   - Example NGINX configuration:

     ```nginx
     http {
         upstream backend_servers {
             server 127.0.0.1:8081;
             server 127.0.0.1:8082;
             server 127.0.0.1:8083;
             # Add more servers as needed...
         }

         server {
             listen 80;
             location / {
                 proxy_pass http://backend_servers;
                 # Additional configuration...
             }
         }
     }
     ```

4. **Load Balancing Algorithms:**
   - Choose a load balancing algorithm based on your requirements.
   - Example: Round Robin

     ```nginx
     http {
         upstream backend_servers {
             round-robin;
             server 127.0.0.1:8081;
             server 127.0.0.1:8082;
             server 127.0.0.1:8083;
             # Add more servers as needed...
         }

         server {
             listen 80;
             location / {
                 proxy_pass http://backend_servers;
                 # Additional configuration...
             }
         }
     }
     ```

5. **Health Checks (Optional):**
   - Implement health checks to ensure servers are available.
   - Example:

     ```nginx
     http {
         upstream backend_servers {
             server 127.0.0.1:8081;
             server 127.0.0.1:8082;
             server 127.0.0.1:8083;

             health_check;
             # Add more servers as needed...
         }

         server {
             listen 80;
             location / {
                 proxy_pass http://backend_servers;
                 # Additional configuration...
             }
         }
     }
     ```

6. **Testing:**
   - Access your application through the NGINX load balancer URL.
   - Monitor NGINX logs for distribution and check backend server logs for incoming requests.

## Conclusion

This practice lab provides a basic setup for load balancing with NGINX. Explore additional load balancing algorithms, SSL termination, and health check configurations for a comprehensive understanding.
