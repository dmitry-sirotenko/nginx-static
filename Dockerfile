FROM alpine:3.12

LABEL maintainer="Dmitry Sirotenko <dmitry.sirotenko@playrix.com>"

ENV NGINX_VERSION 1.18.0
ENV NGX_BROTLI_COMMIT 25f86f0bac1101b6512135eac5f93c49c63609e3

RUN set -x \
    && addgroup -S nginx \
    && adduser -D -S -h /var/cache/nginx -s /sbin/nologin -G nginx nginx \
    && apk add --no-cache --virtual .build-deps \
    		gcc \
    		libc-dev \
    		make \
    		linux-headers \
    		curl \
    		zlib-dev \
    		openssl-dev \
            pcre-dev \
    && apk add --no-cache --virtual .brotli-build-deps \
            autoconf \
            libtool \
            automake \
            git \
            g++ \
            cmake \
    && mkdir -p /usr/src \
    && cd /usr/src \
    && git clone --recursive https://github.com/google/ngx_brotli.git \
    && cd ngx_brotli \
    && git checkout -b $NGX_BROTLI_COMMIT $NGX_BROTLI_COMMIT \
    && cd .. \
    && curl -LSs https://nginx.org/download/nginx-$NGINX_VERSION.tar.gz | tar xzf - -C /usr/src \
    && cd /usr/src/nginx-$NGINX_VERSION \
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
            --with-compat \
            --with-file-aio \
            --with-threads \
            --with-http_gzip_static_module \
            --with-http_ssl_module \
            --without-http_access_module \
            --without-http_auth_basic_module \
            --without-http_autoindex_module \
            --without-http_browser_module \
            --without-http_empty_gif_module \
            --without-http_fastcgi_module \
            --without-http_geo_module \
            --without-http_limit_conn_module \
            --without-http_limit_req_module \
            --without-http_map_module \
            --without-http_memcached_module \
            --without-http_proxy_module \
            --without-http_referer_module \
            --without-http_scgi_module \
            --without-http_ssi_module \
            --without-http_split_clients_module \
            --without-http_upstream_hash_module \
            --without-http_upstream_ip_hash_module \
            --without-http_upstream_keepalive_module \
            --without-http_upstream_least_conn_module \
            --without-http_upstream_zone_module \
            --without-http_userid_module \
            --without-http_uwsgi_module \
            --add-module=/usr/src/ngx_brotli \
        " \
    && ./configure $CONFIG \
    && make -j$(getconf _NPROCESSORS_ONLN) \
    && make install \
    && rm -rf /etc/nginx/html/ \
    && mkdir /etc/nginx/conf.d/ \
    && mkdir -p /usr/share/nginx/html/ \
    && install -m644 html/index.html /usr/share/nginx/html/ \
    && install -m644 html/50x.html /usr/share/nginx/html/ \
    && ln -s ../../usr/lib/nginx/modules /etc/nginx/modules \
    && rm -rf /usr/src/ \
    \
    && apk add --no-cache --virtual .gettext gettext \
    && mv /usr/bin/envsubst /tmp/ \
    \
    && runDeps="$( \
        scanelf --needed --nobanner /usr/sbin/nginx /usr/lib/nginx/modules/*.so /tmp/envsubst \
            | awk '{ gsub(/,/, "\nso:", $2); print "so:" $2 }' \
            | sort -u \
            | xargs -r apk info --installed \
            | sort -u \
    )" \
    && apk add --no-cache --virtual .nginx-rundeps tzdata $runDeps \
    && apk del .build-deps \
    && apk del .brotli-build-deps \
    && apk del .gettext \
    && mv /tmp/envsubst /usr/local/bin/ \
    \
    && ln -sf /dev/stdout /var/log/nginx/access.log \
    && ln -sf /dev/stderr /var/log/nginx/error.log

COPY nginx.conf /etc/nginx/nginx.conf

EXPOSE 80 443

STOPSIGNAL SIGTERM

CMD ["nginx", "-g", "daemon off;"]
