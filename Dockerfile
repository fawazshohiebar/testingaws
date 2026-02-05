# ============================================
# STAGE 1: Base image with system deps & PHP extensions (cached)
# ============================================
FROM php:8.3-fpm AS base

# Install system dependencies (cached layer)
RUN apt-get update && apt-get install -y \
    git \
    unzip \
    libpng-dev \
    libzip-dev \
    libonig-dev \
    libxml2-dev \
    zip \
    curl \
    nginx \
    supervisor \
    nodejs \
    npm \
    && apt-get clean && rm -rf /var/lib/apt/lists/*

# Install PHP extensions (cached layer)
RUN docker-php-ext-install \
    pdo \
    pdo_mysql \
    zip \
    gd \
    mbstring \
    xml \
    pcntl \
    bcmath

# Install Redis extension (cached layer)
RUN pecl install redis && docker-php-ext-enable redis

# Copy Composer from official image
COPY --from=composer:2 /usr/bin/composer /usr/bin/composer

# Configure PHP-FPM
RUN echo 'user = www-data\n\
group = www-data\n\
listen = 127.0.0.1:9000\n\
pm = dynamic\n\
pm.max_children = 20\n\
pm.start_servers = 2\n\
pm.min_spare_servers = 1\n\
pm.max_spare_servers = 3' > /usr/local/etc/php-fpm.d/www.conf

# Create nginx config
RUN echo 'user www-data;\n\
worker_processes auto;\n\
pid /run/nginx.pid;\n\
\n\
events {\n\
    worker_connections 1024;\n\
}\n\
\n\
http {\n\
    include /etc/nginx/mime.types;\n\
    default_type application/octet-stream;\n\
    sendfile on;\n\
    keepalive_timeout 65;\n\
    \n\
    server {\n\
        listen 80;\n\
        root /var/www/html/public;\n\
        index index.php index.html;\n\
        \n\
        client_max_body_size 100M;\n\
        \n\
        location / {\n\
            try_files $uri $uri/ /index.php?$query_string;\n\
        }\n\
        \n\
        location ~ \.php$ {\n\
            fastcgi_pass 127.0.0.1:9000;\n\
            fastcgi_index index.php;\n\
            fastcgi_param SCRIPT_FILENAME $document_root$fastcgi_script_name;\n\
            include fastcgi_params;\n\
        }\n\
        \n\
        location ~ /\.(?!well-known).* {\n\
            deny all;\n\
        }\n\
    }\n\
}' > /etc/nginx/nginx.conf

# Create supervisor config
RUN echo '[supervisord]\n\
nodaemon=true\n\
\n\
[program:php-fpm]\n\
command=/usr/local/sbin/php-fpm\n\
autostart=true\n\
autorestart=true\n\
stdout_logfile=/dev/stdout\n\
stdout_logfile_maxbytes=0\n\
stderr_logfile=/dev/stderr\n\
stderr_logfile_maxbytes=0\n\
\n\
[program:nginx]\n\
command=/usr/sbin/nginx -g "daemon off;"\n\
autostart=true\n\
autorestart=true\n\
stdout_logfile=/dev/stdout\n\
stdout_logfile_maxbytes=0\n\
stderr_logfile=/dev/stderr\n\
stderr_logfile_maxbytes=0' > /etc/supervisor/conf.d/supervisord.conf

# ============================================
# STAGE 2: Install dependencies (cached if composer.lock unchanged)
# ============================================
FROM base AS deps

WORKDIR /var/www/html

# Copy ONLY dependency files first (for caching)
COPY composer.json composer.lock ./

# Install PHP dependencies
RUN composer install --no-dev --prefer-dist --no-progress --no-interaction --optimize-autoloader --no-scripts

# ============================================
# STAGE 3: Final image with app code
# ============================================
FROM base AS final

WORKDIR /var/www/html

# Copy installed dependencies from deps stage
COPY --from=deps /var/www/html/vendor ./vendor

# Copy application files
COPY . .

# Build frontend assets
RUN npm install && npm run build

# Create necessary directories (including Statamic-specific)
RUN mkdir -p storage/framework/cache \
    storage/framework/sessions \
    storage/framework/views \
    storage/logs \
    storage/statamic/stache-locks \
    storage/statamic/file-locks \
    storage/statamic \
    bootstrap/cache \
    cache/stache/indexes/global-variables \
    cache/stache/indexes/collections \
    cache/stache/indexes/entries \
    cache/stache/indexes/terms \
    cache/stache/indexes/assets \
    cache/stache/indexes/navigations \
    cache/stache/indexes/taxonomies

# Remove any cache files copied from local (they cause permission issues)
RUN rm -rf /var/www/html/cache/* && \
    rm -rf /var/www/html/storage/framework/cache/data/* && \
    rm -rf /var/www/html/storage/logs/*

# Set full permissions on all writable directories
RUN chown -R www-data:www-data /var/www/html && \
    chmod -R 777 /var/www/html/storage && \
    chmod -R 777 /var/www/html/bootstrap/cache && \
    chmod -R 777 /var/www/html/cache && \
    chmod -R 755 /var/www/html/public

# Optimize Laravel (skip if no .env, use || true)
RUN php artisan config:cache || true && \
    php artisan route:cache || true && \
    php artisan view:cache || true

# Final permissions fix (ensure everything is writable after artisan commands)
RUN chown -R www-data:www-data /var/www/html/storage /var/www/html/bootstrap/cache /var/www/html/cache && \
    chmod -R 777 /var/www/html/storage /var/www/html/bootstrap/cache /var/www/html/cache && \
    find /var/www/html/cache -type d -exec chmod 777 {} \; && \
    find /var/www/html/cache -type f -exec chmod 666 {} \;

# Create startup script that fixes permissions and creates directories at runtime
RUN echo '#!/bin/sh\n\
# Create all required cache directories\n\
mkdir -p /var/www/html/cache/stache/indexes/global-variables\n\
mkdir -p /var/www/html/cache/stache/indexes/collections\n\
mkdir -p /var/www/html/cache/stache/indexes/entries\n\
mkdir -p /var/www/html/cache/stache/indexes/terms\n\
mkdir -p /var/www/html/cache/stache/indexes/assets\n\
mkdir -p /var/www/html/cache/stache/indexes/navigations\n\
mkdir -p /var/www/html/cache/stache/indexes/taxonomies\n\
mkdir -p /var/www/html/storage/framework/cache/data\n\
mkdir -p /var/www/html/storage/framework/sessions\n\
mkdir -p /var/www/html/storage/framework/views\n\
mkdir -p /var/www/html/storage/logs\n\
mkdir -p /var/www/html/storage/statamic/stache-locks\n\
mkdir -p /var/www/html/storage/statamic/file-locks\n\
mkdir -p /var/www/html/bootstrap/cache\n\
# Fix permissions\n\
chown -R www-data:www-data /var/www/html/storage /var/www/html/bootstrap/cache /var/www/html/cache 2>/dev/null || true\n\
chmod -R 777 /var/www/html/storage /var/www/html/bootstrap/cache /var/www/html/cache 2>/dev/null || true\n\
# Start services\n\
exec /usr/bin/supervisord -c /etc/supervisor/conf.d/supervisord.conf\n\
' > /start.sh && chmod +x /start.sh

EXPOSE 80

# Override the default entrypoint to ensure /start.sh runs
ENTRYPOINT []
CMD ["/start.sh"]