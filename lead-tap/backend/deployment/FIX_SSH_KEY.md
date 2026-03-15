# 🔑 SSH Key Fix Guide

## ✅ Key File Found!

**Location:** `/Users/divyanshubhati/Downloads/lead-tap.pem`

**Note:** File name is `lead-tap.pem` (not `leadd-tap.pem` - ek 'd' kam hai)

---

## 🔧 Step 1: Fix Key Permissions

SSH key file ko proper permissions deni chahiye:

```bash
chmod 400 ~/Downloads/lead-tap.pem
```

---

## 📤 Step 2: Files Upload (Correct Command)

```bash
cd "/Users/divyanshubhati/Desktop/Stall capture/lead-tap"
scp -i ~/Downloads/lead-tap.pem -r . ubuntu@13.230.148.121:/home/ubuntu/stall-capture
```

---

## 🔐 Step 3: SSH Connect (Correct Command)

```bash
ssh -i ~/Downloads/lead-tap.pem ubuntu@13.230.148.121
```

---

## ⚠️ Important Notes

1. **File name:** `lead-tap.pem` (not `leadd-tap.pem`)
2. **Path:** `~/Downloads/lead-tap.pem` ya `/Users/divyanshubhati/Downloads/lead-tap.pem`
3. **Permissions:** `chmod 400` karna zaroori hai

---

## 🚀 Complete Commands

### Terminal 1 (Files Upload):
```bash
# Permissions fix
chmod 400 ~/Downloads/lead-tap.pem

# Files upload
cd "/Users/divyanshubhati/Desktop/Stall capture/lead-tap"
scp -i ~/Downloads/lead-tap.pem -r . ubuntu@13.230.148.121:/home/ubuntu/stall-capture
```

### Terminal 2 (SSH Connect):
```bash
# SSH connect
ssh -i ~/Downloads/lead-tap.pem ubuntu@13.230.148.121
```

---

**Ab yeh commands use karein!** ✅
