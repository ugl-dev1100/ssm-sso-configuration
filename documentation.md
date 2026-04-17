# 🚀 Project Documentation: AWS SSO + SSM Secure Access Framework

---

## 📌 1. What This Project Solves

### ❗ Problem Statement

In traditional setups:

* Developers use:

  * SSH keys
  * Bastion hosts
  * VPN access
* Issues:

  * 🔴 Key management is messy
  * 🔴 Bastion hosts increase attack surface
  * 🔴 No proper session logging
  * 🔴 Hard to enforce access control per user/team
  * 🔴 Manual DB tunneling (error-prone)

---

### ✅ Solution Overview

This project implements:

* 🔐 **AWS SSO-based authentication**
* 🖥️ **SSM Session Manager for secure instance access**
* 🔁 **SSM Port Forwarding for DB access**
* 📜 **Centralized logging via Amazon CloudWatch**
* ⚙️ **Custom automation scripts (Mac + Windows)**

---

### 🎯 Key Benefits

* No SSH keys required
* No bastion hosts
* Fine-grained access control via SSO
* Full session audit logs
* Secure DB access without exposing ports
* Developer-friendly (auto reconnect feel)

---

### 🧠 Real-World Use Case

> Developer wants to connect to RDS MySQL

Instead of:

```
Local → Bastion[PEM] → DB
```

We do:

```
Local → SSO Login → SSM Tunnel → DB
```

---

### 🔄 Before vs After

| Aspect        | Before        | After           |
| ------------- | ------------- | --------------- |
| Access Method | SSH + Bastion | SSO + SSM       |
| Security      | Medium        | High            |
| Logging       | Limited       | Full CloudWatch |
| Setup         | Manual        | Scripted        |
| DB Access     | Complex       | One command     |

---

### 🏗️ Technologies Used

* AWS SSO
* AWS SSM Session Manager
* EC2
* RDS
* Amazon CloudWatch
* Bash (Mac)
* PowerShell (Windows)

---

Perfect, let’s build this clean and strong 💪

---

# 🏗️ 2. Architecture Diagrams

We’ll cover two core flows:

1. **SSM Tunneling for Instance Access**
2. **SSM Port Forwarding for Database Access**

---

## 🔹 2.1 SSM Tunneling (Instance Access)

