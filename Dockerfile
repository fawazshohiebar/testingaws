FROM php:8.3-fpm

# Install system dependencies
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
    && apt-get clean && rm -rf /var/lib/apt/lists/*

# Install PHP extensions
RUN docker-php-ext-install \
    pdo \
    pdo_mysql \
    zip \
    gd \
    mbstring \
    xml \
    pcntl \
    bcmath

# Install Redis extension
RUN pecl install redis && docker-php-ext-enable redis

# Configure PHP-FPM to run as www-data
RUN echo 'user = www-data\n\
group = www-data\n\
listen = 127.0.0.1:9000\n\
pm = dynamic\n\
pm.max_children = 20\n\
pm.start_servers = 2\n\
pm.min_spare_servers = 1\n\
pm.max_spare_servers = 3' > /usr/local/etc/php-fpm.d/www.conf

# Copy Composer from official image
COPY --from=composer:2 /usr/bin/composer /usr/bin/composer

# Set working directory
WORKDIR /var/www/html

# Copy composer files
COPY composer.json composer.lock ./

# Install PHP dependencies (ignore platform reqs during build)
RUN composer install --no-dev --prefer-dist --no-progress --no-interaction --optimize-autoloader --no-scripts

# Copy application files
COPY . .

# Run composer scripts after copying all files
RUN composer dump-autoload --optimize

# Create necessary directories and set permissions
RUN mkdir -p storage/framework/cache \
    storage/framework/sessions \
    storage/framework/views \
    storage/logs \
    bootstrap/cache \
    && chown -R www-data:www-data /var/www/html \
    && chmod -R 775 storage bootstrap/cache \
    && chmod -R 775 /var/www/html/public

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

# Create supervisor config for PHP-FPM and Nginx (Horizon removed)
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

# Optimize Laravel
RUN php artisan config:cache || true \
    && php artisan route:cache || true \
    && php artisan view:cache || true

RUN chown -R www-data:www-data /var/www/html && \
chmod -R 775 /var/www/html/storage /var/www/html/bootstrap/cache && \
chmod -R 755 /var/www/html/public

EXPOSE 80

CMD ["/usr/bin/supervisord", "-c", "/etc/supervisor/conf.d/supervisord.conf"]
