FROM wordpress:latest

# Install additional PHP extensions
RUN docker-php-ext-install mysqli pdo pdo_mysql

# Copy custom configuration
COPY wp-config.php /var/www/html/

# Set proper permissions
RUN chown -R www-data:www-data /var/www/html

# Health check
HEALTHCHECK --interval=30s --timeout=3s --start-period=5s --retries=3 \
  CMD curl -f http://localhost/wp-admin/install.php || exit 1

EXPOSE 80