![Image](https://images.openai.com/static-rsc-4/EA_w65do9cPS7l_BoPxbjj_39YprxhvGkyoUne7pKZyYaC_Im2dJ7zyCvDWq2yUvOgkBoPuXC5LzCCaW-xjwY0hON5QA5mEBMvkkm7Ccrr6ponjNSS3gMAIAjoMj5BfzzZx6EwPkKYdhsj6StjcboamJKRIjK8y1je63sc1dxe30704yDxQyoNDymFJwT7eS?purpose=fullsize)


![Image](https://images.openai.com/static-rsc-4/BqHc6dJBMEQ5y3lSDSFPtfiG6ijKMGg8lwT0efcX8mJAWuf8HH_mPbD6FeW3RFZwHMLaZxiRW0jwTEl1IAtSnicUumLdhVXkY3b3jqVg0Sr7mS_78rwmB_V8KiVVvDA2v3qKvVhkbw6iHIveuyJNfgXdX2ESTdVhtvWj8yFCFgBze2bPKO53doXtpBEs1F9J?purpose=fullsize)

![Image](https://images.openai.com/static-rsc-4/Yz-Myu4vRs0xLPCL3ciSo7yyzTVvbTbw1mqd0-QWO4RQb96V6NcAkd10nFVz2yfprsCR2eAv7Hjwz7wXee6IU1Br-f2r3Zp2LQ-9PJZ3i6U1MtO9hMm7j0nJPC-_kyVJqPnsAErPirfLX8Pa2RddQ2pYYaBVxureubKVyDBxU2Q49bhA98692dsZ3rkdkZ04?purpose=fullsize)

![Image](https://images.openai.com/static-rsc-4/tNhUXrsH6B-HBXQshb4MD-HmABGlO5yXeon77ZS5NJZlaPsVovv2tYaVCI2IUMrHIVClxN9qUXtrXpwJPLbb2ufuPESTKQr3iyqIvqxy8dFJbflgzmCX9IoliuquWKCqAPrRyT8MHOhk85zKSTxReSFEJxeMX8AUVrIM-As5w-qkniIEb1aKJZXRP8mBw3nA?purpose=fullsize)

![Image](https://images.openai.com/static-rsc-4/eK-c7jkx6H9Ooal75ikbVmDd4UWZq8mZWwHHE1_S5JX5hGVVLP-SdcAYTqaUgx4XiQCNZdcVHDl_scOJziljdiUSvuBVCqnQ7LFK9X5tqGR3j2BmmY25rw81TebJVRVb1kNG-nP22PbUq58c6hXZsmyzooUFcWHDOtj32gEd6t6Hvc4kS1bQBMWSTLQZTE_8?purpose=fullsize)

### 🧠 Flow Explanation

```text
Developer (Mac/Windows)
        │
        ▼
AWS SSO Login
        │
        ▼
Temporary Credentials (STS)
        │
        ▼
AWS SSM StartSession
        │
        ▼
SSM Agent (on EC2)
        │
        ▼
Shell Access to Instance
```

---

### 🔍 What Happens Internally

1. User runs script → triggers:

   ```bash
   aws sso login --profile uat
   ```

2. AWS provides **temporary credentials (STS)**

3. Command executed:

   ```bash
   aws ssm start-session --target <instance-id>
   ```

4. Instead of SSH:

   * Connection goes via **SSM service (no inbound ports needed)**
   * Instance communicates via:

     * HTTPS (port 443 outbound)

---

### 🔐 Security Advantages

* ❌ No port 22 open
* ❌ No SSH keys
* ✅ IAM-based access control
* ✅ Full session logging via Amazon CloudWatch

---

## 🔹 2.2 SSM Port Forwarding (Database Access)

![Image](https://images.openai.com/static-rsc-4/Yz-Myu4vRs0xLPCL3ciSo7yyzTVvbTbw1mqd0-QWO4RQb96V6NcAkd10nFVz2yfprsCR2eAv7Hjwz7wXee6IU1Br-f2r3Zp2LQ-9PJZ3i6U1MtO9hMm7j0nJPC-_kyVJqPnsAErPirfLX8Pa2RddQ2pYYaBVxureubKVyDBxU2Q49bhA98692dsZ3rkdkZ04?purpose=fullsize)

![Image](https://images.openai.com/static-rsc-4/qaDVRKbZH_jy1-nd0Wgn2jzfubhlDlnNu6ukD5XzhsmDKS6H-cpj21lXf4zScyWtemt55g7VWuT2t5r3coO8Vw3NGyYmtKjGcR9XOA8WUFvaE9-lHG14eNGNW2H0UwRKxMoOx_ed0m1KBqYODeud27W4sTQ0DqlbfyNN-EJU8tDjCaa7CojpU65GdD0nIvPF?purpose=fullsize)

![Image](https://images.openai.com/static-rsc-4/Kk2E0mew7moBYSXXgV5t29tt6f0ZVdfkj9kBW1KsrobmdkrSWAICL-xdaIH8BfHgloSrZmShDoCd4-16-y0Io5-rweq_qyk-RtiD24lFQIU3YZgCwFpe73w-dV5l6oCx_vNM0B8c3yoBmJLbgqmm1J9zEPKNSoX-f2u205uUb5MyCyKrOi9XR1UtgRQEoke8?purpose=fullsize)

![Image](https://images.openai.com/static-rsc-4/a87vvAjvyZdpJLzdwrrp96-bDuNvPlEsi6jCrOFrRfWxQm6CJu-P_FAJVuNG3Md_d1UTeIFt0aqh3vatBmS6B9V26tb3bj_QqTJQyeWATpF9BXk9JGTUVCNKXnb2-qeS7BDmZN3hMNEUcoefFvZKSnJ4zVyCzGovn200ghZWjcd1kE_MyAu8wrHOHiYfR7l6?purpose=fullsize)

![Image](https://images.openai.com/static-rsc-4/ZudyZGrHOJY0TZdHEWetW-8uhojVA_ILAIKq88wBlUf4n5AVDu5GZnh2GSAhYmJGLyG1xqg_FgHmvBgkotfmiFpguAXWy3UZ75tfVkXk5CtdhkZOUN7q3j0b1PZwxK2zaqvaMJFF6I14J736AqDJMxEY9e8tBNeU6Aa6Xt5jSDC533fc3G86-Os2oLDSkpSm?purpose=fullsize)

![Image](https://images.openai.com/static-rsc-4/_EGWyPYgip3ENl9492Akg1xeNaC-bvr8qVmGTuJB_JL4TyiMFI6N_FWLKZqJKjm-DOqU2LUcz3HcWepIIKSnL5xypcKoNnEUUpJiayQHrthouDNt3dY9c2660Ivq9nsJcAcmNL3piZEyK0F39ZbI3PSADoN2l2frSSZMLkVfHPpZr7bsS3mLzwGmkg37CLv9?purpose=fullsize)

---

### 🧠 Flow Explanation

```text
Sequel Ace / Local App
        │
        ▼
Localhost:3306
        │
        ▼
SSM Port Forwarding Session
        │
        ▼
EC2 (SSM Agent)
        │
        ▼
RDS MySQL (Private Subnet)
```

---

### 🔍 Actual Command Used

```bash
aws ssm start-session \
  --target <instance-id> \
  --document-name AWS-StartPortForwardingSessionToRemoteHost \
  --parameters '{"host":["<rds-endpoint>"],"portNumber":["3306"],"localPortNumber":["3306"]}'
```

---

### 💡 How Developer Experiences It

* Open **Sequel Ace**
* Host: `127.0.0.1`
* Port: `XXXX`

👉 That’s it. No idea about EC2 / tunnel / SSM — seamless.

---

### 🔐 Security Benefits

* ❌ DB not exposed publicly
* ❌ No VPN needed
* ❌ No SSH tunneling manually
* ✅ IAM + SSO controlled
* ✅ Auditable via Amazon CloudWatch

---

### ⚠️ Important Requirement

* EC2 must have:

  * SSM Agent installed
  * IAM role:

    * `AmazonSSMManagedInstanceCore`

---

## 🧩 Summary

| Feature    | Instance Access | DB Access        |
| ---------- | --------------- | ---------------- |
| Method     | SSM Session     | SSM Port Forward |
| Protocol   | Shell           | TCP Tunnel       |
| Local Port | N/A             | Yes (3306 etc)   |
| Security   | IAM             | IAM              |
| Logging    | CloudWatch      | CloudWatch       |

---
Got you, buddy 👍 — keeping it **very simple and straight**.

---

# 📁 3. Mac Scripts – What Each Script Does

---

## 🔹 install.sh

* Installs required tools (AWS CLI, Session Manager Plugin)
* Copies scripts to system path
* Sets execute permissions
* Creates config files (`~/.rds-map`)
* Adds command aliases to shell (`uat`, `prod`, `dbpc`, `dbuat` , `dbprod`)
* Auto Session Login for uat and prod

---

## 🔹 aws-login

* Checks if AWS SSO session is active
* If not, performs login using AWS SSO

---

## 🔹 linux

* Lists EC2 instances
* Allows user to select an instance
* Connects to the instance using SSM
* Sets a custom prompt inside the session

---

## 🔹 rds

* Reads database name and port from `~/.rds-map`
* Selects EC2 instance for tunneling
* Starts SSM port forwarding to the database
* Enables connection via `localhost:<port>`

---

## 🔹 dbpc

* Checks if the required local port is already in use
* Prevents conflicts before starting DB connection

---

## 🔹 rds-map (template)

* Stores database name and port
* Used by `rds` script for connection setup

---

Got it, buddy 👍 — same simple format.

---

# 🪟 4. Windows Scripts – What Each Script Does

---

## 🔹 install.ps1

* Installs required tools (AWS CLI, Session Manager Plugin)
* Copies scripts to a usable path
* Sets execution permissions
* Creates config file (`~/.rds-map`)
* Adds command aliases/functions for easy usage

---

## 🔹 aws-login.ps1

* Checks if AWS SSO session is active
* If not, performs AWS SSO login

---

## 🔹 win-connect.ps1

* Lists EC2 instances
* Allows user to select an instance
* Connects to the instance using SSM

---

## 🔹 rds.ps1

* Reads database name and port from `~/.rds-map`
* Selects EC2 instance for tunneling
* Starts SSM port forwarding to the database
* Enables connection via `localhost:<port>`

---

## 🔹 db-pc.ps1

* Checks if the required local port is already in use
* Prevents conflicts before starting DB connection

---

## 🔹 rds-map (template)

* Stores database name and port
* Used by `rds.ps1` for connection setup

---


