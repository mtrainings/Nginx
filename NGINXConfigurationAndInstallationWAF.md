# NGINX Configuration And Installation WAF

## Objective

Configure NGINX and install a Web Application Firewall (WAF) to enhance the security of your web application.

## Steps

### Prerequisites & Requirements

1. **Install Nginx:**
   - If you haven't installed Nginx, do so based on your operating system. For example:
     - Ubuntu/Debian: `sudo apt-get install nginx`
     - CentOS: `sudo yum install nginx`

### Downloading & Building ModSecurity

1. **Install all the dependencies required for the build and compilation process with the following command:**

     ```bash
     sudo apt-get install bison build-essential ca-certificates curl dh-autoreconf doxygen \
     flex gawk git iputils-ping libcurl4-gnutls-dev libexpat1-dev libgeoip-dev liblmdb-dev \
     libpcre3-dev libpcre++-dev libssl-dev libtool libxml2 libxml2-dev libyajl-dev locales \
     lua5.3-dev pkg-config wget zlib1g-dev zlibc libxslt1-dev libgd-dev
     ```

2. **Clone the ModSecurity Github repository from the /opt directory:**

     ```bash
     cd /opt && sudo git clone https://github.com/SpiderLabs/ModSecurity && cd ModSecurity
     ```

3. **Run the following git commands to initialize and update the submodule:**

     ```bash
     sudo git submodule init
     sudo git submodule update     
     ```

4. **Run the build.sh script:**

     ```bash
     sudo ./build.sh   
     ```

5. **Run the configure file, which is responsible for getting all the dependencies for the build process:**

     ```bash
     sudo ./configure
     ```

6. **Run the make command to build ModSecurity:**

     ```bash
     sudo make
     ```

7. **After the build process is complete, install ModSecurity by running the following command:**

     ```bash
     sudo make install
     ```

### Downloading ModSecurity-Nginx Connector

1. **Clone the Nginx-connector from the /opt directory:**

     ```bash
     cd /opt && sudo git clone --depth 1 https://github.com/SpiderLabs/ModSecurity-nginx.git 
     ```

### Building the ModSecurity Module For Nginx

1. **Enumerate the version of Nginx you have installed:**

     ```bash
     nginx -v
     ```  

2. **Download the exact version of Nginx running on your system into the /opt directory:**

     ```bash
     cd /opt && sudo wget http://nginx.org/download/nginx-1.18.0.tar.gz
     ```

3. **Extract the tarball:**

     ```bash
     sudo tar -xvzmf nginx-1.18.0.tar.gz
     ```

4. **Change your directory to the tarball directory you just extracted:**

     ```bash
      cd nginx-1.18.0
     ```

5. **Display the configure arguments used for your version of Nginx:**

     ```bash
      nginx -V
     ```

   - Below is an example output for Nginx 1.18.0:

     ```bash
      root@vagrant:/var/log/nginx# nginx -V
      nginx version: nginx/1.18.0 (Ubuntu)
      built with OpenSSL 1.1.1f  31 Mar 2020
      TLS SNI support enabled
      configure arguments: --with-cc-opt='-g -O2 -fdebug-prefix-map=/build/nginx-lUTckl/nginx-1.18.0=. -fstack-protector-strong -Wformat -Werror=format-security -fPIC -Wdate-time -D_FORTIFY_SOURCE=2' --with-ld-opt='-Wl,-Bsymbolic-functions -Wl,-z,relro -Wl,-z,now -fPIC' --prefix=/usr/share/nginx --conf-path=/etc/nginx/nginx.conf --http-log-path=/var/log/nginx/access.log --error-log-path=/var/log/nginx/error.log --lock-path=/var/lock/nginx.lock --pid-path=/run/nginx.pid --modules-path=/usr/lib/nginx/modules --http-client-body-temp-path=/var/lib/nginx/body --http-fastcgi-temp-path=/var/lib/nginx/fastcgi --http-proxy-temp-path=/var/lib/nginx/proxy --http-scgi-temp-path=/var/lib/nginx/scgi --http-uwsgi-temp-path=/var/lib/nginx/uwsgi --with-debug --with-compat --with-pcre-jit --with-http_ssl_module --with-http_stub_status_module --with-http_realip_module --with-http_auth_request_module --with-http_v2_module --with-http_dav_module --with-http_slice_module --with-threads --with-http_addition_module --with-http_gunzip_module --with-http_gzip_static_module --with-http_image_filter_module=dynamic --with-http_sub_module --with-http_xslt_module=dynamic --with-stream=dynamic --with-stream_ssl_module --with-mail=dynamic --with-mail_ssl_module
     ```

