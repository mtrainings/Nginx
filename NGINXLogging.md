# NGINX Logging

#### Practice Lab: Nginx Logging Configuration

## Objective

Configure and manage Nginx logs, including access logs, error logs, and custom access logs.

## Steps

1. **Install Nginx:**
   - If you haven't installed Nginx, do so based on your operating system. For example:
     - Ubuntu/Debian: `sudo apt-get install nginx`
     - CentOS: `sudo yum install nginx`

2. **Configure Access Logs:**
   - Open the Nginx default configuration file for editing.

     ```bash
     sudo nano /etc/nginx/nginx.conf
     ```

   - Add or modify the `http` block to include access log configuration.

     ```nginx
     http {
         # Other configurations...

         log_format main '$remote_addr - $remote_user [$time_local] "$request" '
                         '$status $body_bytes_sent "$http_referer" '
                         '"$http_user_agent" "$http_x_forwarded_for"';

         access_log /var/log/nginx/access.log main;

         # Additional access log configurations...
     }
     ```

   - Save the configuration file and reload Nginx.

3. **Configure Error Logs:**
   - Open the Nginx default configuration file for editing.

     ```bash
     sudo nano /etc/nginx/nginx.conf
     ```

   - Add or modify the `http` block to include error log configuration.

     ```nginx
     http {
         # Other configurations...

         error_log /var/log/nginx/error.log;

         # Additional error log configurations...
     }
     ```

   - Save the configuration file and reload Nginx.

4. **Create Custom Access Log:**
   - Create a custom access log for a specific location or server block.

     ```nginx
     server {
         listen 80;
         server_name your-domain.com;

         location / {
             access_log /var/log/nginx/custom_access.log custom_format;
             # Other location configurations...
         }
     }

     http {
         log_format custom_format '$remote_addr - $remote_user [$time_local] "$request" '
                                 '$status $body_bytes_sent "$http_referer" '
                                 '"$http_user_agent" "$http_x_forwarded_for"';
     }
     ```

   - Save the configuration file and reload Nginx.

5. **Test Logging:**
   - Access your Nginx server to generate logs.
   - Check the access log, error log, and custom access log for entries.

     ```bash
     sudo cat /var/log/nginx/access.log
     sudo cat /var/log/nginx/error.log
     sudo cat /var/log/nginx/custom_access.log
     ```

6. **Explore Additional Logging Configurations:**
   - Experiment with additional logging configurations such as log rotation, logging to syslog, or configuring different log formats.
   - Adjust log levels in error logs for debugging or production environments.

7. **Review Nginx Documentation:**
   - Explore the [Nginx logging documentation](http://nginx.org/en/docs/http/ngx_http_log_module.html) to understand the various log-related directives and configurations.

## Conclusion

This lab guides you through configuring and managing Nginx logs, including access logs, error logs, and custom access logs. It covers basic log formats, log locations, and how to create custom logs for specific locations. Feel free to customize the logging configuration based on your specific use case and explore additional Nginx logging features.
