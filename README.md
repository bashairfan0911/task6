# Task 1 — Strapi Application Setup & Sample Article

This repository contains a Strapi **v5.x** application prepared for the internship assignment.
It includes a sample collection type `Article`, sample entries, and the minimal project files required to run the app locally.

---

## Overview

What this repo contains:

* A Strapi app scaffolded locally
* An `Article` collection type with fields: `title` (short text), `content` (rich text), `published` (boolean)
* Sample article entries created via the Strapi admin UI
* Files pushed to branch `Shantanu` for PR

---

## Prerequisites

Make sure you have:

* Node.js (LTS recommended) installed
* npm (or yarn)
* Git installed
* (Optional) Docker if you prefer containerized runs

---

## Quick Setup — Commands used

Below are the exact commands used to create, run and push the project. Run these from a terminal in the folder where you want the project.

### 1. Create a new Strapi project (example)

> This is an example used if you want to create a project from scratch. Skip if you already have the project folder.

```bash
# Using npm (Strapi installer approach may vary)
npx create-strapi@latest my-strapi-app --quickstart
# or if you want TypeScript or specific options, configure accordingly
```

> In this assignment we used a standard Strapi project scaffold that results in the project folder: `my-strapi-app/`.

### 2. Start Strapi (developer mode)

Run from the project root:

```bash
# If package.json has the develop script
npm run develop
# or with yarn
yarn develop
```

The admin UI opens at:

```
http://localhost:1337/admin
```

When prompted on first run, register an admin user (email + password) in the admin UI.

### 3. Create content type (via Admin UI)

In the browser admin UI:

1. Go to **Content-Type Builder** → **Create collection type**.
2. Enter display name: `Article`.
3. Add fields:

   * `title` — Text (Short text)
   * `content` — Rich Text (or Long Text / Rich Text)
   * `published` — Boolean
4. Save (Strapi will rebuild admin UI automatically).

### 4. Add sample content (via Admin UI)

* Go to **Content Manager** → **Article** → **Create new entry**
* Fill sample data and click **Publish** (or Save & Publish).

### 5. Test API endpoints

Example GET (public or role-limited depending on permissions):

```bash
# Basic curl while running locally
curl -s http://localhost:1337/api/articles | jq .
```

If `jq` is not installed you will see JSON raw output:

```bash
curl -s http://localhost:1337/api/articles
```

The response should include your sample articles.

---

## Git workflow used for this submission

Commands executed locally to push your changes to the internship repository:

```bash
# inside project root
git init                        # if not already a repo
git remote add origin <repo-url>   # set remote to the organization repo
git fetch origin
git checkout -b Shantanu origin/Shantanu  # create branch tracking remote (or create new local branch)
# stage and commit your project files (exclude node_modules)
git add .
git commit -m "Add Strapi setup and sample article"
git push -u origin Shantanu
```

After `git push`, open the repository on GitHub and click the green **Compare & pull request** button to create the PR from branch `Shantanu` into `main` (or as instructed by the mentor).

> **Important:** Keep `.env` secrets out of Git. `.gitignore` should include `node_modules/`, `.env`, and other local artifacts.

---

## File structure (current — updated)

```
my-strapi-app/
├─ config/
│   └─ ... Strapi config files
├─ database/
│   └─ migrations/
├─ public/
│   └─ static assets (favicon, etc.)
├─ src/
│   ├─ api/
│   │   └─ article/
│   │       ├─ content-types/
│   │       │    └─ article/      # schema JSON for Article
│   │       ├─ controllers/
│   │       ├─ routes/
│   │       └─ services/
│   └─ ... other Strapi source files
├─ types/
│   └─ generated/
│       ├─ contentTypes.d.ts
│       └─ components.d.ts
├─ .env.example
├─ .gitignore
├─ README.md
├─ package.json
├─ package-lock.json
├─ tsconfig.json
└─ favicon.png
```

---

## How to reproduce locally (step-by-step)

1. Clone the repo or copy the project folder to your machine:

```bash
git clone <org-repo-url>
cd The-Monitor-Hub
git checkout -b Shantanu origin/Shantanu   # or git checkout Shantanu if created
```

2. Install dependencies:

```bash
# from project root
npm install
# or
yarn
```

3. Create `.env` (copy `.env.example` to `.env`) and configure DB / ports if required.

4. Run Strapi in dev mode:

```bash
npm run develop
# or
yarn develop
```

5. Visit `http://localhost:1337/admin`, sign in, and you should see your `Article` in Content Manager.

---

## What I verified here

* Admin panel accessible and admin user created.
* `Article` collection type added with fields: title, content, published.
* Sample entries created and visible via API `GET /api/articles`.
* Repo pushed to the `Shantanu` branch and PR created for review.