6. **Compile the Modsecurity module, copy all of the arguments following configure arguments: from your output of the above command and paste them in place of `Configure Arguments` in the following command:**

     ```bash
      sudo ./configure --add-dynamic-module=../ModSecurity-nginx <Configure Arguments>
     ```

7. **Build the modules with the following command:**

     ```bash
      sudo make modules
     ```  

8. **Create a directory for the Modsecurity module in your system’s Nginx configuration folder:**

     ```bash
      sudo mkdir /etc/nginx/modules
     ```

9. **Copy the compiled Modsecurity module into your Nginx configuration folder:**

     ```bash
      sudo cp objs/ngx_http_modsecurity_module.so /etc/nginx/modules
     ```

### Loading the ModSecurity Module in Nginx

1. **Open the `/etc/nginx/nginx.conf` file with a text editor such a vim and add the following line:**

     ```bash
      load_module /etc/nginx/modules/ngx_http_modsecurity_module.so;
     ```

### Setting Up OWASP-CRS

1. **Delete the current rule set that comes prepackaged with ModSecurity by running the following command: :**

     ```bash
      sudo rm -rf /usr/share/modsecurity-crs
     ```  

2. **Clone the OWASP-CRS GitHub repository into the `/usr/share/modsecurity-crs` directory: :**

     ```bash
      sudo git clone https://github.com/coreruleset/coreruleset /usr/local/modsecurity-crs
     ```  

3. **Rename the `crs-setup.conf.example` to `crs-setup.conf`:**

     ```bash
      sudo mv /usr/local/modsecurity-crs/crs-setup.conf.example /usr/local/modsecurity-crs/crs-setup.conf
     ```  

4. **Rename the default request exclusion rule file:**

     ```bash
      sudo mv /usr/local/modsecurity-crs/rules/REQUEST-900-EXCLUSION-RULES-BEFORE-CRS.conf.example /usr/local/modsecurity-crs/rules/REQUEST-900-EXCLUSION-RULES-BEFORE-CRS.conf
     ```

### Configuring Modsecurity

1. **Create a ModSecurity directory in the `/etc/nginx/` directory:**

     ```bash
      sudo mkdir -p /etc/nginx/modsec
     ```

2. **Copy over the unicode mapping file and the ModSecurity configuration file from your cloned ModSecurity GitHub repository:**

     ```bash
      sudo cp /opt/ModSecurity/unicode.mapping /etc/nginx/modsec
      sudo cp /opt/ModSecurity/modsecurity.conf-recommended /etc/nginx/modsec/modsecurity.conf
     ```

3. **Remove the `.recommended` extension from the ModSecurity configuration filename with the following command:**

     ```bash
      sudo cp /etc/modsecurity/modsecurity.conf-recommended /etc/modsecurity/modsecurity.conf
     ```

4. **Change the value for `SecRuleEngine` to `On` in `/etc/modsecurity/modsecurity.conf`**

5. **Create a new configuration file called `main.conf` under the `/etc/nginx/modsec` directory:**

     ```bash
      sudo touch /etc/nginx/modsec/main.conf
     ```

6. **Specify the rules and the Modsecurity configuration file for Nginx by inserting following lines:**

     ```bash
      Include /etc/nginx/modsec/modsecurity.conf
      Include /usr/local/modsecurity-crs/crs-setup.conf
      Include /usr/local/modsecurity-crs/rules/*.conf
     ```

### Configuring Nginx

1. **Edit `/etc/nginx/sites-available/default` and insert the following lines in your server block: :**

     ```bash
      modsecurity on;
      modsecurity_rules_file /etc/nginx/modsec/main.conf;
     ```

2. **Restart the nginx service to apply the configuration:**

     ```bash
      sudo systemctl restart nginx
     ```

### Testing ModSecurity

1. **Test ModSecurity by performing a simple local file inclusion attack by running the following command:**

     ```bash
      curl http://<SERVER-IP>/index.html?exec=/bin/bash
     ```

   - If ModSecurity has been configured correctly and is actively blocking attacks, the following error is returned:

   ```bash
   root@vagrant:/var/log/nginx# curl http://127.0.0.1/index.html?exec=/bin/bash
   <html>
   <head><title>403 Forbidden</title></head>
   <body>
   <center><h1>403 Forbidden</h1></center>
   <hr><center>nginx/1.18.0 (Ubuntu)</center>
   </body>
   </html>
   root@vagrant:/var/log/nginx#
   ```

2. **Check nginx error log**
