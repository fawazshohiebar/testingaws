# 403 Forbidden Error - Troubleshooting Guide

## What Was Fixed

### 1. **PHP-FPM User Configuration** ✅
- Configured PHP-FPM to run as `www-data` user
- This matches the file ownership

### 2. **Nginx Configuration** ✅
- Moved from `/etc/nginx/sites-available/default` to `/etc/nginx/nginx.conf`
- Added `user www-data;` directive
- Added proper MIME types and worker configuration
- Increased `client_max_body_size` to 100M for file uploads

### 3. **File Permissions** ✅
- Created all necessary Laravel directories
- Set proper ownership: `www-data:www-data`
- Set proper permissions: `775` for writable directories
- Added public directory permissions

### 4. **Build Order** ✅
- Fixed: Now installs composer dependencies BEFORE copying all files
- This prevents issues with autoloading

---

## Deployment Steps

1. **Commit and push changes:**
   ```bash
   chmod +x deploy-fix.sh
   ./deploy-fix.sh
   ```

2. **Wait for Coolify to rebuild** (check deployment logs)

3. **Once deployed, open Coolify terminal and run:**
   ```bash
   # Check if the app is there
   ls -la /var/www/html/public/
   
   # Should see index.php with proper permissions
   # -rw-r--r-- www-data www-data index.php
   ```

---

## Still Getting 403? Try These Commands in Coolify Terminal:

### Check 1: Verify File Ownership
```bash
ls -la /var/www/html/
ls -la /var/www/html/public/
```
**Expected:** Files owned by `www-data:www-data`

### Check 2: Verify Services are Running
```bash
ps aux | grep -E 'nginx|php-fpm'
```
**Expected:** Both nginx and php-fpm processes running as www-data

### Check 3: Test Nginx Config
```bash
nginx -t
```
**Expected:** `syntax is ok` and `test is successful`

### Check 4: Check Nginx Error Logs
```bash
tail -50 /var/log/nginx/error.log
```
**Look for:** Permission denied errors

### Check 5: Test PHP-FPM
```bash
curl -I http://localhost
```
**Expected:** HTTP 200 or 302 redirect

### Check 6: Verify Public Directory
```bash
stat /var/www/html/public/index.php
```
**Expected:** File exists and is readable

---

## Manual Fix (If Still Not Working)

If you still get 403 after rebuild, run these in Coolify terminal:

```bash
# Fix permissions
chown -R www-data:www-data /var/www/html
chmod -R 775 /var/www/html/storage
chmod -R 775 /var/www/html/bootstrap/cache
chmod -R 755 /var/www/html/public

# Restart services
supervisorctl restart all

# Check logs
tail -f /var/log/nginx/error.log
```

---

## Common Causes of 403 After Fix

1. **Old build cache** - Force rebuild in Coolify
2. **Volume permissions** - If using volumes, they might have wrong permissions
3. **SELinux (rare)** - If server has SELinux, might need configuration
4. **.htaccess issues** - Make sure no conflicting Apache configs

---

## Success Indicators

✅ You should see your Laravel/Statamic homepage  
✅ No error in nginx logs  
✅ PHP-FPM responding to requests  
✅ All assets loading properly  

---

## Need More Help?

Check the logs in Coolify:
- Build logs (for Dockerfile issues)
- Application logs (for runtime issues)
- Container logs (for service issues)