---
                                                                                                                                                                                                                                                                                                                                                                                                                                         Here is a **clean, professional, internship-grade Task-3 README section** you can directly paste under your existing README.md.

---

#  **Task 3 – Dockerized Strapi + PostgreSQL + Nginx Setup**

This task focuses on setting up a fully containerized environment for Strapi using PostgreSQL as the database and Nginx as a reverse proxy. All services communicate over a user-defined Docker network. The final goal is to access the Strapi Admin panel via **[http://localhost/admin](http://localhost/admin)**.

---

##  **1. Create a User-Defined Docker Network**

```bash
docker network create strapi-net
```

All containers (PostgreSQL, Strapi, Nginx) will use this network.

---

##  **2. Run PostgreSQL Container**

```bash
docker run -d \
  --name strapi-postgres \
  --network strapi-net \
  -e POSTGRES_USER=strapi \
  -e POSTGRES_PASSWORD=strapi123 \
  -e POSTGRES_DB=strapi \
  -p 5432:5432 \
  postgres:15
```

### PostgreSQL Credentials

| Key               | Value     |
| ----------------- | --------- |
| POSTGRES_USER     | strapi    |
| POSTGRES_PASSWORD | strapi123 |
| POSTGRES_DB       | strapi    |

---

##  **3. Configure Environment Variables (.env)**

Create a `.env` file in the project root:

```
HOST=0.0.0.0
PORT=1337

APP_KEYS=appkey1,appkey2
API_TOKEN_SALT=apitokensalt123
ADMIN_JWT_SECRET=adminjwt123
JWT_SECRET=jwtsecret123
ADMIN_AUTH_SECRET=adminauthsecret123
TRANSFER_TOKEN_SALT=transfersalt123
ENCRYPTION_KEY=encryptionkey123

DATABASE_CLIENT=postgres
DATABASE_HOST=strapi-postgres
DATABASE_PORT=5432
DATABASE_NAME=strapi
DATABASE_USERNAME=strapi
DATABASE_PASSWORD=strapi123
```

---

##  **4. Dockerfile for Strapi (TypeScript Project)**

```dockerfile
FROM node:20-bullseye
 
WORKDIR /app
 
# Copy package files and install dependencies
COPY package.json package-lock.json* ./
RUN npm install
RUN npm install pg --save
 
# Copy the full project
COPY . .
 
# Build Strapi (build TypeScript → dist/)
RUN npm run build
 
EXPOSE 1337
 
# Start Strapi in production mode
CMD ["npm", "run", "start"]
```

---

##  **5. Build Strapi Docker Image**

```bash
docker build --no-cache -t strapi-app .
```

---

##  **6. Run Strapi Container**

```bash
docker run -d \
  --name strapi-container \
  --network strapi-net \
  --env-file .env \
  -p 1337:1337 \
  strapi-app
```

To verify logs:

```bash
docker logs -f strapi-container
```

---

##  **7. Configure Nginx Reverse Proxy**

Create the file:

```
nginx/nginx.conf
```

with the following contents:

```nginx
events {}

http {
    server {
        listen 80;

        location / {
            proxy_pass http://strapi-container:1337;
            proxy_set_header Host $host;
            proxy_set_header X-Real-IP $remote_addr;
            proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
            proxy_set_header X-Forwarded-Proto $scheme;
        }

        location /admin/ {
            proxy_pass http://strapi-container:1337/admin/;
            proxy_http_version 1.1;
            proxy_set_header Upgrade $http_upgrade;
            proxy_set_header Connection "upgrade";
        }
    }
}
```

---

##  **8. Run Nginx Container (Windows Path Included)**

```bash
winpty docker run -d \
  --name strapi-nginx \
  --network strapi-net \
  -p 80:80 \
  -v "C:/Users/SHANTANU RANA/Desktop/Task-3/The-Monitor-Hub/nginx/nginx.conf:/etc/nginx/nginx.conf:ro" \
  nginx:latest
```

Check logs:

```bash
docker logs strapi-nginx
```

Expected:

```
Configuration complete; ready for start up
```

---

##  **9. Final Verification**

Open your browser:

###  **[http://localhost/admin](http://localhost/admin)**

You should now see the Strapi Admin Panel setup screen.

Congratulations — all services are running successfully through Docker!

---

##  **What This Task Achieves**

* Fully Dockerized Strapi application
* PostgreSQL database running in a dedicated container
* Nginx reverse proxy routing requests to Strapi
* A shared Docker network (`strapi-net`) for container communication
* Production-like local setup
* Admin dashboard accessible via **[http://localhost/admin](http://localhost/admin)**

---

