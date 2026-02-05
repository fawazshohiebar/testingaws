# Docker Deployment Guide for Coolify

## ✅ What Was Fixed

1. **Added pcntl extension** - Required by Laravel Horizon for process control
2. **Added redis extension** - Needed for Laravel queues and caching
3. **Added mbstring, xml, bcmath extensions** - Common Laravel requirements
4. **Replaced `php artisan serve`** with Nginx + PHP-FPM (production-ready)
5. **Added Supervisor** - Manages PHP-FPM, Nginx, and Laravel Horizon
6. **Added optimization** - Config/route/view caching for better performance
7. **Created .dockerignore** - Faster builds, smaller images

## 🚀 Deployment Steps

### 1. Environment Variables in Coolify

Make sure these are set in Coolify (not in your .env file):

```bash
APP_NAME=Pavilion
APP_ENV=production
APP_KEY=your-app-key-here
APP_DEBUG=false
APP_URL=https://yourdomain.com

DB_CONNECTION=mysql
DB_HOST=your-db-host
DB_PORT=3306
DB_DATABASE=your-database
DB_USERNAME=your-username
DB_PASSWORD=your-password

REDIS_HOST=your-redis-host
REDIS_PASSWORD=your-redis-password
REDIS_PORT=6379

QUEUE_CONNECTION=redis
CACHE_STORE=redis
SESSION_DRIVER=redis

# Add all other env vars from your .env file
```

### 2. Push to GitHub

```bash
git add .
git commit -m "Fix Docker deployment - add pcntl and production config"
git push origin main
```

### 3. Deploy in Coolify

- Go to your Coolify dashboard
- Click on your application
- Click "Deploy" or wait for auto-deploy
- Monitor the build logs

## 🔍 What's Running

After successful deployment, your container will run:

1. **Nginx** - Web server on port 8000
2. **PHP-FPM** - PHP FastCGI Process Manager
3. **Laravel Horizon** - Queue worker for background jobs

## 📝 Important Notes

### Database Migrations

After first deployment, you'll need to run migrations. In Coolify:

1. Go to your application
2. Open the terminal/console
3. Run:
```bash
php artisan migrate --force
```

### Storage Link

Create the storage symlink:
```bash
php artisan storage:link
```

### Cache Clearing (if needed)

```bash
php artisan config:clear
php artisan cache:clear
php artisan view:clear
php artisan route:clear
```

## 🐛 Troubleshooting

### Build fails with "composer install" error
- Check that all required PHP extensions are listed in the Dockerfile
- Make sure composer.lock is committed to git

### Application shows 500 error
- Check APP_KEY is set in Coolify environment variables
- Run `php artisan key:generate` in the terminal
- Check storage permissions
- View logs in Coolify

### Horizon not working
- Verify REDIS_HOST is set correctly
- Check Horizon logs: `storage/logs/horizon.log`
- Restart the container

### Permission errors
- The container sets permissions during build
- If issues persist, run: `chown -R www-data:www-data /var/www/html`

## 📊 Monitoring

### Check Horizon Dashboard
Visit: `https://yourdomain.com/horizon`

### Check Application Logs
In Coolify terminal:
```bash
tail -f storage/logs/laravel.log
```

### Check Horizon Logs
```bash
tail -f storage/logs/horizon.log
```

## 🎯 Next Steps (Optional Improvements)

1. **Add Health Checks** - Configure Coolify health check endpoint
2. **Add Redis** - Set up Redis service in Coolify
3. **Add Scheduler** - Add Laravel scheduler to supervisor if you use it
4. **SSL/HTTPS** - Coolify handles this automatically
5. **Backups** - Configure database backups in Coolify

## 📦 Production Checklist

- [ ] All environment variables set in Coolify
- [ ] APP_DEBUG=false
- [ ] APP_KEY generated and set
- [ ] Database configured and accessible
- [ ] Redis configured and accessible
- [ ] Storage directory writable
- [ ] Migrations run
- [ ] SSL certificate active
- [ ] Horizon dashboard accessible
- [ ] Test application functionality

## 🔐 Security Notes

- Never commit .env file to git
- Use Coolify's environment variable management
- Keep APP_DEBUG=false in production
- Regularly update dependencies
- Monitor error logs

---

Good luck with your deployment! 🎉
