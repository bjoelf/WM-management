# New Instance Deployment Checklist

When deploying a new instance of pivot-web2 on the VM, follow these steps to ensure proper configuration across all deployment scripts and services.

## 1. Environment Variables (.env)

- [ ] Create unique `.env` file for the new instance
  - [ ] Set `SERVICE_NAME=newrunner-NAME` (unique identifier, e.g., `newrunner-algo1`)
  - [ ] Set `SERVER_ADDRESS=:PORT` (assign unique port, e.g., `:8082`, `:8083`)
  - [ ] Set `SAXO_ENVIRONMENT` (sim or live)
  - [ ] Set `LOG_LEVEL` (debug, info, warn, error)
  - [ ] Set `SIGNUP_SECRET` (keep consistent or unique per instance)
  - [ ] Set all Saxo credentials (`SIM_CLIENT_ID`, `SIM_CLIENT_SECRET`, etc.)
  - [ ] **Store separately** in instance-specific directory

## 2. DNS & Subdomain

- [ ] Create unique subdomain at registrar (e.g., `instance-name.pipsnticks.se`)
  - [ ] Add A record pointing to VM IP: `34.79.13.81`
  - [ ] Wait for DNS propagation (test with `dig instance-name.pipsnticks.se`)

## 3. Systemd Service Configuration

**File to modify:** `scripts/setup-newrunner-service.sh`

- [ ] Update `SERVICE_NAME` variable (must match `.env` SERVICE_NAME)
  ```bash
  SERVICE_NAME="newrunner-algo1"
  ```

- [ ] Update `DEPLOY_DIR` variable (unique directory per instance)
  ```bash
  DEPLOY_DIR="/opt/newrunner-algo1"
  ```

- [ ] Update `BINARY_NAME` variable (optional, can be same across instances or unique)
  ```bash
  BINARY_NAME="newrunner-algo1"
  ```

- [ ] Update `PORT` variable (must match `.env` SERVER_ADDRESS port)
  ```bash
  PORT=8082
  ```

- [ ] Update subdomain reference in echo output (cosmetic, for clarity)
  ```bash
  echo "  - Subdomain: instance-name.pipsnticks.se"
  ```

- [ ] Update systemd SyslogIdentifier (for log filtering)
  ```bash
  SyslogIdentifier=$SERVICE_NAME
  ```

