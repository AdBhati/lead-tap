# 🚀 Step-by-Step Deployment Guide

## 📋 Prerequisites

- ✅ EC2 Instance running (IP: 13.230.148.121)
- ✅ SSH Key file: `leadd-tap.pem`
- ✅ Domain name ready
- ✅ Supabase database password
- ✅ Cloudflare R2 credentials
- ✅ Google OAuth credentials

---

## 📍 Step 1: Files Upload Karein (Local Machine Se)

### Terminal me yeh command run karein:

```bash
cd "/Users/divyanshubhati/Desktop/Stall capture/lead-tap"
scp -i ~/leadd-tap.pem -r . ubuntu@13.230.148.121:/home/ubuntu/stall-capture
```

**Note:** Agar `leadd-tap.pem` file kisi aur location par hai, to uska full path use karein.

**Example:**
```bash
scp -i ~/Downloads/leadd-tap.pem -r . ubuntu@13.230.148.121:/home/ubuntu/stall-capture
```

**Kya hoga:**
- ✅ Sari files EC2 par upload ho jayengi
- ✅ 2-5 minutes lagega (internet speed ke hisab se)

---

## 📍 Step 2: EC2 Par SSH Connect Karein

### Nayi terminal window me:

```bash
ssh -i ~/leadd-tap.pem ubuntu@13.230.148.121
```

**Kya hoga:**
- ✅ EC2 server par connect ho jayega
- ✅ Terminal me `ubuntu@ip-xxx-xxx-xxx-xxx:~$` dikhega

---

## 📍 Step 3: Deployment Script Run Karein

### EC2 par connect hone ke baad:

```bash
# 1. Project directory me jayein
cd /home/ubuntu/stall-capture

# 2. Script ko executable banayein
chmod +x deployment/deploy.sh

# 3. Script run karein
./deployment/deploy.sh
```

---

## 📍 Step 4: Script Aap Se Puchhega

Script run hote hi yeh information mang lega:

### 1. Domain Name
```
Enter your domain name (e.g., example.com): yourdomain.com
```

### 2. Supabase Password
```
Enter Supabase database password: [type password - hidden]
```
**Note:** Password type karte waqt screen par dikhega nahi (security ke liye)

### 3. Cloudflare R2 Access Key ID
```
Enter Cloudflare R2 Access Key ID: your-access-key-id
```
- Cloudflare Dashboard → R2 → Manage R2 API Tokens se milega

### 4. Cloudflare R2 Secret Key
```
Enter Cloudflare R2 Secret Access Key: [hidden]
```
- Same place se milega

### 5. R2 Bucket Name
```
Enter R2 Bucket Name: stall-capture-media
```
- Default: `stall-capture-media` (Enter press karein)
- Ya apna bucket name dein

### 6. Google OAuth Client ID
```
Enter Google OAuth Client ID: xxxxx.apps.googleusercontent.com
```
- Google Cloud Console → APIs & Services → Credentials se milega

### 7. Google OAuth Client Secret
```
Enter Google OAuth Client Secret: [hidden]
```
- Same place se milega

### 8. Frontend Domain (CORS)
```
Enter Frontend Domain for CORS (e.g., https://yourdomain.com): https://yourdomain.com
```
- Frontend ka domain URL dein

---

## 📍 Step 5: Script Automatically Karega

Script automatically yeh sab karega:

1. ✅ **System packages install** (Python, Nginx, Certbot, etc.)
2. ✅ **Virtual environment setup**
3. ✅ **Python dependencies install**
4. ✅ **.env file create** (secure keys generate karke)
5. ✅ **Database migrations run**
6. ✅ **Static files collect**
7. ✅ **Nginx configure**
8. ✅ **Gunicorn service setup**
9. ✅ **SSL certificate install** (agar DNS ready hai)
10. ✅ **Services start**

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
   - `https://your-domain.com/health/`
   - Response: `{"status":"healthy","service":"stall-capture-api"}`

2. **Swagger API Docs:**
   - `https://your-domain.com/swagger/`

3. **Admin Panel:**
   - `https://your-domain.com/admin/`

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

### Issue 1: "Permission denied"

```bash
# Solution
chmod +x deployment/deploy.sh
chmod 600 backend/.env
```

### Issue 2: "DNS not pointing"

```bash
# Check DNS
dig your-domain.com

# Agar IP match nahi kar raha:
# 1. Cloudflare/Namecheap me A record add karein
# 2. IP: 13.230.148.121
# 3. Wait 5-10 minutes
# 4. Phir SSL install karein: sudo certbot --nginx -d your-domain.com
```

### Issue 3: "SSL certificate failed"

```bash
# Manual SSL install
sudo certbot --nginx -d your-domain.com -d www.your-domain.com
```

### Issue 4: "Database connection error"

- Supabase password check karein
- Database URL format check karein
- Supabase firewall me EC2 IP allow karein

---

## 📝 Complete Command Sequence

### Local Machine (Terminal 1):

```bash
cd "/Users/divyanshubhati/Desktop/Stall capture/lead-tap"
scp -i ~/leadd-tap.pem -r . ubuntu@13.230.148.121:/home/ubuntu/stall-capture
```

### EC2 Server (Terminal 2 - SSH ke baad):

```bash
ssh -i ~/leadd-tap.pem ubuntu@13.230.148.121
cd /home/ubuntu/stall-capture
chmod +x deployment/deploy.sh
./deployment/deploy.sh
```

---

## ✅ Checklist

Deployment se pehle:

- [ ] EC2 instance running hai (13.230.148.121)
- [ ] SSH key file ready hai (leadd-tap.pem)
- [ ] Domain name ready hai
- [ ] Supabase password ready hai
- [ ] Cloudflare R2 credentials ready hain
- [ ] Google OAuth credentials ready hain
- [ ] DNS pointing to EC2 IP (agar SSL chahiye)

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

**Deployment Complete! 🎉**
