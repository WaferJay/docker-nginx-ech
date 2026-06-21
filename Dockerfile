FROM alpine:3.23

LABEL maintainer="WaferJay <https://github.com/WaferJay>"

ENV OPENSSL_VERSION=4.0.1
ENV NGINX_VERSION=1.31.2

RUN tmpDir=$(mktemp -d) \
    && cd $tmpDir \
    && apk add --no-cache --virtual .build-deps perl make gcc libc-dev linux-headers zlib-dev \
        pcre2-dev curl \
    && curl -fL -- "https://github.com/nginx/nginx/releases/download/release-${NGINX_VERSION}/nginx-${NGINX_VERSION}.tar.gz" > nginx.tar.gz \
    && curl -fL -- "https://github.com/openssl/openssl/releases/download/openssl-${OPENSSL_VERSION}/openssl-${OPENSSL_VERSION}.tar.gz" > openssl.tar.gz \
    && tar zxf openssl.tar.gz -C $tmpDir \
    && tar zxf nginx.tar.gz -C $tmpDir \
    && rm openssl.tar.gz nginx.tar.gz \
    && cd $tmpDir/openssl* \
    && ./Configure --prefix=/usr --libdir=/usr/lib --openssldir=/etc/ssl4 \
    && make test install_sw install_fips \
    && addgroup -S nginx \
    && adduser -S -H -s /sbin/nologin -G nginx -g nginx nginx \
    && cd $tmpDir/nginx* \
    && ./configure \
      --prefix=/etc/nginx \
      --sbin-path=/usr/sbin/nginx \
      --modules-path=/usr/lib/nginx/modules \
      --conf-path=/etc/nginx/nginx.conf \
      --error-log-path=/var/log/nginx/error.log \
      --http-log-path=/var/log/nginx/access.log \
      --pid-path=/run/nginx.pid \
      --lock-path=/run/nginx.lock \
      --http-client-body-temp-path=/var/cache/nginx/client_temp \
      --http-proxy-temp-path=/var/cache/nginx/proxy_temp \
      --http-fastcgi-temp-path=/var/cache/nginx/fastcgi_temp \
      --http-uwsgi-temp-path=/var/cache/nginx/uwsgi_temp \
      --http-scgi-temp-path=/var/cache/nginx/scgi_temp \
      --with-perl_modules_path=/usr/lib/perl5/vendor_perl \
      --user=nginx \
      --group=nginx \
      --with-compat \
      --with-file-aio \
      --with-threads \
      --with-http_addition_module \
      --with-http_auth_request_module \
      --with-http_dav_module \
      --with-http_flv_module \
      --with-http_gunzip_module \
      --with-http_gzip_static_module \
      --with-http_mp4_module \
      --with-http_random_index_module \
      --with-http_realip_module \
      --with-http_secure_link_module \
      --with-http_slice_module \
      --with-http_ssl_module \
      --with-http_stub_status_module \
      --with-http_sub_module \
      --with-http_v2_module \
      --with-http_v3_module \
      --with-mail \
      --with-mail_ssl_module \
      --with-stream \
      --with-stream_realip_module \
      --with-stream_ssl_module \
      --with-stream_ssl_preread_module \
      --with-cc-opt="" --with-ld-opt="" \
    && make install \
    && if [ -n "$tmpDir" ]; then rm -rf "$tmpDir"; fi \
    && apk del --no-network .build-deps \
    && apk add --no-cache tzdata pcre2 \
    && ln -sf /dev/stdout /var/log/nginx/access.log \
    && ln -sf /dev/stderr /var/log/nginx/error.log \
    && mkdir /docker-entrypoint.d /var/cache/nginx \
    && chown nginx:nginx /var/cache/nginx


COPY docker-entrypoint.sh /
COPY 10-listen-on-ipv6-by-default.sh /docker-entrypoint.d
COPY 15-local-resolvers.envsh /docker-entrypoint.d
COPY 20-envsubst-on-templates.sh /docker-entrypoint.d
COPY 30-tune-worker-processes.sh /docker-entrypoint.d
ENTRYPOINT ["/docker-entrypoint.sh"]

EXPOSE 80

STOPSIGNAL SIGQUIT

CMD ["nginx", "-g", "daemon off;"]