- [ ] Run script: `./scripts/setup-newrunner-service.sh`
  - Creates `/etc/systemd/system/SERVICE_NAME.service` file
  - Creates deployment directory with proper ownership
  - Enables service (but doesn't start it yet)

## 4. Nginx Configuration

**File to modify:** `scripts/setup-newrunner-nginx.sh`

- [ ] Update `SERVICE_NAME` variable (if using for reference)
  ```bash
  SERVICE_NAME="newrunner-algo1"
  ```

- [ ] Update `SUBDOMAIN` variable (must match DNS subdomain from step 2)
  ```bash
  SUBDOMAIN="instance-name.pipsnticks.se"
  ```

- [ ] Update `PORT` variable (must match `.env` SERVER_ADDRESS port)
  ```bash
  PORT=8082
  ```

- [ ] Update nginx config filenames (references to "newrunner")
  ```bash
  # In gcloud command:
  sudo tee /etc/nginx/sites-available/newrunner-algo1 << 'EOF'
  # ...
  proxy_pass http://127.0.0.1:8082;  # Match PORT above
  # ...
  server_name instance-name.pipsnticks.se;  # Match SUBDOMAIN
  ```

- [ ] Update log file paths (for clarity, use instance name)
  ```bash
  access_log /var/log/nginx/newrunner-algo1.access.log;
  error_log /var/log/nginx/newrunner-algo1.error.log;
  ```

- [ ] Run script: `./scripts/setup-newrunner-nginx.sh`
  - Creates nginx config at `/etc/nginx/sites-available/newrunner-algo1`
  - Enables symlink at `/etc/nginx/sites-enabled/newrunner-algo1`
  - Tests and reloads nginx

- [ ] **Manual step:** Obtain SSL certificate
  ```bash
  gcloud compute ssh pivot-trading-vm --zone=europe-west1-b \
    --command='sudo certbot --nginx -d instance-name.pipsnticks.se'
  ```
  - Certbot will auto-update nginx config with SSL
  - Test HTTPS: `curl -I https://instance-name.pipsnticks.se`

## 5. Application Deployment

**File to reference:** `scripts/deploy-service.sh`

This script is configured for deploying to the default instance. For new instances:

- [ ] Create instance-specific deployment script OR
- [ ] Run `deploy-service.sh` with manual adjustments:
  ```bash
  # Before running, edit the script to set:
  DEPLOY_DIR="/opt/newrunner-algo1"
  SERVICE_NAME="newrunner-algo1"
  BINARY_NAME="newrunner-algo1"
  ```

- [ ] Or create new script: `deploy-service-algo1.sh`
  - Copy `deploy-service.sh`
  - Update all hardcoded values above
  - Keep deployment logic identical

- [ ] Run deployment: `./scripts/deploy-service.sh` (or custom variant)
  - Deploys application code
  - Builds binary on VM
  - Preserves `.env` and `data/` directory

## 6. Verify Deployment

- [ ] Check service status:
  ```bash
  gcloud compute ssh pivot-trading-vm --zone=europe-west1-b \
    --command='sudo systemctl status newrunner-algo1'
  ```

- [ ] View service logs:
  ```bash
  gcloud compute ssh pivot-trading-vm --zone=europe-west1-b \
    --command='sudo journalctl -u newrunner-algo1 -f'
  ```

- [ ] Test HTTP endpoint (before SSL):
  ```bash
  curl -I http://instance-name.pipsnticks.se
  ```

- [ ] Test HTTPS endpoint (after certbot):
  ```bash
  curl -I https://instance-name.pipsnticks.se
  ```

- [ ] Check logs endpoint (with proper SERVICE_NAME):
  ```bash
  curl -I https://instance-name.pipsnticks.se/diagnos/logs?code=SIGNUP_SECRET
  # Logs should show SERVICE_NAME in filtering
  ```

## 7. Configuration Updates for Multi-Instance Scripts

**These scripts may need awareness of multiple instances:**

- [ ] `scripts/deploy-env-only.sh`
  - Currently hardcoded for `SERVICE_NAME="newrunner"`
  - For multiple instances, either:
    - Create instance-specific variant: `deploy-env-only-algo1.sh`
    - Or add command-line argument support: `./deploy-env-only.sh newrunner-algo1`

- [ ] `scripts/check-services-health.sh`
  - Currently checks both `runner` (legacy) and `newrunner` (default instance)
  - Update to include all new instances
  - Add loop to check all services: `newrunner`, `newrunner-algo1`, `newrunner-algo2`, etc.

- [ ] `scripts/deploy-trading-config.sh` (if exists)
  - Verify which instances need updated trading config
  - May need instance selection parameter

## 8. Log Isolation Verification

- [ ] Verify logs are properly isolated by SERVICE_NAME:
  ```bash
  # Should only show logs from specific instance
  sudo journalctl -u newrunner-algo1 -n 100
  sudo journalctl -u newrunner-algo2 -n 100
  ```

- [ ] Test `/diagnos/logs` endpoint for each instance:
  - Should only display that instance's logs
  - SERVICE_NAME from `.env` controls filtering

## Summary of Files to Modify Per Instance

| File | Variables to Update | Purpose |
|------|-------------------|---------|
| `.env` | SERVICE_NAME, SERVER_ADDRESS, credentials | Instance configuration |
| `setup-newrunner-service.sh` | SERVICE_NAME, DEPLOY_DIR, BINARY_NAME, PORT | Systemd service creation |
| `setup-newrunner-nginx.sh` | SUBDOMAIN, PORT, config file names, log paths | Nginx proxy configuration |
| `deploy-service.sh` | DEPLOY_DIR, SERVICE_NAME, BINARY_NAME | Application deployment |
| `deploy-env-only.sh` | SERVICE_NAME, REMOTE_DIR, SERVER_ADDRESS check | Environment-only deployment |
| `check-services-health.sh` | Add new instance to service list | Health monitoring |

## Troubleshooting

**Issue:** Logs are showing mixed output from multiple instances
- **Check:** Verify SERVICE_NAME in `.env` is unique
- **Fix:** Ensure each instance has unique SERVICE_NAME and runs own systemd service

**Issue:** nginx proxying to wrong port
- **Check:** PORT in `setup-newrunner-nginx.sh` matches SERVER_ADDRESS in `.env`
- **Fix:** Update both to same port number

**Issue:** Service fails to start
- **Check:** DEPLOY_DIR exists with proper ownership
- **Fix:** Run `setup-newrunner-service.sh` to recreate directories
- **Also check:** .env file is in DEPLOY_DIR with proper permissions (644 or 600)

**Issue:** SSL certificate fails
- **Check:** DNS propagation completed (dig SUBDOMAIN)
- **Fix:** Wait for DNS propagation, retry certbot
- **Also check:** nginx is running and accessible on port 80

**Issue:** `/diagnos/logs` returns wrong logs
- **Check:** SERVICE_NAME environment variable in running process
- **Command:** `ps aux | grep BINARY_NAME` to see environment
- **Fix:** Verify EnvironmentFile in systemd service points to correct `.env`
