FROM alpine:3.10

ARG NGINX_VERSION=1.14.2
ARG GOOGLE_FILTER_MODULE_VERSION=5806afeffe0a773f70f6aa8ef509b9f118ef6c2c
ARG SUBSTITUTIONS_FILTER_MODULE_VERSION=bc58cb11844bc42735bbaef7085ea86ace46d05b
ARG NGX_BROTLI_VERSION=dc37f658ccb5a51d090dc09d1a2aca2f24309869

RUN GPG_KEYS=B0F4253373F8F6F510D42178520A9993A1C052F8 \
  && CONFIG="\
    --prefix=/etc/nginx \
    --sbin-path=/usr/sbin/nginx \
    --modules-path=/usr/lib/nginx/modules \
    --conf-path=/etc/nginx/nginx.conf \
    --error-log-path=/var/log/nginx/error.log \
    --http-log-path=/var/log/nginx/access.log \
    --pid-path=/var/run/nginx.pid \
    --lock-path=/var/run/nginx.lock \
    --http-client-body-temp-path=/var/cache/nginx/client_temp \
    --http-proxy-temp-path=/var/cache/nginx/proxy_temp \
    --http-fastcgi-temp-path=/var/cache/nginx/fastcgi_temp \
    --http-uwsgi-temp-path=/var/cache/nginx/uwsgi_temp \
    --http-scgi-temp-path=/var/cache/nginx/scgi_temp \
    --user=nginx \
    --group=nginx \
    --with-http_ssl_module \
    --with-http_realip_module \
    --with-http_addition_module \
    --with-http_sub_module \
    --with-http_dav_module \
    --with-http_flv_module \
    --with-http_mp4_module \
    --with-http_gunzip_module \
    --with-http_gzip_static_module \
    --with-http_random_index_module \
    --with-http_secure_link_module \
    --with-http_stub_status_module \
    --with-http_auth_request_module \
    --with-http_xslt_module=dynamic \
    --with-http_image_filter_module=dynamic \
    --with-http_geoip_module=dynamic \
    --with-threads \
    --with-stream \
    --with-stream_ssl_module \
    --with-stream_ssl_preread_module \
    --with-stream_realip_module \
    --with-stream_geoip_module=dynamic \
    --with-http_slice_module \
    --with-mail \
    --with-mail_ssl_module \
    --with-compat \
    --with-file-aio \
    --with-http_v2_module \
    --add-module=/usr/src/ngx_http_google_filter_module-$GOOGLE_FILTER_MODULE_VERSION \
    --add-module=/usr/src/ngx_http_substitutions_filter_module-$SUBSTITUTIONS_FILTER_MODULE_VERSION \
    --add-module=/usr/src/ngx_brotli \
  " \
  && addgroup -S nginx \
  && adduser -D -S -h /var/cache/nginx -s /sbin/nologin -G nginx nginx \
  && apk add --no-cache ca-certificates \
  && apk add --no-cache --virtual .build-deps \
    gcc \
    libc-dev \
    make \
    openssl-dev \
    pcre-dev \
    zlib-dev \
    linux-headers \
    curl \
    gnupg1 \
    libxslt-dev \
    gd-dev \
    geoip-dev \
    git \
  && curl -fsSL https://nginx.org/download/nginx-$NGINX_VERSION.tar.gz -o nginx.tar.gz \
  && curl -fsSL https://nginx.org/download/nginx-$NGINX_VERSION.tar.gz.asc -o nginx.tar.gz.asc \
  && curl -fsSL https://github.com/cuber/ngx_http_google_filter_module/archive/$GOOGLE_FILTER_MODULE_VERSION.tar.gz -o ngx_http_google_filter_module.tar.gz \
  && curl -fsSL https://github.com/yaoweibin/ngx_http_substitutions_filter_module/archive/$SUBSTITUTIONS_FILTER_MODULE_VERSION.tar.gz -o ngx_http_substitutions_filter_module.tar.gz \
  && export GNUPGHOME="$(mktemp -d)" \
  && found=''; \
  for server in \
    ha.pool.sks-keyservers.net \
    hkp://keyserver.ubuntu.com:80 \
    hkp://p80.pool.sks-keyservers.net:80 \
    pgp.mit.edu \
  ; do \
    echo "Fetching GPG key $GPG_KEYS from $server"; \
    gpg --keyserver "$server" --keyserver-options timeout=10 --recv-keys "$GPG_KEYS" && found=yes && break; \
  done; \
  test -z "$found" && echo >&2 "error: failed to fetch GPG key $GPG_KEYS" && exit 1; \
  gpg --batch --verify nginx.tar.gz.asc nginx.tar.gz \
  && rm -rf "$GNUPGHOME" nginx.tar.gz.asc \
  && mkdir -p /usr/src \
  && tar -x -f nginx.tar.gz -C /usr/src \
  && rm nginx.tar.gz \
  && tar -x -f ngx_http_google_filter_module.tar.gz -C /usr/src \
  && rm ngx_http_google_filter_module.tar.gz \
  && tar -x -f ngx_http_substitutions_filter_module.tar.gz -C /usr/src \
  && rm ngx_http_substitutions_filter_module.tar.gz \
  && git -C /usr/src clone https://github.com/eustas/ngx_brotli.git \
  && git -C /usr/src/ngx_brotli checkout "$NGX_BROTLI_VERSION" \
  && git -C /usr/src/ngx_brotli submodule update --init \
  && cd /usr/src/nginx-$NGINX_VERSION \
  && ./configure $CONFIG --with-debug \
  && make -j$(getconf _NPROCESSORS_ONLN) \
  && mv objs/nginx objs/nginx-debug \
  && mv objs/ngx_http_xslt_filter_module.so objs/ngx_http_xslt_filter_module-debug.so \
  && mv objs/ngx_http_image_filter_module.so objs/ngx_http_image_filter_module-debug.so \
  && mv objs/ngx_http_geoip_module.so objs/ngx_http_geoip_module-debug.so \
  && mv objs/ngx_stream_geoip_module.so objs/ngx_stream_geoip_module-debug.so \
  && ./configure $CONFIG \
  && make -j$(getconf _NPROCESSORS_ONLN) \
  && make install \
  && rm -rf /etc/nginx/html/ \
  && mkdir /etc/nginx/conf.d/ \
  && mkdir -p /usr/share/nginx/html/ \
  && install -m644 html/index.html /usr/share/nginx/html/ \
  && install -m644 html/50x.html /usr/share/nginx/html/ \
  && install -m755 objs/nginx-debug /usr/sbin/nginx-debug \
  && install -m755 objs/ngx_http_xslt_filter_module-debug.so /usr/lib/nginx/modules/ngx_http_xslt_filter_module-debug.so \
  && install -m755 objs/ngx_http_image_filter_module-debug.so /usr/lib/nginx/modules/ngx_http_image_filter_module-debug.so \
  && install -m755 objs/ngx_http_geoip_module-debug.so /usr/lib/nginx/modules/ngx_http_geoip_module-debug.so \
  && install -m755 objs/ngx_stream_geoip_module-debug.so /usr/lib/nginx/modules/ngx_stream_geoip_module-debug.so \
  && ln -s ../../usr/lib/nginx/modules /etc/nginx/modules \
  && strip /usr/sbin/nginx* \
  && strip /usr/lib/nginx/modules/*.so \
  && rm -rf /usr/src/nginx-$NGINX_VERSION \
  && rm -rf /usr/src/ngx_http_google_filter_module-$GOOGLE_FILTER_MODULE_VERSION \
  && rm -rf /usr/src/ngx_http_substitutions_filter_module-$SUBSTITUTIONS_FILTER_MODULE_VERSION \
  && rm -rf /usr/src/ngx_brotli \
  \
  # Bring in gettext so we can get `envsubst`, then throw
  # the rest away. To do this, we need to install `gettext`
  # then move `envsubst` out of the way so `gettext` can
  # be deleted completely, then move `envsubst` back.
  && apk add --no-cache --virtual .gettext gettext \
  && mv /usr/bin/envsubst /tmp/ \
  \
  && runDeps="$( \
    scanelf --needed --nobanner --format '%n#p' /usr/sbin/nginx /usr/lib/nginx/modules/*.so /tmp/envsubst \
      | tr ',' '\n' \
      | sort -u \
      | awk 'system("[ -e /usr/local/lib/" $1 " ]") == 0 { next } { print "so:" $1 }' \
  )" \
  && apk add --no-cache --virtual .nginx-rundeps $runDeps \
  && apk del .build-deps \
  && apk del .gettext \
  && mv /tmp/envsubst /usr/local/bin/ \
  \
  # Bring in tzdata so users could set the timezones through the environment
  # variables
  && apk add --no-cache tzdata \
  \
  # forward request and error logs to docker log collector
  && ln -sf /dev/stdout /var/log/nginx/access.log \
  && ln -sf /dev/stderr /var/log/nginx/error.log

# Copy all files inside nginx directory into /etc/nginx
COPY nginx /etc/nginx/

  # setup certificates
RUN apk add --no-cache gnutls-utils \
  && certtool --generate-privkey --outfile /etc/nginx/certs/ca-key.pem \
  && certtool --generate-self-signed --load-privkey /etc/nginx/certs/ca-key.pem --template /etc/nginx/certs/ca-tmp --outfile /etc/nginx/certs/ca-cert.pem \
  && certtool --generate-privkey --outfile /etc/nginx/certs/server-key.pem \
  && certtool --generate-certificate --load-privkey /etc/nginx/certs/server-key.pem --load-ca-certificate /etc/nginx/certs/ca-cert.pem --load-ca-privkey /etc/nginx/certs/ca-key.pem --template /etc/nginx/certs/serv-tmp --outfile /etc/nginx/certs/server-cert.pem

EXPOSE 80 443

STOPSIGNAL SIGTERM

CMD ["nginx", "-g", "daemon off;"]
