# 🌐 EC2 Public DNS vs Custom Domain

## ✅ Yes, You Can Use EC2 Public DNS!

You can use EC2's Public DNS instead of a custom domain name.

---

## 📍 How to Get EC2 Public DNS

### Method 1: AWS Console
1. Go to AWS Console → EC2 → Instances
2. Click on your instance
3. Copy the **Public IPv4 DNS** value
4. Example: `ec2-13-230-148-121.ap-southeast-1.compute.amazonaws.com`

### Method 2: From EC2 Instance
```bash
# SSH into your EC2 instance
curl http://169.254.169.254/latest/meta-data/public-hostname
```

### Method 3: From AWS CLI
```bash
aws ec2 describe-instances --instance-ids i-xxxxx --query 'Reservations[0].Instances[0].PublicDnsName'
```

---

## 🔄 Using Public DNS in Deployment Script

When the script asks for domain name, you can:

**Option 1:** Press Enter (script will auto-detect Public DNS)
```
Enter domain name or press Enter to use EC2 Public DNS [ec2-13-230-148-121.ap-southeast-1.compute.amazonaws.com]: 
[Press Enter]
```

**Option 2:** Enter Public DNS manually
```
Enter domain name (or EC2 Public DNS): ec2-13-230-148-121.ap-southeast-1.compute.amazonaws.com
```

---

## ⚠️ Important Differences

### Using EC2 Public DNS:
- ✅ **Free** - No domain purchase needed
- ✅ **Quick setup** - No DNS configuration
- ❌ **No HTTPS/SSL** - Only HTTP (not secure)
- ❌ **Long URL** - Hard to remember
- ❌ **Changes on restart** - DNS changes if instance stops/starts
- ❌ **Not professional** - Not suitable for production

### Using Custom Domain:
- ✅ **HTTPS/SSL** - Secure connection
- ✅ **Short URL** - Easy to remember
- ✅ **Professional** - Better for production
- ✅ **Stable** - Doesn't change
- ❌ **Cost** - ~$10-15/year for domain
- ❌ **DNS setup** - Need to configure

---

## 🚀 Quick Start with Public DNS

### Step 1: Get Public DNS
```bash
# From AWS Console or run this on EC2:
curl http://169.254.169.254/latest/meta-data/public-hostname
```

### Step 2: Run Deployment
```bash
cd /home/ubuntu/stall-capture
./deployment/deploy.sh
```

### Step 3: When Asked for Domain
```
Enter domain name or press Enter to use EC2 Public DNS [ec2-xxx.compute.amazonaws.com]: 
[Just press Enter]
```

### Step 4: Access Your App
- `http://ec2-13-230-148-121.ap-southeast-1.compute.amazonaws.com`
- `http://ec2-13-230-148-121.ap-southeast-1.compute.amazonaws.com/swagger/`
- `http://ec2-13-230-148-121.ap-southeast-1.compute.amazonaws.com/admin/`

**Note:** HTTP (not HTTPS) - SSL certificate won't be installed

---

## 🔒 For Production: Use Custom Domain

For production applications, **highly recommended** to use a custom domain:

1. **Buy Domain** (~$10-15/year):
   - Namecheap
   - Google Domains
   - Cloudflare
   - GoDaddy

2. **Point DNS to EC2:**
   - Add A record: `@` → `13.230.148.121`
   - Add CNAME: `www` → `yourdomain.com`

3. **Run Deployment:**
   - Script will automatically install SSL certificate
   - You'll get HTTPS (secure)

---

## 📝 Example: Your Current Setup

**EC2 IP:** `13.230.148.121`  
**Region:** `ap-southeast-1` (Singapore)  
**Public DNS:** `ec2-13-230-148-121.ap-southeast-1.compute.amazonaws.com`

You can use this Public DNS directly in the deployment script!

---

## ✅ Recommendation

- **For Testing/Development:** Use EC2 Public DNS (quick and free)
- **For Production:** Use Custom Domain (professional and secure)

---

**The deployment script now supports both options automatically!** 🎉
