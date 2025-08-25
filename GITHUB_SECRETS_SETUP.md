# GitHub Repository Secrets Setup

## 🚨 **Current Issue**
The deployment is failing because GitHub repository secrets are not configured. The workflow needs these secrets to connect to your VPS.

**Error**: `option requires an argument -- p` 
**Cause**: Empty `VPS_PORT` and `VPS_HOST` secrets

## 🔑 **Required GitHub Secrets**

You need to add these 4 secrets to your GitHub repository:

| Secret Name | Value | Description |
|-------------|-------|-------------|
| `VPS_HOST` | `103.168.19.241` | Your VPS IP address |
| `VPS_PORT` | `7576` | SSH port (you mentioned 7576) |
| `VPS_USER` | `root` | SSH username |
| `VPS_SSH_KEY` | `<private_key_content>` | SSH private key |

## 🛠️ **Step-by-Step Setup**

### Step 1: Generate SSH Key (if not done already)
```bash
# Run the SSH setup script
cd deployment
./setup-ssh.sh
```

This script will:
- Generate SSH keys
- Install public key on your VPS
- Show you the private key to copy

### Step 2: Add Secrets to GitHub Repository

1. **Go to your GitHub repository**
2. **Click on "Settings" tab**
3. **Go to "Secrets and variables" → "Actions"**
4. **Click "New repository secret"**

Add each secret:

#### Secret 1: VPS_HOST
- **Name**: `VPS_HOST`
- **Value**: `103.168.19.241`

#### Secret 2: VPS_PORT  
- **Name**: `VPS_PORT`
- **Value**: `7576`

#### Secret 3: VPS_USER
- **Name**: `VPS_USER` 
- **Value**: `root`

#### Secret 4: VPS_SSH_KEY
- **Name**: `VPS_SSH_KEY`
- **Value**: Copy the entire private key content (including `-----BEGIN` and `-----END` lines)

**Example private key format**:
```
-----BEGIN OPENSSH PRIVATE KEY-----
b3BlbnNzaC1rZXktdjEAAAAABG5vbmUAAAAEbm9uZQAAAAAAAAABAAAAMwAAAAtzc2gtZW
QyNTUxOQAAACBK8B5jF5K5qK5qK5qK5qK5qK5qK5qK5qK5qK5qK5qK5qK5qK5qK5qK5q
...
(many lines of key data)
...
K5qK5qK5qK5qK5qK5qK5qK5qK5qK5qK5qK5qK5qK5qK5qK5qK5qK5qK5qK5qK5qK5qK5q
-----END OPENSSH PRIVATE KEY-----
```

## 🔧 **Manual SSH Key Generation (Alternative)**

If the setup script doesn't work, generate manually:

```bash
# Generate SSH key pair
ssh-keygen -t ed25519 -C "github-actions-letzgo" -f ~/.ssh/letzgo_deploy_key -N ""

# Copy public key to VPS
ssh-copy-id -i ~/.ssh/letzgo_deploy_key.pub -p 7576 root@103.168.19.241

# Display private key (copy this to GitHub secret)
cat ~/.ssh/letzgo_deploy_key
```

## ✅ **Verification**

After adding all secrets, verify they're set:

1. **Go to repository Settings → Secrets and variables → Actions**
2. **You should see 4 secrets**:
   - ✅ VPS_HOST
   - ✅ VPS_PORT  
   - ✅ VPS_USER
   - ✅ VPS_SSH_KEY

## 🚀 **Test Deployment**

Once secrets are added, trigger deployment:

```bash
# Trigger infrastructure deployment
git add .
git commit -m "Add GitHub secrets configuration"
git push origin main
```

## 🐛 **Troubleshooting**

### Issue: "Permission denied (publickey)"
- Verify the private key is correct
- Check that public key is in VPS `~/.ssh/authorized_keys`
- Ensure VPS SSH service allows key authentication

### Issue: "Connection refused"
- Verify VPS IP address (103.168.19.241)
- Check SSH port (7576)
- Ensure VPS firewall allows SSH on port 7576

### Issue: "Host key verification failed"
- The workflow handles this automatically with `ssh-keyscan`
- If issues persist, may need to add `-o StrictHostKeyChecking=no`

## 📋 **Quick Setup Checklist**

- [ ] Run `./deployment/setup-ssh.sh`
- [ ] Copy SSH private key
- [ ] Add `VPS_HOST` = `103.168.19.241`
- [ ] Add `VPS_PORT` = `7576`
- [ ] Add `VPS_USER` = `root`
- [ ] Add `VPS_SSH_KEY` = `<private_key_content>`
- [ ] Verify all 4 secrets are in GitHub
- [ ] Test deployment by pushing to main branch

## 🔒 **Security Notes**

- **Never commit private keys to git**
- **Keep private keys secure**
- **Use separate keys for different environments**
- **Regularly rotate SSH keys**
- **Consider using GitHub Environment protection rules**

---

**🎯 Once these secrets are configured, the deployment workflow will be able to connect to your VPS successfully!**
