# NGINX Configure Multiple Websites

**Practice Lab:** Nginx Multiple Websites Configuration

## Objective

Configure Nginx to host multiple websites on a single server, each with its own domain.

## Steps

1. **Install Nginx:**
   - If you haven't installed Nginx, do so based on your operating system. For example:
     - Ubuntu/Debian: `sudo apt-get install nginx -y`
     - CentOS: `sudo yum install nginx`

2. **Create Website Directories:**
   - Create directories to store the content for each website.

     ```bash
     sudo mkdir -p /var/www/site1
     sudo mkdir -p /var/www/site2
     ```

3. **Create Sample Index Files:**
   - Create sample `index.html` files for each website.

     ```bash
     echo "Welcome to Site 1" | sudo tee /var/www/site1/index.html
     echo "Welcome to Site 2" | sudo tee /var/www/site2/index.html
     ```

4. **Configure Nginx for Multiple Websites:**
   - Open the Nginx default configuration file for editing.

     ```bash
     sudo nano /etc/nginx/nginx.conf
     ```

   - Add server blocks for each website inside the `http` block.

     ```nginx
     server {
         listen 80;
         server_name site1.com www.site1.com;

         location / {
             root /var/www/site1;
             index index.html;
         }
     }

     server {
         listen 80;
         server_name site2.com www.site2.com;

         location / {
             root /var/www/site2;
             index index.html;
         }
     }
     ```

5. **Save and Close:**
   - Save the configuration file and close the text editor.

6. **Test Configuration:**
   - Test the Nginx configuration to ensure there are no syntax errors.

     ```bash
     echo "127.0.0.1 site1.com site2.com" | sudo tee /etc/hosts
     sudo nginx -t
     ```

7. **Reload Nginx:**
   - If the test is successful, reload Nginx to apply the changes.

     ```bash
     sudo systemctl reload nginx
     ```

8. **Verify Websites:**

- Open a web browser and navigate to `site1.com` and `site2.com`. You should see the respective "Welcome" messages.

## Conclusion

This lab guides you through configuring Nginx to host multiple websites on a single server. Each website is assigned its own domain, and Nginx is configured with separate server blocks to handle the traffic for each site.
