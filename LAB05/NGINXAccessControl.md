# NGINX Access Control

#### Practice Lab: Nginx Access List with Basic Authentication

## Objective

Configure Nginx to restrict access to a specific location using both access lists and Basic Authentication.

## Steps

1. **Install Nginx:**
   - If you haven't installed Nginx, do so based on your operating system. For example:
     - Ubuntu/Debian: `sudo apt-get install nginx`
     - CentOS: `sudo yum install nginx`

2. **Install `apache2-utils` package:**
   - The `htpasswd` utility is part of the `apache2-utils` package. Install it using:
     - Ubuntu/Debian: `sudo apt-get install apache2-utils`
     - CentOS: `sudo yum install httpd-tools`

3. **Create a Basic Authentication File:**
   - Use the `htpasswd` utility to create a file with the username and hashed password.

     ```bash
     sudo htpasswd -c /etc/nginx/.htpasswd user1
     ```

4. **Edit Nginx Configuration:**
   - Open the Nginx configuration file for editing.

     ```bash
     sudo nano /etc/nginx/nginx.conf
     ```

   - Add the following configuration inside the `http` block:

     ```nginx
     server {
         listen 80;
         server_name your-domain.com;

         location /private {
             auth_basic "Restricted Access";
             auth_basic_user_file /etc/nginx/.htpasswd;
             allow 192.168.1.0/24;
             deny all;
         }
     }
     ```

   - Adjust network range according to the address where you are:

5. **Save and Close:**
   - Save the configuration file and close the text editor.

6. **Test Access:**
   - Open a web browser and try to access the `/private` location on your server. You should be prompted for credentials.
   - Use the username `user1` and the password you set during the `htpasswd` creation.

     ```bash
     echo "127.0.0.1 your-domain.com" | sudo tee /etc/hosts
     sudo nginx -t
     sudo systemctl reload nginx
     ```  

7. **Verify Access List:**
   - Test access from both the allowed IP range (192.168.1.0/24) and a denied IP range to ensure that access lists are working as expected.

6. **Cleanup:**

- Remove added configuration from point `4`.
