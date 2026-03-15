# 🚀 Step-by-Step Deployment Guide (Git Clone Method)

## 📋 Prerequisites

- ✅ EC2 Instance running (IP: 13.230.148.121)
- ✅ SSH Key file: `lead-tap.pem` (in Downloads folder)
- ✅ Git Repository URL (public or private with access)
- ✅ Supabase database password
- ✅ Cloudflare R2 credentials
- ✅ Google OAuth credentials

---

## 📍 Step 1: SSH Connect to EC2

### Terminal me yeh command run karein:

```bash
ssh -i ~/Downloads/lead-tap.pem ubuntu@13.230.148.121
```

**Kya hoga:**
- ✅ EC2 server par connect ho jayega
- ✅ Terminal me `ubuntu@ip-xxx-xxx-xxx-xxx:~$` dikhega

---

## 📍 Step 2: Deployment Script Upload (Optional)

Agar script repository me nahi hai, to pehle script upload karein:

### Local Machine Se (Nayi Terminal):

```bash
cd "/Users/divyanshubhati/Desktop/Stall capture/lead-tap"
scp -i ~/Downloads/lead-tap.pem deployment/deploy.sh ubuntu@13.230.148.121:/home/ubuntu/
```

### EC2 Par:

```bash
mkdir -p /home/ubuntu/stall-capture/deployment
mv /home/ubuntu/deploy.sh /home/ubuntu/stall-capture/deployment/
chmod +x /home/ubuntu/stall-capture/deployment/deploy.sh
```

**Ya phir:** Script ko repository me commit karein, to automatically clone hoga.

---

## 📍 Step 3: Run Deployment Script

### EC2 par connect hone ke baad:

```bash
# Script ko executable banayein (agar already nahi hai)
chmod +x /home/ubuntu/stall-capture/deployment/deploy.sh

# Script run karein
/home/ubuntu/stall-capture/deployment/deploy.sh
```

**Ya agar script repository me hai:**

```bash
cd /home/ubuntu
git clone YOUR_GIT_REPO_URL stall-capture
cd stall-capture/deployment
chmod +x deploy.sh
./deploy.sh
```

---

## 📍 Step 4: Script Aap Se Puchhega

Script run hote hi yeh information mang lega:

### 1. Git Repository URL
```
Enter Git Repository URL (e.g., https://github.com/username/repo.git): 
```
- Apni repository ka URL dein
- Example: `https://github.com/yourusername/lead-tap.git`
- Private repo ke liye: `https://username:token@github.com/username/repo.git`

### 2. Domain Name
```
Enter domain name or press Enter to use EC2 Public DNS [ec2-xxx.compute.amazonaws.com]: 
```
- Custom domain dein ya Enter press karein (Public DNS use hoga)

### 3. Supabase Password
```
Enter Supabase database password: [hidden]
```
- Supabase database ka password

### 4. Cloudflare R2 Access Key ID
```
Enter Cloudflare R2 Access Key ID: 
```
- Cloudflare Dashboard → R2 → Manage R2 API Tokens se

### 5. Cloudflare R2 Secret Key
```
Enter Cloudflare R2 Secret Access Key: [hidden]
```
- Same place se

### 6. R2 Bucket Name
```
Enter R2 Bucket Name [stall-capture-media]: 
```
- Default: `stall-capture-media` (Enter press karein)
- Ya apna bucket name dein

### 7. Google OAuth Client ID
```
Enter Google OAuth Client ID: 
```
- Google Cloud Console → APIs & Services → Credentials se

### 8. Google OAuth Client Secret
```
Enter Google OAuth Client Secret: [hidden]
```
- Same place se

### 9. Frontend Domain (CORS)
```
Enter Frontend Domain for CORS (e.g., https://yourdomain.com): 
```
- Frontend ka domain URL dein

---

## 📍 Step 5: Script Automatically Karega

Script automatically yeh sab karega:

1. ✅ **System packages install** (Python, Nginx, Certbot, etc.)
2. ✅ **Git repository clone** (backend aur frontend folders)
3. ✅ **Virtual environment setup**
4. ✅ **Python dependencies install**
5. ✅ **.env file create** (secure keys generate karke)
6. ✅ **Database migrations run**
7. ✅ **Static files collect**
8. ✅ **Nginx configure**
9. ✅ **Gunicorn service setup**
10. ✅ **SSL certificate install** (agar DNS ready hai)
11. ✅ **Services start**

