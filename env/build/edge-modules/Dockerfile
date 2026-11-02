# LAB09 - build extra dynamic modules for the EXACT nginx version of the base image.
# --with-compat makes the module binary-compatible with the official nginx build.
ARG NGINX_TAG=stable
FROM nginx:${NGINX_TAG} AS build
RUN apt-get update \
 && apt-get install -y --no-install-recommends \
      build-essential ca-certificates curl git libpcre2-dev libssl-dev zlib1g-dev
WORKDIR /src
# NGINX_VERSION is set by the official image
RUN curl -fsSL "https://nginx.org/download/nginx-${NGINX_VERSION}.tar.gz" | tar xz \
 && git clone --depth 1 https://github.com/openresty/headers-more-nginx-module.git
RUN cd "nginx-${NGINX_VERSION}" \
 && ./configure --with-compat --add-dynamic-module=../headers-more-nginx-module \
 && make modules \
 && mkdir -p /out && cp objs/*.so /out/

FROM nginx:${NGINX_TAG}
COPY --from=build /out/ /usr/lib/nginx/modules/
