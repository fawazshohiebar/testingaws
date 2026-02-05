#!/bin/bash
# Quick deployment script to fix 403 error

echo "🚀 Deploying fixed Dockerfile..."

# Add and commit changes
git add Dockerfile
git commit -m "Fix 403 error - configure Nginx and PHP-FPM permissions"

# Push to repository
git push origin main

echo ""
echo "✅ Changes pushed!"
echo ""
echo "📋 After Coolify rebuilds, run these commands in the container:"
echo ""
echo "   1. Check if public/index.php exists:"
echo "      ls -la /var/www/html/public/"
echo ""
echo "   2. Check permissions:"
echo "      ls -la /var/www/html/"
echo ""
echo "   3. Test PHP-FPM:"
echo "      ps aux | grep php-fpm"
echo ""
echo "   4. Test Nginx:"
echo "      curl -I http://localhost"
echo ""
echo "   5. Check Nginx error logs:"
echo "      tail -f /var/log/nginx/error.log"
echo ""