**Time:** 10-15 minutes lagega

---

## 📍 Step 6: Verify Deployment

### Services Check Karein:

```bash
# Gunicorn status
sudo systemctl status gunicorn

# Nginx status
sudo systemctl status nginx
```

### Logs Check Karein:

```bash
# Gunicorn logs
sudo journalctl -u gunicorn -f

# Nginx logs
sudo tail -f /var/log/nginx/stall_capture_error.log
```

### Browser Me Test Karein:

1. **Health Check:**
   - `http://your-domain.com/health/` (ya Public DNS)
   - Response: `{"status":"healthy","service":"stall-capture-api"}`

2. **Swagger API Docs:**
   - `http://your-domain.com/swagger/`

3. **Admin Panel:**
   - `http://your-domain.com/admin/`

---

## 🔄 Future Updates (Code Update)

Agar code update karna ho:

```bash
cd /home/ubuntu/stall-capture
git pull origin main
cd backend
source venv/bin/activate
pip install -r requirements.txt
python manage.py migrate
python manage.py collectstatic --noinput
sudo systemctl restart gunicorn
```

---

## 🔧 Important Commands

### Service Management:

```bash
# Restart Gunicorn
sudo systemctl restart gunicorn

# Restart Nginx
sudo systemctl restart nginx

# View Gunicorn logs
sudo journalctl -u gunicorn -f

# Check service status
sudo systemctl status gunicorn
```

### Django Management:

```bash
cd /home/ubuntu/stall-capture/backend
source venv/bin/activate

# Run migrations
python manage.py migrate

# Create superuser
python manage.py createsuperuser

# Django shell
python manage.py shell
```

---

## ⚠️ Common Issues

### Issue 1: "Git clone failed"

**Solution:**
- Repository URL check karein
- Private repo ke liye access token use karein
- SSH key setup karein (agar SSH URL use kar rahe hain)

### Issue 2: "Backend directory not found"

**Solution:**
- Repository structure check karein
- `backend/` folder repository me hona chahiye

### Issue 3: "Permission denied"

```bash
# Solution
chmod +x deployment/deploy.sh
chmod 600 backend/.env
```

### Issue 4: "DNS not pointing"

```bash
# Check DNS
dig your-domain.com

# Agar IP match nahi kar raha:
# 1. Cloudflare/Namecheap me A record add karein
# 2. IP: 13.230.148.121
# 3. Wait 5-10 minutes
# 4. Phir SSL install karein: sudo certbot --nginx -d your-domain.com
```

---

## 📝 Complete Command Sequence

### EC2 Server (SSH ke baad):

```bash
# Method 1: Script already repository me hai
cd /home/ubuntu
git clone YOUR_GIT_REPO_URL stall-capture
cd stall-capture/deployment
chmod +x deploy.sh
./deploy.sh

# Method 2: Script manually upload karein (pehle step 2 dekhein)
```

---

## ✅ Checklist

Deployment se pehle:

- [ ] EC2 instance running hai (13.230.148.121)
- [ ] SSH key file ready hai (lead-tap.pem)
- [ ] Git repository URL ready hai
- [ ] Repository me `backend/` folder hai
- [ ] Supabase password ready hai
- [ ] Cloudflare R2 credentials ready hain
- [ ] Google OAuth credentials ready hain
- [ ] DNS pointing to EC2 IP (agar custom domain use kar rahe hain)

---

## 🆘 Help

Agar koi problem aaye:

1. **Error message share karein** (credentials ke bina)
2. **Logs check karein:**
   ```bash
   sudo journalctl -u gunicorn -n 50
   ```
3. **Configuration verify karein:**
   ```bash
   cat backend/.env  # Values redact karke share karein
   ```

---

## 🎯 Git Repository Setup Tips

### Public Repository:
- Direct clone: `https://github.com/username/repo.git`

### Private Repository:
- **Option 1:** Personal Access Token
  ```
  https://username:token@github.com/username/repo.git
  ```

- **Option 2:** SSH Key (recommended)
  ```bash
  # EC2 par SSH key setup karein
  ssh-keygen -t ed25519 -C "ec2-deploy"
  # Public key ko GitHub me add karein
  git clone git@github.com:username/repo.git
  ```

---

**Deployment Complete! 🎉**
